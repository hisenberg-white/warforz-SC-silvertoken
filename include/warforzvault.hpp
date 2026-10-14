// ============================================================================
//  warforzvault.hpp — Warforz Lands SILVER token (WAX / eosio.cdt)
//
//  The fungible-token ("FT") contract for the Warforz Lands economy. It is an
//  `eosio.token` implementation — same actions, same `stat`/`accounts` table
//  layouts — so every WAX wallet, explorer and light-API indexer reads it
//  without special-casing.
//
//  ADDITIONS ON TOP OF THE STANDARD
//    1. `burn`         — any holder may destroy their own tokens (economy V1
//                        §13 sinks do not accumulate in the issuer balance, so
//                        `retire` alone cannot reach them).
//    2. A BURNED TRANSFER FEE — a configurable cut of each transfer is
//                        destroyed instead of delivered. See the warning below.
//    3. `setissuer`    — issuer rotation, under DUAL authority.
//    4. Fee governance — a rate ceiling, a timelock on increases, and
//                        lockable exemptions that cannot be revoked while a
//                        fee is live.
//
//  DEPLOYMENT TARGET: the `warforzvault` account.
//    The class name must match the contract name passed to add_contract() in
//    CMakeLists.txt, and that name should match the deploy account for the ABI
//    to load cleanly. If you deploy elsewhere, rename BOTH.
//
//  ###########################################################################
//  ##  TRANSFER FEE — READ BEFORE CONFIGURING                               ##
//  ###########################################################################
//  When a fee applies, the sender is debited `quantity` but the recipient is
//  credited `quantity - fee`. The transfer NOTIFICATION still carries the gross
//  `quantity`, because that is the action's own argument and cannot be rewritten.
//
//  Any contract that credits an internal ledger from that notification will
//  therefore over-credit itself and drift into deficit. `warforzlands` does
//  exactly that in `on_token_transfer` (player deposits) and `add_reward_pool`
//  (reward funding).
//
//  THE CONTRACT ENFORCES THE TWO ORDERING HAZARDS ITSELF:
//    * A fee can never be enabled while no LOCKED exemption exists
//      (`setfee` asserts it), so "fee on, exemptions forgotten" cannot happen.
//    * A LOCKED exemption can never be revoked while any fee is live
//      (`exemptunlock` asserts every rate is 0 first), so an exemption can
//      never be pulled out from under a running fee.
//
//  BE PRECISE ABOUT WHAT THAT DOES AND DOES NOT GUARANTEE. It guarantees no
//  SILENT, MID-FLIGHT exposure: stripping an exemption always requires first
//  switching every fee off, which is a visible, deliberate act. It does NOT
//  guarantee that any particular account stays exempt — `has_locked_exemption`
//  only asks whether SOME lock exists, so with two locked rows an admin can
//  still, in four deliberate steps, zero the fee, unlock and delete one of
//  them, and re-enable the fee with that integration now exposed.
//
//  WHAT IS NOT ENFORCEABLE AT ALL: the contract cannot know WHICH accounts need
//  exemption. Every NEW ledger-keeping integration — marketplace, bridge,
//  staking, exchange deposit processor — must still be exempted by hand, and
//  forgetting one under-collateralizes that integration silently. This is
//  inherent to fee-on-transfer and is the residual risk of the design.
//
//  A transfer is fee-free if EITHER party is exempt, so exempting the game
//  account covers both deposits (player -> game) and withdrawals (game ->
//  player) with one row.
//  ###########################################################################
//
//  HOW THIS PAIRS WITH THE GAME CONTRACT (SC/mininggame):
//    * `warforzlands::ftconfigset` is told this account + the `4,SILVER`
//      symbol. Every FT amount in the game reads that config — the game never
//      hardcodes the symbol.
//    * Deposits: a player calls `transfer(player, warforzlands, q, memo)` here.
//      `transfer` notifies both parties, so `warforzlands::on_token_transfer`
//      fires and credits the in-game balance. Nothing in this contract knows
//      about the game — do not add a game dependency here.
//    * Withdrawals: `warforzlands::wdrawft` sends an inline `transfer` from the
//      game account back to the player, with a fee split to the fee account.
//
//  DEPLOYMENT REQUIREMENT: `transfer` sends an inline `logburn` receipt when a
//  fee is charged, so the contract account needs the `eosio.code` permission:
//      cleos set account permission warforzvault active --add-code
//  Without it EVERY fee-bearing transfer reverts. Fee-free transfers are
//  unaffected, so this fails loudly on the first taxed transfer, not silently.
//
//  TABLE NAMES ARE PART OF THE STANDARD. `stat` (scope = symbol code) and
//  `accounts` (scope = owner) with these exact field layouts are what wallets
//  query for balances. Do not rename or reorder them. The governance tables are
//  additive and contract-scoped, so they cannot disturb that.
//
//  READING ORDER: tables first (they are the whole data model), then the action
//  list, then src/warforzvault.cpp for the logic.
// ============================================================================
#pragma once

