# Warforz Vault (SILVER token) — Contract Audit

Date: 2026-08-17 (revision 3 — re-verified against the current build; supersedes revision 2 — post-hardening)
Scope: `SC/silvertoken/src/warforzvault.cpp` (421 lines), `SC/silvertoken/include/warforzvault.hpp` (327 lines), Ricardian `.md` files, `tests/static_contract_checks.ps1`, `CMakeLists.txt`, `README.md`
Coverage: all **16 actions**, all **8 private helpers**, all **4 tables**, and the integration surface with `warforzlands`
Build audited: WASM SHA-256 `12362a1abd88acfd8b8164ec39b714454ca9be54581a0965cb2bba871e3793e0` (CDT 4.1.1, 0 errors, 0 warnings). **Not deployed to any chain, and never executed.**

**Revision 3 re-verification (2026-08-17).** Re-checked against current source
after the CDT 4.1.1 rebuild and the Ricardian format change. No functional code
changed since revision 2 — those edits touched comments and build inputs only.
Confirmed mechanically: all 16 actions carry `require_auth`; supply and balance
move together on all four mutating paths (`issue`, `retire`, `transfer`,
`burn`) with no path moving one without the other; all four fee-safety guards
are still wired (`has_locked_exemption`, `any_fee_configured`,
`MAX_TRANSFER_FEE_BPS` clamp, `activated` one-shot). Static checks pass.
**All revision 2 findings stand as written.**

See also [WARFORZ_SYSTEM_AUDIT.md](WARFORZ_SYSTEM_AUDIT.md) for the integration
with `warforzlands`, which no single-contract audit covers.

**Method:** line-by-line source review, plus the repeatable structural check in `SC/silvertoken/tests/static_contract_checks.ps1` (action declaration/definition parity, EOSIO name-length and charset limits, `action_wrapper` name matching, helper definition coverage, `eosio.token` table-layout integrity, notification-dispatch limits, and the presence of the four fee-safety guards). All checks pass.

**Not done:** no unit tests, no testnet execution, no fuzzing, no formal verification. Compilation and ABI inspection have been done; **no code in this contract has ever executed.** The author of this audit is also the author of the contract, which is a real limitation — an independent review is still required before mainnet.

---

## Revision 2 status

Revision 1 raised 3 High, 6 Medium, 8 Low. Hardening has since been applied.

| # | Finding | Status |
|---|---|---|
| **H1** | Fee correctness depends on an admin-maintained table | **Partially resolved** → now M7 |
| **H2** | `exemptdel` can silently break the game | **Resolved** |
| **H3** | Contract account retains upgrade authority | **Open** — deployment action, not fixable in code |
| **M1** | Issuer immutable after `create` | **Resolved** |
| **M2** | `max_supply` permanent and still a placeholder | **Open** — your decision |
| **M3** | Burned fee leaves no action trace | **Resolved** |
| **M4** | `setfee` can jump to the ceiling instantly | **Resolved** |
| **M5** | Fee-on-transfer breaks exchanges/DEXes/bridges | **Open** — inherent to the model |
| **M6** | Never compiled, no test suite | **Compiles cleanly**; test suite still open |
| **L1** | `fee_units` trusts stored bps | **Resolved** |
| **L2** | Extra table lookups on the hot path | **Accepted** |
| **L3** | `BPS` collides with `warforzlands.hpp` | **Resolved** |
| **L4** | `using namespace eosio;` in a header | **Accepted** — matches project convention |
| **L5** | Dust-splitting below the truncation threshold | **Accepted** — correct trade-off |
| **L6** | No pause/freeze/blacklist | **Accepted** — deliberate |
| **L7** | Policy changes emit no receipt | **No change needed** — see below |
| **L8** | Issuer cannot fund the game directly | **Documented** |

Current standing: **1 High, 4 Medium, 4 Low** carried forward, plus 4 new findings introduced by the hardening itself (M8, N1–N3). M8 in particular is a correction to a guarantee this revision initially overstated — read it before relying on the lock mechanism.

---

## Summary

| Severity | Count | Findings |
|---|---|---|
| **High** | 1 | H3 |
| **Medium** | 6 | M2, M5, M6, M7, M8, N1 |
| **Low** | 6 | L2, L4, L5, L6, N2, N3 |

**No finding allows an unauthorized party to mint, steal, or freeze another holder's tokens.** The authorization model is correct on every action, and the core accounting invariant holds on every mutating path.

