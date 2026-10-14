// ============================================================================
//  warforzvault.cpp — implementation of the Warforz Lands SILVER token.
//
//  Section map:
//    1. Helpers (validation, balance mutation, fee computation, receipts)
//    2. Supply management — create / issue / retire / setissuer
//    3. Movement — transfer (charges + burns the fee)
//    4. Balance-row lifecycle — open / close
//    5. Economy sink — burn
//    6. Fee policy — setfee / feeapply / feecancel
//    7. Fee exemptions — exemptadd / exemptlock / exemptunlock / exemptdel
//    8. Inline receipt — logburn
//
//  Sections 2-5 are standard `eosio.token` semantics, except `setissuer`,
//  `burn`, and the fee deduction inside `transfer`. See the header for why each
//  exists and what the fee's residual risk is.
// ============================================================================
#include "warforzvault.hpp"

// ===========================================================================
//  1. HELPERS
// ===========================================================================

// Shared front-half validation for issue / retire / transfer / burn.
//
// Returns the `stat` row for the symbol, so callers that move supply already
// hold it. The precision check is the important one: `asset` compares symbols
// including precision, so a "1000 SILVER" (precision 0) payload can never be
// mistaken for "1000.0000 SILVER".
const warforzvault::currency_stats& warforzvault::require_symbol(
        stats& statstable, const asset& quantity, const string& memo,
        const char* positive_msg) {
    check(quantity.symbol.is_valid(), "invalid symbol name");
    check(memo.size() <= MAX_MEMO_BYTES, "memo has more than 256 bytes");

    const auto& st = statstable.get(quantity.symbol.code().raw(),
                                    "token with symbol does not exist");

    check(quantity.is_valid(), "invalid quantity");
    check(quantity.amount > 0, positive_msg);
    check(quantity.symbol == st.supply.symbol, "symbol precision mismatch");
    return st;
}

// Debit `owner`. The row must already exist — you cannot spend from a balance
// you never had — and `same_payer` keeps the existing RAM payer in place.
void warforzvault::sub_balance(name owner, const asset& value) {
    accounts from_acnts(get_self(), owner.value);

    const auto& from = from_acnts.get(value.symbol.code().raw(), "no balance object found");
    check(from.balance.amount >= value.amount, "overdrawn balance");

    from_acnts.modify(from, same_payer, [&](auto& a) { a.balance -= value; });
}

// Credit `owner`. Only a brand-new row costs RAM (billed to `ram_payer`);
// topping up an existing row uses `same_payer` and is therefore free, which is
// what makes `open` worth calling ahead of a high-frequency transfer stream.
void warforzvault::add_balance(name owner, const asset& value, name ram_payer) {
    accounts to_acnts(get_self(), owner.value);

    auto to = to_acnts.find(value.symbol.code().raw());
    if (to == to_acnts.end()) to_acnts.emplace(ram_payer, [&](auto& a) { a.balance = value; });
    else                      to_acnts.modify(to, same_payer, [&](auto& a) { a.balance += value; });
}

// Is this account excused from the transfer fee? Exemption is symbol-agnostic
// and applies whether the account is the sender or the receiver.
bool warforzvault::is_fee_exempt(name token_contract_account, name account) {
    feeexempts exempt(token_contract_account, token_contract_account.value);
    return exempt.find(account.value) != exempt.end();
}

// The burned fee, in token units, for one transfer.
//
// Returns 0 — i.e. transfers at par — when the symbol has no fee policy, the
// configured rate is 0, or EITHER party is exempt. "Either party" is what lets
// a single `feeexempt` row cover both directions of a contract's traffic.
//
// The stored rate is CLAMPED to MAX_TRANSFER_FEE_BPS here rather than trusted.
// `setfee` already bounds what it writes, but keeping the bound next to the
// arithmetic that depends on it means a row written under an older, higher
// ceiling can never take effect, and the int64 cast below cannot overflow.
//
// The multiply is done in int128 because `amount * bps` overflows int64 for
// large balances (asset tops out near 4.6e18). This mirrors
// `warforzlands::bps_of`, so a rate means the same thing on both sides of the
// integration. Integer division truncates, so the fee rounds DOWN in the
// holder's favour, and transfers too small to yield one unit of fee move at par
// (at 0.50% and 4-decimal precision, anything under 0.0200 SILVER).
int64_t warforzvault::fee_units(name token_contract_account, name from, name to,
                                const asset& quantity) {
    feeconfigs fees(token_contract_account, token_contract_account.value);
    auto it = fees.find(quantity.symbol.code().raw());
    if (it == fees.end() || it->transfer_fee_bps == 0) return 0;

    if (is_fee_exempt(token_contract_account, from) ||
        is_fee_exempt(token_contract_account, to)) return 0;

    uint16_t bps = it->transfer_fee_bps;
    if (bps > MAX_TRANSFER_FEE_BPS) bps = MAX_TRANSFER_FEE_BPS;

    return (int64_t)((__int128)quantity.amount * (__int128)bps / (__int128)BPS);
}