#include <eosio/eosio.hpp>
#include <eosio/asset.hpp>
#include <eosio/system.hpp>     // current_time_point()
#include <string>

using namespace eosio;
using std::string;

// ===========================================================================
//  CONTRACT
// ===========================================================================
CONTRACT warforzvault : public contract {
public:
    using contract::contract;

    // -----------------------------------------------------------------------
    //  Named constants (avoid magic numbers; tune here).
    //  Scoped INSIDE the class deliberately: `warforzlands.hpp` declares its own
    //  namespace-scope `BPS`, and a third contract integrating with both would
    //  otherwise fail to compile on the redefinition.
    // -----------------------------------------------------------------------

    // Memo ceiling, identical to eosio.token. Memos land in public transaction
    // history and are read by indexers, so the bound keeps NET cost predictable.
    static constexpr size_t MAX_MEMO_BYTES = 256;

    // Basis-points denominator, matching the game contract's convention so a
    // rate means the same thing on both sides: 10000 bps == 100.00%.
    static constexpr int64_t BPS = 10000;

    // Hard ceiling on the burned transfer fee an admin may configure, 2.00%.
    // Holders cannot opt out of the fee, so the contract bounds how punitive it
    // can ever become. Deliberately close to the intended 0.50% (50 bps): a
    // ceiling many multiples above the real policy protects nobody.
    //
    // Raising this constant requires a code upgrade, and `fee_units` clamps to
    // it at READ time, so a stored rate above the ceiling can never take effect.
    static constexpr uint16_t MAX_TRANSFER_FEE_BPS = 200;

    // Notice period before a fee INCREASE takes effect. Decreases apply
    // immediately (always better for holders), and the first activation of a
    // symbol's fee is immediate too — that moment is guarded by the
    // locked-exemption precondition instead, which is the real hazard there.
    // Every later increase is announced on-chain for this long first.
    static constexpr uint32_t FEE_TIMELOCK_SEC = 259200;   // 72 hours

    // =======================================================================
    //  ACTIONS
    // =======================================================================

    // -- Supply management (auth = contract / issuer) --

    // One-time symbol registration. Fixes the precision and the hard ceiling on
    // circulating supply forever: there is no action that raises `max_supply`,
    // so the cap chosen here is the permanent monetary policy.
    ACTION create(name issuer, asset maximum_supply);

    // Mint into the issuer's own balance. `to` must BE the issuer — that is the
    // eosio.token rule and it is deliberate: minting and distributing are two
    // separate, separately auditable steps (issue, then transfer).
    ACTION issue(name to, asset quantity, string memo);

    // Destroy tokens held by the issuer. Lowers `supply`, never `max_supply`,
    // so retired headroom can be re-issued later.
    ACTION retire(asset quantity, string memo);

    // Rotate the issuer — the one `create` decision that IS reversible.
    //
    // DUAL AUTHORITY: both the current issuer AND the contract account must
    // sign. A single compromised key therefore cannot seize minting rights or
    // lock the project out of its own token. Plan key custody accordingly: if
    // you resign the contract account to a locked multisig (recommended), that
    // multisig becomes a required co-signer on every future rotation.
    ACTION setissuer(const symbol& token_symbol, name new_issuer);

    // -- Movement (auth = from) --
    // Charges and burns the configured transfer fee unless either party is
    // exempt. See the header warning above.
    ACTION transfer(name from, name to, asset quantity, string memo);

    // -- Balance-row lifecycle (RAM management) --

    // Pre-create a zero balance row so a later `transfer` cannot fail on RAM,
    // and so the receiving account (not the sender) owns that RAM.
    ACTION open(name owner, const symbol& symbol, name ram_payer);

    // Delete a zero balance row and reclaim its RAM.
    ACTION close(name owner, const symbol& symbol);

    // -- Economy sink (auth = owner) --

    // Let ANY holder destroy their own tokens. Plain eosio.token can only
    // `retire` from the issuer's balance, which would force every game sink
    // (healing, crafting, repairs, fees — economy V1 §13) to round-trip back to
    // the issuer before it could shrink the supply. `burn` lets the holder do it
    // directly. Same accounting as `retire`: `supply` drops, `max_supply` does
    // not, so burned headroom stays re-issuable.
    ACTION burn(name owner, asset quantity, string memo);

    // -- Fee policy (auth = contract) --

    // Set the burned transfer fee for a symbol, in basis points. 50 == 0.50%.
    //
    // Timing rules:
    //   * A DECREASE (including to 0) applies immediately.
    //   * The FIRST activation of a symbol's fee applies immediately, but is
    //     refused unless at least one LOCKED exemption already exists.
    //   * Every later INCREASE is written as a pending change and only takes
    //     effect after FEE_TIMELOCK_SEC, via `feeapply`.
    ACTION setfee(const symbol& token_symbol, uint16_t transfer_fee_bps);

    // Promote a pending fee increase once its notice period has elapsed.
    ACTION feeapply(const symbol& token_symbol);

    // Abandon a pending fee increase before it matures.
    ACTION feecancel(const symbol& token_symbol);

    // -- Fee exemptions (auth = contract) --

    // Exempt an account from the transfer fee in BOTH directions. Required for
    // any contract that credits an internal ledger from transfer notifications.
    // `reason` records the intent on-chain; it is not used in fee logic.
    // New rows start UNLOCKED — call `exemptlock` to protect them.
    ACTION exemptadd(name account, string reason);

    // Mark an exemption as load-bearing. A locked row cannot be deleted, and
    // cannot be unlocked while any fee is live. Lock every exemption whose
    // removal would break an integration's accounting.
    ACTION exemptlock(name account);

    // Unlock a protected exemption. REFUSED unless every configured fee (both
    // active and pending, across all symbols) is 0 — so the only way to strip a
    // critical exemption is to switch the fee off first. This is what makes it
    // impossible for the game to run with a fee and without its exemption.
    ACTION exemptunlock(name account);

    // Remove an exemption. Refused while the row is locked.
    ACTION exemptdel(name account);

    // -- Inline receipt (auth = _self; no state change, for traces) --

    // Records a burned transfer fee in the transaction trace. Without it the
    // burn is visible only as a `stat.supply` delta, which a historical indexer
    // cannot attribute without replaying the fee configuration as of that block.
    //
    // Deliberately does NOT call `require_recipient`: notifying a party whose
    // account may hold rejecting contract code would let them revert the parent
    // transfer. That exact pattern is finding H1 of the game contract's audit.
    ACTION logburn(name from, name to, asset fee);

    // =======================================================================
    //  READ HELPERS
    //  Callable from other contracts (they are static and take the token
    //  account explicitly), which is how eosio.token exposes balances on-chain.
    // =======================================================================
    static asset get_supply(name token_contract_account, symbol_code sym_code) {
        stats statstable(token_contract_account, sym_code.raw());
        const auto& st = statstable.get(sym_code.raw(), "symbol does not exist");
        return st.supply;
    }

    static asset get_balance(name token_contract_account, name owner, symbol_code sym_code) {
        accounts accountstable(token_contract_account, owner.value);
        const auto& ac = accountstable.get(sym_code.raw(), "no balance with specified symbol");
        return ac.balance;
    }

    // What `to` would actually receive for a `quantity` sent from `from`.
    // Front-ends should quote this rather than the gross amount, and other
    // contracts should use it instead of trusting a transfer notification.
    static asset get_net_transfer(name token_contract_account, name from, name to,
                                  const asset& quantity) {
        return quantity - asset{fee_units(token_contract_account, from, to, quantity),
                                quantity.symbol};
    }

    // Typed inline-action wrappers, so another contract can call us as
    // `warforzvault::transfer_action(...).send(...)` instead of hand-rolling
    // an `action(...)` with a std::make_tuple payload.
    using create_action       = action_wrapper<"create"_n,       &warforzvault::create>;
    using issue_action        = action_wrapper<"issue"_n,        &warforzvault::issue>;
    using retire_action       = action_wrapper<"retire"_n,       &warforzvault::retire>;
    using setissuer_action    = action_wrapper<"setissuer"_n,    &warforzvault::setissuer>;
    using transfer_action     = action_wrapper<"transfer"_n,     &warforzvault::transfer>;
    using open_action         = action_wrapper<"open"_n,         &warforzvault::open>;
    using close_action        = action_wrapper<"close"_n,        &warforzvault::close>;
    using burn_action         = action_wrapper<"burn"_n,         &warforzvault::burn>;
    using setfee_action       = action_wrapper<"setfee"_n,       &warforzvault::setfee>;
    using feeapply_action     = action_wrapper<"feeapply"_n,     &warforzvault::feeapply>;
    using feecancel_action    = action_wrapper<"feecancel"_n,    &warforzvault::feecancel>;
    using exemptadd_action    = action_wrapper<"exemptadd"_n,    &warforzvault::exemptadd>;
    using exemptlock_action   = action_wrapper<"exemptlock"_n,   &warforzvault::exemptlock>;
    using exemptunlock_action = action_wrapper<"exemptunlock"_n, &warforzvault::exemptunlock>;
    using exemptdel_action    = action_wrapper<"exemptdel"_n,    &warforzvault::exemptdel>;
    using logburn_action      = action_wrapper<"logburn"_n,      &warforzvault::logburn>;

private:
    // =======================================================================
    //  TABLES
    //  `account` and `currency_stats` are the eosio.token standard layout and
    //  must not change. `feeconfig` and `feeexempt` are additive.
    // =======================================================================

    // -------- Per-holder balance (scope = owner) --------------------------
    // One row per symbol held. Keyed by the symbol CODE (not the full symbol),
    // so a precision change would collide — which is another reason precision
    // is frozen at `create` time.
    TABLE account {
        asset balance;
        uint64_t primary_key() const { return balance.symbol.code().raw(); }
    };

    // -------- Per-symbol supply state (scope = symbol code) ---------------
    TABLE currency_stats {
        asset supply;                   // currently in circulation
        asset max_supply;               // hard ceiling, set once by `create`
        name  issuer;                   // only account that may issue/retire
        uint64_t primary_key() const { return supply.symbol.code().raw(); }
    };

    // -------- Transfer-fee policy, per symbol (scope = _self) -------------
    // Deliberately NOT folded into `currency_stats`: that row's layout is the
    // eosio.token standard that wallets and indexers deserialize, and adding a
    // field would break them. A missing row means "no fee".
    TABLE feeconfig {
        symbol         token_symbol;    // the symbol this policy governs
        uint16_t       transfer_fee_bps;// live rate; 50 == 0.50%, 0 disables
        uint16_t       pending_fee_bps; // announced increase awaiting `feeapply`
        time_point_sec pending_at;      // when it may be applied (epoch 0 = none)
        // True once a non-zero rate has EVER been live for this symbol. Makes
        // the "first activation is immediate" allowance strictly one-shot, so
        // setting the fee to 0 and back up cannot be used to skip the timelock.
        bool           activated;
        uint64_t primary_key() const { return token_symbol.code().raw(); }
    };

    // -------- Fee-exempt accounts (scope = _self) -------------------------
    // Exemption applies in BOTH directions and across every symbol. Intended
    // for contracts that credit an internal ledger from transfer notifications
    // (which carry the gross amount) plus treasury/liquidity accounts.
    TABLE feeexempt {
        name   account;                 // primary key
        string reason;                  // on-chain record of why; not used in logic
        // Load-bearing: this row cannot be deleted, and cannot be unlocked
        // while any fee is live. See `exemptunlock`.
        bool   locked;
        uint64_t primary_key() const { return account.value; }
        // Secondary index: answer "does any locked exemption exist?" in
        // O(log n) instead of scanning, since `setfee` and `feeapply` both
        // depend on it and the table has no size bound.
        uint64_t by_locked() const { return locked ? 1 : 0; }
    };

    typedef multi_index<"accounts"_n,  account>        accounts;
    typedef multi_index<"stat"_n,      currency_stats> stats;
    typedef multi_index<"feeconfig"_n, feeconfig>      feeconfigs;
    typedef multi_index<"feeexempt"_n, feeexempt,
        indexed_by<"bylocked"_n, const_mem_fun<feeexempt, uint64_t, &feeexempt::by_locked>>
    > feeexempts;

    // ----- balance helpers (see .cpp) -------------------------------------
    // Debit `owner`. Asserts the row exists and holds enough.
    void sub_balance(name owner, const asset& value);
    // Credit `owner`, billing a brand-new row to `ram_payer`. Credits to an
    // existing row use same_payer and therefore need no RAM.
    void add_balance(name owner, const asset& value, name ram_payer);
    // Shared validation for issue/retire/burn/transfer: symbol validity, memo
    // length, positive amount, and precision match against the stat row.
    // Returns the stat row so callers that move supply already hold it.
    const currency_stats& require_symbol(stats& statstable, const asset& quantity,
                                         const string& memo, const char* positive_msg);

    // ----- fee helpers -----------------------------------------------------
    // Fee in token units for this transfer; 0 when no policy is configured, the
    // rate is 0, or either party is exempt. Static so `get_net_transfer` can
    // quote it for an arbitrary token account.
    static int64_t fee_units(name token_contract_account, name from, name to,
                             const asset& quantity);
    static bool is_fee_exempt(name token_contract_account, name account);
    // True while ANY symbol has a non-zero live or pending rate. Gates
    // `exemptunlock`, so a protected exemption can only be released once the
    // fee that made it load-bearing is switched off.
    bool any_fee_configured();
    // True when at least one exemption is locked. Gates enabling a fee, so the
    // "turned the fee on before registering exemptions" mistake cannot happen.
    bool has_locked_exemption();
    // Emit the burn receipt (see `logburn`).
    void send_burn_receipt(name from, name to, const asset& fee);
};