The single remaining High is **not a code defect** — it is key custody, which no amount of contract code can fix.

### What is solid

- **The supply invariant holds.** `supply == sum(all balances)` is preserved on all five mutating paths: `issue` (+q/+q), `retire` (−q/−q), `burn` (−q/−q), `transfer` (−fee to both sides), and `create` (0/0). I traced each one; there is no path that moves one without the other.
- **Authorization is correct and complete.** `create`/`setfee`/`feeapply`/`feecancel`/`exempt*`/`logburn` require `get_self()`; `issue`/`retire` require `st.issuer`; `setissuer` requires **both**; `transfer`/`burn` require the holder; `close` requires the owner; `open` requires the RAM payer. No action is missing a check.
- **The fee-safety ordering hazards are closed on-chain.** A fee cannot be enabled while no exemption is locked ([:338](SC/silvertoken/src/warforzvault.cpp#L338)), re-checked when a pending increase matures ([:391](SC/silvertoken/src/warforzvault.cpp#L391)); a locked exemption cannot be unlocked while any fee is live ([:475](SC/silvertoken/src/warforzvault.cpp#L475)) and cannot be deleted at all. **No exemption can be pulled out from under a live fee** — stripping one always costs a visible, deliberate "turn every fee off first", so nothing is ever exposed silently or mid-flight. See M8 for the limit of this guarantee.
- **No negative balances or supply.** `sub_balance` asserts sufficiency before debiting, and every supply decrease is paired with a balance decrease that must succeed first or in the same transaction — so `asset::operator-=`, which permits negative results down to `-max_amount`, is never reached with an underflowing value.
- **Standard table layouts are intact**, and the static check enforces that they stay that way. `stat` and `accounts` carry the exact `eosio.token` field order and types, so wallets, explorers and light-API indexers read balances without special-casing. The governance tables are separate and contract-scoped.
- **Integer money math.** The fee multiply uses `__int128` intermediates and the stored rate is clamped to the ceiling at read time ([:101](SC/silvertoken/src/warforzvault.cpp#L101)), so the `int64` cast cannot overflow regardless of what is in the table. Truncation rounds in the holder's favour.
- **The receipt cannot be weaponized.** `logburn` is self-authenticated, stateless, and deliberately omits `require_recipient` — the exact pattern that produced finding H1 of the game contract's own audit, where a player's account code could revert a settlement. The static check enforces its absence.
- **No reentrancy surface.** Antelope dispatches notifications after the action completes, so a notified party cannot re-enter `transfer` mid-execution. The `st` reference from `require_symbol` stays valid across `sub_balance`/`add_balance` because those touch a different table.

---

## HIGH

### H3 — The contract account retains upgrade authority over a value-bearing token

**Status: open. This is the most important item in this document, and it cannot be closed by writing code.**

Whoever holds `warforzvault@active` can `set contract` at any time and replace this code with anything — mint past `max_supply`, rewrite balances, remove the fee ceiling, strip the exemption guards, drain holders. Every guarantee in this audit holds only for the currently-deployed code, and nothing prevents that code from changing.

The same key currently also holds `create`, `setfee`, `feeapply`, all four `exempt*` actions, and — under the README's default of `issuer = warforzvault` — `issue`. That is a single point of compromise for the entire economy.

`setissuer` (added in this revision) reduces the blast radius by making issuer rotation require two keys, but only if you actually split them.

**Recommendation, before the token has any market value:**

1. **Split the issuer from the contract account at `create` time.** `setissuer` can rotate later, but it needs both keys, so start with them separate.
2. Put both behind `eosio.msig` multisig permissions.
3. Once the code is final, resign the contract account's `owner`/`active` to `eosio.prods` or a locked multisig so the code becomes effectively immutable — and publish that fact. Note this also freezes `setissuer` and every fee action, which is the point.

---

## MEDIUM

### M7 — Residual: the contract cannot know *which* accounts need exemption

*(Downgraded from H1. The enforceable half is now enforced; this is what remains.)*

The two ordering hazards are closed on-chain (see "What is solid"). What is **not** enforceable is identity: nothing can tell the contract that a newly deployed marketplace, bridge, staking contract or exchange deposit processor keeps an internal ledger and therefore needs exempting.

The failure mode remains silent. A new integration that credits from the gross `quantity` in a transfer notification will under-collateralize itself by 0.5% per deposit, and neither contract will detect it.

This is inherent to fee-on-transfer and is the residual cost of the design.

**Recommendation.** Make "add a locked `feeexempt` row" a mandatory step in the integration checklist for every future contract that touches SILVER, and have each such contract's own deploy script assert its exemption exists before going live. If the deflationary goal can be met another way — burning at the game's sinks, where the amount and the accounting are already in the same place — that removes this class of risk entirely rather than managing it.

### M8 — The lock guard counts exemptions; it does not pin identities

**New in revision 2, and a correction to an overstated claim.** `has_locked_exemption()` asks only whether *at least one* locked row exists. It does not and cannot assert that `warforzlands` specifically is exempt.

Concrete consequence: with both `warforzlands` and `warforzfees1` locked, an admin can still reach an exposed state in four deliberate steps — `setfee 0`, `exemptunlock warforzlands`, `exemptdel warforzlands`, `setfee 50`. The final `setfee` passes because `warforzfees1`'s lock still satisfies the guard.

What the guards genuinely buy is the removal of *silent* and *mid-flight* failure: every route to an exposed state now passes through switching the fee off, which is visible on-chain and deliberate. That is a large improvement over revision 1, where a single `exemptdel` did it instantly with a live fee. But it is not the absolute guarantee revision 2 initially claimed, and the code comments and README have been corrected to match.

**Recommendation.** If you want identity pinning, store a per-symbol list of accounts that must hold an exemption before that symbol's fee may be non-zero, and have `setfee`/`feeapply` verify every entry. That converts M8 into a genuine invariant at the cost of one more admin-managed list — which is only worth it if the operator set is larger than one or two trusted people.

### M2 — `max_supply` is permanent and the configured value is still a placeholder

**Status: open — your decision, deliberately deferred.**

Fixed forever by `create`, with no action to raise it. The README's `1000000000.0000 SILVER` is explicitly labelled a placeholder and is not derived from the economy document, which does not state a total supply anywhere.

At ~210 FT average gross per mine and ~10 mines/day, 1 billion covers roughly 15 months at 1,000 daily actives, or about 3 months at 5,000. Because `warforzlands` sinks do **not** recycle into the reward pool (they are debited from player ledgers and left unallocated in the contract), the pool drains at the gross rate and must be continuously refunded from new issuance.

**Recommendation.** Resolve the supply figure and the sink-recycling design together — they are the same decision. Wiring the game's sinks to `burn` makes a 1B cap sustainable; leaving them stranded does not.

### M5 — Fee-on-transfer is broadly incompatible with exchanges, DEXes and bridges

**Status: open — inherent to the model, not fixable in code.**

A token that delivers less than the amount stated in the transfer is rejected or mishandled by a large fraction of third-party infrastructure. Automated market makers compute reserves from stated amounts, exchange deposit processors credit the gross, and bridges mint the gross on the destination chain. Usual outcomes: stuck deposits, failed swaps, or listing refusal.

The exemption table can solve this case by case, but only for counterparties who use fixed accounts and tell you which ones in advance.

**Recommendation.** Confirm the fee against your listing and liquidity plans before mainnet. If SILVER is intended to trade on Alcor or any WAX DEX or bridge, expect to exempt those contracts, and verify with each one that exemption is sufficient for their integration.

### M6 — No unit test suite exists

**Status: compilation resolved; testing still open.**

**The contract now compiles.** Built with CDT 4.1.1 via the project's own
`warforz-cdt:4.1.1` Docker image:

| | |
|---|---|
| `build/warforzvault.wasm` | 35,254 bytes |
| `build/warforzvault.abi` | 15,200 bytes, `eosio::abi/1.2` |
| WASM SHA-256 | `12362a1abd88acfd8b8164ec39b714454ca9be54581a0965cb2bba871e3793e0` |
| Compiler diagnostics | 0 errors, 0 warnings |
| ABI actions | 16 of 16, all with Ricardian text |
| ABI clauses | 10 of 10 |

ABI verification confirms the two standard layouts survived intact — `account` is `balance:asset`, and `currency_stats` is `supply:asset, max_supply:asset, issuer:name` — so wallets and light-API indexers will read balances normally.

Two build-flag traps were found and are documented in the README: `-I .` is required alongside `-I include` (CDT's codegen pass runs from `/tmp`), and the Ricardian files must use `<h1 class="contract">` / `<h1 class="clause">` headings rather than markdown `##`, or they are silently dropped.

**What remains open:** there is still no unit or integration test suite. Compilation proves the code is well-formed, not that it is correct. Nothing has ever executed.

**Recommendation.** Cover at minimum: fee arithmetic at boundary amounts (1 unit, 199, 200, `max_supply`); the exemption matrix (neither/from/to/both exempt); the supply invariant across all five mutating paths; the timelock paths (decrease immediate, first activation immediate, later increase deferred, `feeapply` before and after maturity); the lock invariant (`exemptunlock` refused while a fee is live); and a full deposit round-trip against a testnet `warforzlands`.

### N1 — The `logburn` receipt makes fee-bearing transfers depend on `eosio.code`

**New in revision 2.** `transfer` now sends an inline `logburn` action when a fee is charged ([:248](SC/silvertoken/src/warforzvault.cpp#L248)). That requires the contract account to carry the `eosio.code` permission on `active`. If it is not granted, **every fee-bearing transfer reverts** — the token appears broken for ordinary wallet-to-wallet sends while all game traffic (fee-free) keeps working.

Mitigating factors: it fails loudly and immediately rather than silently, it is a one-line deployment step, and step 11 of the README's setup explicitly tests it.

**Recommendation.** Run `cleos set account permission warforzvault active --add-code` as part of deployment, and never skip README step 11. If you later resign the account to a locked multisig (H3), confirm `eosio.code` survives that change.

---

## LOW

### N2 — `setissuer`'s dual authority can become unusable after resigning the account

**New in revision 2.** `setissuer` requires both the current issuer and `warforzvault` itself ([:189](SC/silvertoken/src/warforzvault.cpp#L189)). If H3's recommendation is followed to its end and the contract account is resigned to `eosio.prods`, every future issuer rotation needs a WAX block-producer multisig to co-sign.

That is arguably correct for an immutable token — but it should be a decision, not a surprise. Decide the final issuer before resigning the account.

### N3 — The first fee activation has no notice period

**New in revision 2.** `setfee`'s one-shot immediate activation means a symbol's fee can go from 0 to the 2.00% ceiling in a single transaction with no announcement. The `activated` flag makes it strictly one-shot — the 0→raise loophole is closed — and the ceiling bounds the damage at 2%.

This is a deliberate trade-off: the deployment ordering hazard at first activation is guarded by the locked-exemption precondition, which is a stronger guarantee than a delay, and a timelock on first activation would make testnet iteration painful for no security gain. Recorded so the choice is explicit.

### L2 — Extra table lookups on the hottest path

**Status: accepted.** Every `transfer` does a `feeconfig` find plus up to two `feeexempt` finds, roughly doubling DB reads versus stock `eosio.token`. The early return when no `feeconfig` row exists limits the cost for unconfigured symbols, but once the fee is on, exempt traffic — all of the game's volume — still pays for two exemption lookups it cannot benefit from.

Measure after the first build. `has_locked_exemption` already uses the new `bylocked` secondary index so the admin paths stay O(log n) regardless of table size.

### L4 — `using namespace eosio;` and `using std::string;` at header scope

**Status: accepted.** Pollutes the global namespace for consumers. Matches `warforzlands.hpp`, so it is consistent with the project. The `BPS` / `MAX_MEMO_BYTES` collision that made this actively dangerous is fixed (L3) — those constants now live inside the contract class.

### L5 — Dust-splitting avoids the fee below the truncation threshold

**Status: accepted.** At 0.50% with 4 decimals, any transfer under `0.0200 SILVER` (200 units) yields a zero fee. Moving 1,000 SILVER fee-free would take ~50,000 separate transfers, so this is economically irrational at any plausible CPU price. Rounding up would remove it, at the cost of charging above the nominal rate on small transfers; rounding down in the holder's favour is the right choice.

### L6 — No pause, freeze, or blacklist mechanism

**Status: accepted, deliberate.** No way to halt transfers during an incident, and no way to freeze an account. This matches `eosio.token`. Such mechanisms are themselves a centralization risk and an attack surface, and H3 makes them partly moot — the key holder can already deploy a pause by upgrading the code.

### L7 — Policy changes emit no receipt

**Status: no change needed.** On reflection this was a weak finding. `setfee`, `exemptadd`, `exemptlock`, `exemptunlock` and `exemptdel` all carry their full effect in their own action arguments, which appear in block history; an indexer watching `warforzvault::setfee` sees the new rate directly. This is unlike the transfer fee, which was *computed* rather than passed and genuinely needed M3's receipt.

### L8 — Sending SILVER from `warforzvault` directly to `warforzlands` will fail

**Status: documented.** `warforzlands::on_token_transfer` treats any memo other than `rewardpool` as a player deposit and calls `check_tos_accepted(from)`, which asserts for an unregistered account; the `rewardpool` memo is only accepted from the configured fee account. A funding transfer straight from the issuer therefore reverts.

It fails safe, and the README now carries an explicit warning plus a two-hop funding sequence in step 8.

---

## What changed in revision 2

| Change | Closes |
|---|---|
| `exemptlock` / `exemptunlock`, `locked` flag on `feeexempt`, `bylocked` secondary index | H2 |
| `setfee` and `feeapply` refuse a non-zero rate with no locked exemption | H1 (ordering half) |
| `exemptunlock` refuses while any fee is live; `exemptdel` refuses locked rows | H2 |
| `setissuer` with dual authority | M1 |
| `logburn` inline receipt, no `require_recipient` | M3 |
| Fee ceiling 10.00% → **2.00%**; 72h timelock on increases via `pending_fee_bps` / `feeapply` / `feecancel`; `activated` flag closes the 0→raise bypass | M4 |
| `fee_units` clamps the stored rate to the ceiling at read time | L1 |
| Constants moved inside the contract class | L3 |
| `tests/static_contract_checks.ps1` — 9 structural checks, including the four fee-safety guards | M6 (partial) |
| README: `eosio.code` step, reordered setup, two-hop pool funding, verification steps 10–11 | N1, L8 |

---

## Integration checklist before any fee is enabled

1. Run `pwsh SC/silvertoken/tests/static_contract_checks.ps1`.
2. Build the contract (`cdt-cpp`) — **M6 blocks everything below this line.**
3. Deploy to `warforzvault` on testnet.
4. Grant `eosio.code` (`set account permission warforzvault active --add-code`) — **N1.**
5. `create` with the final issuer and final `max_supply` — **both permanent (H3, M2).**
6. `exemptadd` for `warforzlands`, `warforzfees1`, `warforzvault`.
7. `exemptlock` for `warforzlands` and `warforzfees1`.
8. Read back `feeexempt` and confirm the locks. *(`setfee` will reject step 9 if you skip this — but confirm anyway.)*
9. `setfee '["4,SILVER", 50]'`.
10. `ftconfigset` on `warforzlands`.
11. Fund the reward pool via `warforzvault → warforzfees1 → warforzlands` with memo `rewardpool`.
12. Verify a player deposit credits the in-game balance with **zero** shortfall and leaves `stat.supply` unchanged.
13. Verify a wallet-to-wallet transfer burns exactly 0.5% **and** emits a `logburn` trace.

---

## Verdict

After hardening, the contract's own logic is in good shape. Authorization is correct everywhere, the supply invariant holds on every path, the standard table layouts are preserved and now guarded by an automated check, the money math is integer-safe with the rate clamped at the point of use, and the fee's two operational hazards — enabling it without exemptions, and revoking an exemption while a fee is live — are now blocked by the contract rather than by documentation.

That is a real improvement, but read M8 for its exact limit: the guard counts locked exemptions rather than pinning identities, so it removes *silent* and *mid-flight* exposure without making an exposed state unreachable by a determined operator.

What remains splits cleanly into three groups:

- **H3 is key custody.** No contract code can fix it, and it is the single most consequential item left. Split the issuer, use multisig, resign the account when the code is final.
- **M2 and M5 are product decisions** — total supply, and whether a fee-on-transfer token fits your listing plans. Both are yours to make; the contract supports either answer.
- **M6 is now testnet, not compilation.** The code compiles cleanly and the ABI is correct, but nothing in it has ever executed. Everything above is a reading audit of source that a toolchain has accepted but a chain has not run.

The residual design risk (M7) is unchanged in kind but much smaller in practice: the contract now enforces everything about the fee that *can* be enforced, and what is left is the requirement to remember future integrations. That is a process problem with a checklist, not a state the contract can enter by accident.

Nothing here should be deployed to mainnet without an independent review by someone who did not write the code.