// True while ANY symbol has a non-zero live or pending rate. The scan is bounded
// by the number of symbols this contract hosts (one, in practice).
bool warforzvault::any_fee_configured() {
    feeconfigs fees(get_self(), get_self().value);
    for (auto it = fees.begin(); it != fees.end(); ++it)
        if (it->transfer_fee_bps > 0 || it->pending_fee_bps > 0) return true;
    return false;
}

// True when at least one exemption is locked. Uses the "bylocked" secondary
// index so this stays O(log n) no matter how many exemptions accumulate.
bool warforzvault::has_locked_exemption() {
    feeexempts exempt(get_self(), get_self().value);
    auto idx = exempt.get_index<"bylocked"_n>();
    return idx.find(1) != idx.end();
}

// Emit the burn receipt. Self-authenticated, stateless, and WITHOUT
// `require_recipient` — see the `logburn` declaration for why that matters.
void warforzvault::send_burn_receipt(name from, name to, const asset& fee) {
    action(permission_level{get_self(), name("active")}, get_self(), name("logburn"),
           std::make_tuple(from, to, fee)).send();
}

// ===========================================================================
//  2. SUPPLY MANAGEMENT  (auth = contract / issuer)
// ===========================================================================

// Register the symbol. Runs exactly once per symbol code, and there is no
// action that can raise `max_supply` afterwards — pick the ceiling carefully.
ACTION warforzvault::create(name issuer, asset maximum_supply) {
    require_auth(get_self());

    auto sym = maximum_supply.symbol;
    check(sym.is_valid(), "invalid symbol name");
    check(maximum_supply.is_valid(), "invalid supply");
    check(maximum_supply.amount > 0, "max-supply must be positive");
    check(is_account(issuer), "issuer account does not exist");

    stats statstable(get_self(), sym.code().raw());
    check(statstable.find(sym.code().raw()) == statstable.end(),
          "token with symbol already exists");

    statstable.emplace(get_self(), [&](auto& s) {
        s.supply.symbol = maximum_supply.symbol;   // starts at 0 of that symbol
        s.max_supply    = maximum_supply;
        s.issuer        = issuer;
    });
}

// Mint into the issuer's own balance. `to` must be the issuer: minting and
// distributing stay separate actions so each is independently auditable in the
// transaction history. Issuance credits the balance directly and so is never
// subject to the transfer fee.
ACTION warforzvault::issue(name to, asset quantity, string memo) {
    stats statstable(get_self(), quantity.symbol.code().raw());
    const auto& st = require_symbol(statstable, quantity, memo, "must issue positive quantity");

    check(to == st.issuer, "tokens can only be issued to issuer account");
    require_auth(st.issuer);

    check(quantity.amount <= st.max_supply.amount - st.supply.amount,
          "quantity exceeds available supply");

    statstable.modify(st, same_payer, [&](auto& s) { s.supply += quantity; });
    add_balance(st.issuer, quantity, st.issuer);
}

// Destroy tokens sitting in the issuer's balance. `max_supply` is untouched,
// so retired headroom can be issued again later.
ACTION warforzvault::retire(asset quantity, string memo) {
    stats statstable(get_self(), quantity.symbol.code().raw());
    const auto& st = require_symbol(statstable, quantity, memo, "must retire positive quantity");

    require_auth(st.issuer);

    statstable.modify(st, same_payer, [&](auto& s) { s.supply -= quantity; });
    sub_balance(st.issuer, quantity);
}

// Rotate the issuer under DUAL authority: the current issuer AND the contract
// account must both sign. Neither key alone can move minting rights, so a
// single compromise cannot seize the token or lock the project out of it.
ACTION warforzvault::setissuer(const symbol& token_symbol, name new_issuer) {
    require_auth(get_self());

    check(token_symbol.is_valid(), "invalid symbol name");
    check(is_account(new_issuer), "new issuer account does not exist");

    auto sym_code_raw = token_symbol.code().raw();
    stats statstable(get_self(), sym_code_raw);
    const auto& st = statstable.get(sym_code_raw, "token with symbol does not exist");
    check(st.supply.symbol == token_symbol, "symbol precision mismatch");

    require_auth(st.issuer);                       // second, independent key
    check(new_issuer != st.issuer, "issuer is already set to that account");

    statstable.modify(st, same_payer, [&](auto& s) { s.issuer = new_issuer; });
}

// ===========================================================================
//  3. MOVEMENT
// ===========================================================================

// Transfer, with the burned fee applied.
//
// `require_recipient` on BOTH parties is what makes the game contract's
// `[[eosio::on_notify("*::transfer")]]` handler fire, so a player depositing
// SILVER into `warforzlands` is credited in-game by the same transaction.
// Removing either notification would silently break deposits.
//
// FEE SEMANTICS: the sender is debited the full `quantity`; the recipient is
// credited `quantity - fee`; the fee is destroyed, lowering `supply`. The
// notification a receiving contract sees still carries the GROSS `quantity` —
// that is the action's own argument and cannot be rewritten — which is exactly
// why ledger-keeping contracts must be exempt. See the header warning.
ACTION warforzvault::transfer(name from, name to, asset quantity, string memo) {
    check(from != to, "cannot transfer to self");
    require_auth(from);
    check(is_account(to), "to account does not exist");

    stats statstable(get_self(), quantity.symbol.code().raw());
    const auto& st = require_symbol(statstable, quantity, memo, "must transfer positive quantity");

    require_recipient(from);
    require_recipient(to);

    // Whoever authorized the transfer pays for a new balance row on the
    // receiving side; if the receiver signed too, it is billed to them.
    name payer = has_auth(to) ? to : from;

    asset fee(fee_units(get_self(), from, to, quantity), quantity.symbol);
    asset net = quantity - fee;
    // Unreachable while MAX_TRANSFER_FEE_BPS stays below 100%, but it keeps a
    // future rate change from ever delivering a zero or negative amount.
    check(net.amount > 0, "transfer amount is too small to cover the fee");

    sub_balance(from, quantity);
    add_balance(to, net, payer);

    if (fee.amount > 0) {
        statstable.modify(st, same_payer, [&](auto& s) { s.supply -= fee; });
        send_burn_receipt(from, to, fee);
    }
}

// ===========================================================================
//  4. BALANCE-ROW LIFECYCLE  (RAM management)
// ===========================================================================

// Pre-create a zero balance row. Two reasons to call it: the receiver takes
// ownership of its own RAM instead of the sender paying, and a later transfer
// cannot fail for lack of RAM at the payer.
ACTION warforzvault::open(name owner, const symbol& symbol, name ram_payer) {
    require_auth(ram_payer);
    check(is_account(owner), "owner account does not exist");

    auto sym_code_raw = symbol.code().raw();
    stats statstable(get_self(), sym_code_raw);
    const auto& st = statstable.get(sym_code_raw, "symbol does not exist");
    check(st.supply.symbol == symbol, "symbol precision mismatch");

    accounts acnts(get_self(), owner.value);
    if (acnts.find(sym_code_raw) == acnts.end())
        acnts.emplace(ram_payer, [&](auto& a) { a.balance = asset{0, symbol}; });
}

// Delete an empty balance row and reclaim its RAM. Refuses while a balance is
// held, so RAM can never be reclaimed at the cost of losing tokens.
ACTION warforzvault::close(name owner, const symbol& symbol) {
    require_auth(owner);

    accounts acnts(get_self(), owner.value);
    auto it = acnts.find(symbol.code().raw());
    check(it != acnts.end(), "Balance row already deleted or never existed. Action won't have any effect.");
    check(it->balance.amount == 0, "Cannot close because the balance is not zero.");

    acnts.erase(it);
}

// ===========================================================================
//  5. ECONOMY SINK
// ===========================================================================

// Any holder destroys their own tokens. Economy V1 §13 routes FT out of
// circulation through healing, crafting, repairs, slot unlocks, rerolls and
// fees; those sinks accumulate wherever the game sends them, not in the issuer
// balance, so plain `retire` could not reach them without a round trip.
//
// Accounting is identical to `retire`: `supply` falls, `max_supply` does not.
ACTION warforzvault::burn(name owner, asset quantity, string memo) {
    require_auth(owner);

    stats statstable(get_self(), quantity.symbol.code().raw());
    const auto& st = require_symbol(statstable, quantity, memo, "must burn positive quantity");

    sub_balance(owner, quantity);
    statstable.modify(st, same_payer, [&](auto& s) { s.supply -= quantity; });
}

// ===========================================================================
//  6. FEE POLICY  (auth = contract)
// ===========================================================================

// Set the burned transfer fee for a symbol.
//
// Three timing paths, all enforced here rather than left to an operator:
//   * DECREASE (including to 0)  -> applies immediately; always holder-favourable.
//   * FIRST activation           -> applies immediately, but only if a locked
//                                   exemption already exists. That precondition,
//                                   not a delay, is what guards the deployment
//                                   ordering hazard.
//   * LATER increase             -> written as a pending change, applied by
//                                   `feeapply` after FEE_TIMELOCK_SEC.
//
// `activated` makes the immediate-first-activation allowance strictly one-shot,
// so dropping the rate to 0 and raising it again cannot be used to skip the
// notice period.
ACTION warforzvault::setfee(const symbol& token_symbol, uint16_t transfer_fee_bps) {
    require_auth(get_self());
    check(token_symbol.is_valid(), "invalid symbol name");
    check(transfer_fee_bps <= MAX_TRANSFER_FEE_BPS,
          "transfer fee exceeds the contract's maximum of 2.00%");

    auto sym_code_raw = token_symbol.code().raw();
    stats statstable(get_self(), sym_code_raw);
    const auto& st = statstable.get(sym_code_raw, "token with symbol does not exist");
    check(st.supply.symbol == token_symbol, "symbol precision mismatch");

    // The ordering guard: a fee can never exist without at least one exemption
    // deliberately marked load-bearing.
    if (transfer_fee_bps > 0)
        check(has_locked_exemption(),
              "lock at least one fee exemption before enabling a fee");

    feeconfigs fees(get_self(), get_self().value);
    auto it = fees.find(sym_code_raw);

    if (it == fees.end()) {
        fees.emplace(get_self(), [&](auto& r) {
            r.token_symbol     = token_symbol;
            r.transfer_fee_bps = transfer_fee_bps;
            r.pending_fee_bps  = 0;
            r.pending_at       = time_point_sec(0);
            r.activated        = transfer_fee_bps > 0;
        });
        return;
    }

    const bool immediate = transfer_fee_bps <= it->transfer_fee_bps  // a decrease
                        || !it->activated;                           // first activation

    fees.modify(it, get_self(), [&](auto& r) {
        if (immediate) {
            r.transfer_fee_bps = transfer_fee_bps;
            r.pending_fee_bps  = 0;
            r.pending_at       = time_point_sec(0);
            if (transfer_fee_bps > 0) r.activated = true;
        } else {
            r.pending_fee_bps = transfer_fee_bps;
            r.pending_at      = time_point_sec(
                current_time_point().sec_since_epoch() + FEE_TIMELOCK_SEC);
        }
    });
}

// Promote a pending fee increase once its notice period has elapsed.
//
// Re-checks every precondition that guarded the original request: the notice
// period is long enough that the ceiling or the exemption set may have changed
// since, and a matured request must not be able to bypass the current rules.
ACTION warforzvault::feeapply(const symbol& token_symbol) {
    require_auth(get_self());

    feeconfigs fees(get_self(), get_self().value);
    auto it = fees.find(token_symbol.code().raw());
    check(it != fees.end(), "no fee policy exists for that symbol");
    check(it->token_symbol == token_symbol, "symbol precision mismatch");
    check(it->pending_at.sec_since_epoch() != 0, "no pending fee change");
    check(current_time_point().sec_since_epoch() >= it->pending_at.sec_since_epoch(),
          "the fee change notice period has not elapsed");

    check(it->pending_fee_bps <= MAX_TRANSFER_FEE_BPS,
          "pending fee exceeds the contract's current maximum");
    if (it->pending_fee_bps > 0)
        check(has_locked_exemption(),
              "lock at least one fee exemption before enabling a fee");

    fees.modify(it, get_self(), [&](auto& r) {
        r.transfer_fee_bps = r.pending_fee_bps;
        r.pending_fee_bps  = 0;
        r.pending_at       = time_point_sec(0);
        r.activated        = true;
    });
}

// Abandon a pending fee increase before it matures.
ACTION warforzvault::feecancel(const symbol& token_symbol) {
    require_auth(get_self());

    feeconfigs fees(get_self(), get_self().value);
    auto it = fees.find(token_symbol.code().raw());
    check(it != fees.end(), "no fee policy exists for that symbol");
    check(it->pending_at.sec_since_epoch() != 0, "no pending fee change");

    fees.modify(it, get_self(), [&](auto& r) {
        r.pending_fee_bps = 0;
        r.pending_at      = time_point_sec(0);
    });
}

// ===========================================================================
//  7. FEE EXEMPTIONS  (auth = contract)
// ===========================================================================

// Excuse an account from the fee in both directions, for every symbol.
//
// REQUIRED for any contract that credits an internal ledger from a transfer
// notification: the notification carries the gross amount, so without an
// exemption such a contract credits more than it receives and drifts into
// deficit. `warforzlands` and its configured fee account are exactly that case.
//
// New rows start UNLOCKED. Re-calling on an existing row updates only `reason`
// and never clears `locked` — otherwise this would be an unlock backdoor around
// `exemptunlock`'s fee-must-be-off requirement.
ACTION warforzvault::exemptadd(name account, string reason) {
    require_auth(get_self());
    check(is_account(account), "account does not exist");
    check(reason.size() <= MAX_MEMO_BYTES, "reason has more than 256 bytes");

    feeexempts exempt(get_self(), get_self().value);
    auto it = exempt.find(account.value);
    if (it == exempt.end())
        exempt.emplace(get_self(), [&](auto& r) {
            r.account = account;
            r.reason  = reason;
            r.locked  = false;
        });
    else
        exempt.modify(it, get_self(), [&](auto& r) { r.reason = reason; });
}

// Mark an exemption load-bearing. Lock every exemption whose removal would
// break an integration's accounting — at minimum the game contract and the
// configured fee account.
ACTION warforzvault::exemptlock(name account) {
    require_auth(get_self());

    feeexempts exempt(get_self(), get_self().value);
    auto it = exempt.find(account.value);
    check(it != exempt.end(), "account is not fee-exempt");
    check(!it->locked, "exemption is already locked");

    exempt.modify(it, get_self(), [&](auto& r) { r.locked = true; });
}

// Release a protected exemption — but only once every fee is switched off.
//
// This is the invariant that makes the design safe: a locked exemption can
// never be pulled out from under a LIVE fee, so no integration is ever exposed
// silently or mid-flight. Stripping one always costs a visible, deliberate
// "turn the whole fee off first".
//
// It does NOT pin any particular account. `has_locked_exemption` only asks
// whether SOME lock exists, so with two locked rows an admin can still zero the
// fee, unlock and delete one, and re-enable — leaving that integration exposed.
// Pinning identities is not something the contract can do (audit M7).
ACTION warforzvault::exemptunlock(name account) {
    require_auth(get_self());

    feeexempts exempt(get_self(), get_self().value);
    auto it = exempt.find(account.value);
    check(it != exempt.end(), "account is not fee-exempt");
    check(it->locked, "exemption is not locked");
    check(!any_fee_configured(),
          "set every transfer fee to 0 before unlocking a protected exemption");

    exempt.modify(it, get_self(), [&](auto& r) { r.locked = false; });
}

// Remove an exemption. Refused while locked, so revoking a critical one is
// always a deliberate two-step through `exemptunlock`.
ACTION warforzvault::exemptdel(name account) {
    require_auth(get_self());

    feeexempts exempt(get_self(), get_self().value);
    auto it = exempt.find(account.value);
    check(it != exempt.end(), "account is not fee-exempt");
    check(!it->locked, "exemption is locked; call exemptunlock first");

    exempt.erase(it);
}

// ===========================================================================
//  8. INLINE RECEIPT
// ===========================================================================

// Trace-only record of a burned transfer fee. No state change, no recipient
// dispatch — see the declaration in the header for why `require_recipient` is
// deliberately absent.
ACTION warforzvault::logburn(name from, name to, asset fee) {
    require_auth(get_self());
}
