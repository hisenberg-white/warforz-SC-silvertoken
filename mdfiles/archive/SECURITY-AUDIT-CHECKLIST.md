# SECURITY AUDIT CHECKLIST — Mining Game Smart Contract

Auditor-facing checklist. Every item below must be verified against the deployed code before mainnet launch. Nothing on this list is optional.

## How to use this document

- Each check has a **status column**: mark `PASS`, `FAIL`, `N/A`, or `DEFERRED` with a rationale.
- Any `FAIL` blocks mainnet. `DEFERRED` requires a written waiver from a named engineer AND a follow-up ticket.
- Any check not applicable due to a design change from the master brief requires an explicit paragraph in the audit report explaining why.
- Reviewer must sign the last page.

**Definitions used throughout:**
- "Player action" = any `[[eosio::action]]` callable by an end-user account (not `_self`, not `orng.wax`).
- "Destructive action" = any action that burns an NFT, transfers tokens out, or permanently removes non-recoverable state.
- "Guards" = the three-call header expected on every player action: `require_auth(caller)`, `check_not_maintenance()`, `check_tos_accepted(caller)`.

---

## Section A — Authorization

Every code path is authorized by the correct account. Auth is checked BEFORE any state read that could leak info about the caller.

| # | Check | Where to look | Expected | Status |
|---|---|---|---|---|
| A1 | Every admin action calls `require_auth(_self)` as its first statement | `configset`, `configclear`, `maintset`, `tosset`, `tosdel`, all `*set/*del` template actions, all crafting admin actions, `slotcostset/del`, `fpstart`, `fprwset` | First non-declaration line is `require_auth(_self)` | |
| A2 | Every player action calls `require_auth(owner_or_caller)` on the actual owner argument (not a spoofed one) | `tosaccept`, `setreferrer`, `buylandslot`, `activateland`, `removeland`, `mineradd`, `minerrem`, `gearadd`, `gearrem`, `listland`, `unlistland`, `mine`, `heal`, `craft`, `craftclaim`, `wdrawminer`, `wdrawsilver` | `require_auth` uses the parameter that identifies the actor, not a table lookup | |
| A3 | `receiverand` requires `orng.wax` exactly, with no fallback | `receiverand` body | First line: `require_auth(name("orng.wax"))` | |
| A4 | `logmine`, `logcraft`, `logheal` require `_self` and are ONLY called inline from the contract | Log actions | `require_auth(_self)`; no external caller can invoke | |
| A5 | `mine(miner_owner, land_owner, …)` authorizes on `miner_owner`, not `land_owner` | `mine` body | `require_auth(miner_owner)` | |
| A6 | No action uses `has_auth` as a substitute for `require_auth` on the primary caller | Grep all `.cpp` files | Only `require_auth` used for the primary auth check | |
| A7 | No action reads `get_sender()` in a way that allows a rogue contract to spoof identity | Notification handlers | `get_sender()` used only where the sender is intended to be an external contract (AtomicAssets, Silver token) | |
| A8 | Notification handlers verify the sender contract matches the expected one | `on_notify` for NFT transfer and Silver transfer | AtomicAssets notify only accepts if `get_first_receiver() == name("atomicassets")` or equivalent; Silver notify verifies against `config.silver_token_contract` | |

---

## Section B — Guards (maintenance, ToS, preconditions)

| # | Check | Where to look | Expected | Status |
|---|---|---|---|---|
| B1 | Every player action calls `check_not_maintenance()` after `require_auth` | All player actions listed in A2 | Present, blocks all writes when maintenance is on | |
| B2 | Every player action except `tosaccept` calls `check_tos_accepted(caller)` | All player actions except `tosaccept` | Present; `tosaccept` itself must NOT gate on this or players can never accept | |
| B3 | Maintenance mode blocks BOTH direct player actions AND notification-based deposit handlers | `on_notify` handlers + player actions | Deposits rejected during maintenance (or explicitly allowed with a written rationale) | |
| B4 | `check_tos_accepted` compares against the LATEST `tosconfig` version, not any specific stored value | Helper implementation | Reads max/latest `tosconfig.version` and compares | |
| B5 | Every action that consumes durability/uses/health checks the value is > 0 (not != 0, to catch underflow via signed-vs-unsigned bugs) | `mine`, `resolve_mine`, `craft` input validation | Explicit `> 0` checks with meaningful error messages | |

---

## Section C — Reward waterfall correctness

The waterfall is the most-audited piece. Any error here directly loses or mints tokens.

| # | Check | Where to look | Expected | Status |
|---|---|---|---|---|
| C1 | Gross reward computed with `int128_t` intermediate (or checked `asset` math), not `uint64_t` multiplication | `resolve_mine` | No raw `uint64_t * uint64_t` on token amounts. `int128_t` cast used for intermediate products, downcast with bounds check | |
| C2 | Platform fee subtracted BEFORE landlord commission | `resolve_mine` | Fee cut off gross first, then landlord takes % of the remainder (or of gross — CONFIRM against master brief §3 and match exactly) | |
| C3 | Referral cut is on `miner_owner`'s share only, NOT on `land_owner`'s commission | `resolve_mine` | Referral cut is (post-landlord-commission miner_owner share) × referral_rate | |
| C4 | The final sum of all cuts equals the gross exactly — no dust minted, no dust lost | Property test in phase 7/8 suite | Test explicitly asserts `platform + landlord + referral + miner_owner_net == gross` for a wide range of inputs including boundary values | |
| C5 | Rounding is deterministic and defined: e.g. `floor` on cut computations, remainder to `miner_owner` | `resolve_mine` | Rounding rule documented and consistent; last party receives the residual so no dust is ever lost | |
| C6 | Gold NFT drop probability uses `random_value` bytes in a documented, deterministic way | `resolve_mine` | Uses defined byte offsets from `checksum256`; documented in code comments; testable | |
| C7 | Gold NFT is minted to `miner_owner` regardless of who owns the land | `resolve_mine` | Recipient parameter of `mintasset` is `miner_owner` | |
| C8 | Own-land mining bypasses landlord commission entirely (does not credit `land_owner == miner_owner` twice) | `resolve_mine` | Branch `if (miner_owner == land_owner) skip commission step` | |
| C9 | Fee routing matches the chosen design (balance credit vs inline transfer) from pre-flight decision #4 | `resolve_mine` | Method matches the documented decision; not mixed | |
| C10 | No path in the waterfall can produce a negative `asset` (which will assert-fail) | `resolve_mine` | Every subtraction is preceded by a check that the minuend is >= subtrahend | |
| C11 | Zero-value cuts are handled without inline transfers of `0.0000 SILVER` (which some token contracts reject) | `resolve_mine` | Skip transfer/credit steps when the cut rounds to zero | |

---

## Section D — Asset math and token safety

| # | Check | Where to look | Expected | Status |
|---|---|---|---|---|
| D1 | All Silver operations use the symbol from `config.silver_symbol`, never a hardcoded symbol | All actions touching Silver | Symbol read from config; no `symbol("SILVER", 4)` literals in reward paths | |
| D2 | `accounts.balances` uses one `asset` per symbol; no duplicates | Deposit handler | Deposit handler upserts by symbol, does not append duplicates | |
| D3 | Withdraw amount validation: `quantity.amount > 0`, `quantity.symbol == config.silver_symbol`, `quantity.is_valid()` | `wdrawsilver` | All three checks present | |
| D4 | Withdraw balance debit uses `-=` on the `asset` with implicit overflow check, not raw `.amount -=` | `wdrawsilver` | Uses `asset::operator-=` semantics; underflow throws | |
| D5 | Fee parameter validation on `wdrawsilver`: strict match against recomputed fee (per pre-flight #8) | `wdrawsilver` | Recomputes fee from `config.fee` × quantity, asserts equal to passed `fee` | |
| D6 | No path allows setting `config.fee` to > 100% | `configset` | Explicit bounds check | |
| D7 | No path allows referral chain earnings to exceed 100% of the referee's share | `resolve_mine` | Bounds check on `config.referral_rate` at configset time AND at use time | |
| D8 | Silver deposits credit the sender's account, not a memo-derived account (prevents "deposit to X" abuse) | Silver `on_notify` | Credited to `from`, not parsed from memo | |
| D9 | If the Silver token contract has a memo requirement to bypass ram/blacklist, contract's outgoing transfers use it correctly | `wdrawsilver` inline transfer | Memo matches token contract expectations | |
| D10 | `asset` overflow on `+=` in `balances` handled | Deposit handler | Balance update wrapped so overflow throws (default asset behavior); no code path that silently truncates | |

---

## Section E — NFT custody safety

| # | Check | Where to look | Expected | Status |
|---|---|---|---|---|
| E1 | AtomicAssets `on_notify` accepts only NFTs from `config.collection_name` | NFT `on_notify` | Collection check present; other collections silently ignored (do NOT throw, or normal user transfers to unrelated accounts break) | |
| E2 | `on_notify` handles empty `asset_ids` vector without crashing | NFT `on_notify` | Explicit guard or safe iteration | |
| E3 | Deposits scoped to `from`, so one player can never see or claim another's deposits | NFT `on_notify` + `deposits` reads | `scope = from` throughout | |
| E4 | `activateland`, `mineradd`, `gearadd` verify the asset ID they operate on is actually in the caller's `deposits` (or their `miners`/`gear` if already promoted), NOT in another account's scope | Each action | Read is from `scope = owner`, and existence checked with `find()` returning `end()` before erase | |
| E5 | Burning (via `atomicassets::burnasset`) happens BEFORE erasing the corresponding row, so if burn fails the row survives and the state stays consistent | `removeland`, `gearrem`, land/gear auto-burn in `resolve_mine` | Order: `burnasset` inline → then erase local row | |
| E6 | Every burnasset call passes exact asset_id + `_self` as authorizer (contract must own the NFT at that moment) | Same actions | Correct params, contract confirmed to hold the NFT | |
| E7 | Withdrawal `wdrawminer` inline `transfer` uses correct authorizer and memo | `wdrawminer` | Auth = `_self`, memo consistent | |
| E8 | Withdrawal verifies the miner is not: placed, in an active `mines` row, referenced by any `occupancy` (via secondary index), attached to a gear that's in use | `wdrawminer` | All four checks present | |
| E9 | No path allows an NFT to exist in `miners` AND `deposits` at the same time | `activateland`, `mineradd`, `gearadd` | Move semantics: erase from source before insert into destination | |
| E10 | AtomicAssets `mintasset` for Gold NFT drops uses the correct schema and template from `config.gold_template_id`; template's collection matches accepted collection | `resolve_mine` | Verified at configset time; used consistently | |
| E11 | Contract cannot mint NFTs from templates it doesn't own the collection auth for (audit `mintasset` params) | `resolve_mine`, `craftclaim` | `_self` must be the collection author or hold `mint` permission on the collection | |

---

## Section F — Async RNG (the hard one)

Async oracle callbacks are the highest-risk surface in EOSIO contracts. Every failure mode must be handled.

| # | Check | Where to look | Expected | Status |
|---|---|---|---|---|
| F1 | `receiverand` verifies `assoc_id` exists in `rngassocs` before dispatching | `receiverand` | Explicit `find()` + `check()` on existence | |
| F2 | `receiverand` dispatches on `assoc_type` with a fallthrough that ASSERTS (never silently succeeds on unknown type) | `receiverand` | Unknown type → `check(false, ...)` | |
| F3 | Every `assoc_id` is unique across the contract lifetime — monotonically incremented in `config.next_assoc_id` | `request_random` helper | Increments and persists; no re-use possible | |
| F4 | Signing value passed to `orng.wax::requestrand` is unpredictable to an outside caller (mixes at least assoc_id + time + owner) | `request_random` helper | Documented salt formula; NOT just `assoc_id` | |
| F5 | `mine`/`craft` actions do NOT credit rewards themselves — ONLY `receiverand` credits rewards | `mine`, `craft` | No reward credit in the initiating action; state is "pending" only | |
| F6 | If `resolve_mine`/`resolve_craft` fails partway through, the transaction reverts entirely — no half-resolved state | `resolve_mine`, `resolve_craft` | Uses `check()` for all preconditions; ordering does not leave stuck rows on any assertion failure | |
| F7 | Stuck-state recovery: if `orng.wax` never calls back (oracle outage), how are pending `mines`/`crafts` unstuck? | Design + code | Either: (a) documented manual admin recovery action; (b) time-based auto-expiry; (c) accepted as unrecoverable and documented. NOT undefined | |
| F8 | The free-play rotation resolver ALWAYS queues the next rotation before returning | `resolve_freeplay_rotation` | Even on unexpected `random_value` shape, the next rotation is queued; otherwise the loop dies silently | |
| F9 | Free-play rotation cannot double-schedule (guard against `resolve_freeplay_rotation` being called twice with the same `assoc_id`) | `resolve_freeplay_rotation` | Idempotency via checking `rngassocs` row exists before scheduling next | |
| F10 | RNG bytes consumed deterministically: documented byte offsets for each roll in `resolve_mine` (Gold drop, any variance rolls) and `resolve_craft` (rule weight resolution) | Both resolvers | Comments in code document byte layout; tests verify with fixed `random_value` | |
| F11 | Weighted resolution in `resolve_craft` uses `total_weight` from the rules table, not recomputed from items (or recomputes and asserts equal — either is fine, both must be consistent) | `resolve_craft` | One of the two patterns; consistent | |
| F12 | `receiverand` erases both the `rngassocs` row and the pending `mines`/`crafts` row on completion — no orphaned rows | `resolve_mine`, `resolve_craft` | Erase order: state row → rngassocs; verify with a table-state test | |

---

## Section G — Invariants (from master brief §7)

Master brief §7 lists 10 correctness invariants. Each MUST have a test that intentionally attempts to violate it and confirms the violation is prevented.

| # | Invariant | Test that attempts to violate it | Status |
|---|---|---|---|
| G1 | Silver accounting identity (sum of balances == contract's Silver holdings) | Simulate rapid deposit → mine → withdraw sequences; assert conservation after each | |
| G2 | Every placed miner has a matching placement record | Attempt to `wdrawminer` a miner that's placed → rejected | |
| G3 | Listed lands are never free-play templates | `listland` on a free-play land → rejected; and no path exists that flips `is_listed=true` for such a land | |
| G4 | Every ToS-accepted account has `unlocked_land_slots >= 1` | Fresh account calls `tosaccept` first → `accounts` row auto-created with `unlocked_land_slots >= 1` (from Silver deposit path OR fresh registration path) | |
| G5 | At most one free-play land per account | Activate second free-play → rejected | |
| G6 | Every `rngassocs` row corresponds to an active mine, craft, or free-play rotation | Verify by table scan post-test-suite that no orphan `rngassocs` exists | |
| G7 | Cannot withdraw a miner referenced by an active mine | Cross-player mine active → `wdrawminer` by miner owner → rejected | |
| G8 | Referrals append-only | `setreferrer` twice for same account → second rejected | |
| G9 | Gear only equipped to one miner at a time | Attempt `gearadd` on already-equipped gear → rejected | |
| G10 | Depleted lands/gear are burned in the same transaction they reach zero | Force depletion via last-durability mine → confirm land row erased and NFT burned in the same tx | |

---

## Section H — Referral & landlord commission abuse resistance

| # | Check | Where to look | Expected | Status |
|---|---|---|---|---|
| H1 | Self-referral rejected (`referrer == referee`) | `setreferrer` | Explicit check | |
| H2 | Immediate cycle rejected (A→B, B→A) | `setreferrer` | Cycle walk up to depth N | |
| H3 | Longer cycles rejected up to configured depth | `setreferrer` | Depth from pre-flight #6 | |
| H4 | Referrer must have an `accounts` row (prevents referring nonexistent accounts) | `setreferrer` | `find()` check | |
| H5 | Referral cannot be changed once set | `setreferrer` | Existence check → reject | |
| H6 | Referral cut only paid if `referrals[miner_owner]` exists AND the referrer's `accounts` row still exists | `resolve_mine` | Both checks; if referrer account was deleted, cut goes to miner_owner instead | |
| H7 | Commission rate on `listland` bounded [0, 100] | `listland` | Explicit bounds | |
| H8 | Commission rate cannot be changed while occupancy is active (or is captured at mine-start time, not resolve time) | `listland`, `mine` | Design decision documented; behavior consistent | |
| H9 | Front-running defense: does the landowner have any incentive/ability to change `commission_rate` between `mine` and `resolve_mine`? | `listland` + `mine` | Either capture rate at `mine` time (safer) or explicitly document that owner cannot change it while active | |
| H10 | Optional: cap on total referral earnings per referee (per pre-flight #7) | `resolve_mine` | Implemented per decision, or explicitly N/A with rationale | |

---

## Section I — Cross-player mining safety

| # | Check | Where to look | Expected | Status |
|---|---|---|---|---|
| I1 | `mine` with `miner_owner != land_owner` verifies land `is_listed == true` at the moment of `mine`, not `resolve_mine` | `mine` | Check at `mine`; land could be unlisted after, but the active session continues (per H8) | |
| I2 | `mine` rejects if `miner_owner != land_owner` AND land template `is_freeplay == true` (belt-and-suspenders even if H2 says free-play can't be listed) | `mine` | Explicit second check | |
| I3 | `occupancy` scoped to `land_owner`, not `miner_owner` | Occupancy table + `mine` | Confirmed scope | |
| I4 | `wdrawminer` checks occupancy via a secondary index or explicit scan (whichever chosen per Phase 8 pre-flight) | `wdrawminer` | Design implemented, matches doc | |
| I5 | `unlistland` blocked while any `occupancy` row exists under this land | `unlistland` | Explicit check | |
| I6 | `removeland` blocked while any `occupancy` row exists (from Phase 8) | `removeland` | Explicit check | |
| I7 | If a landlord tries to burn their own land while a visitor is mining, the visitor's session isn't destroyed silently — either blocked or (if allowed) explicitly credited | `removeland`, `resolve_mine` | Design documented; not silent | |
| I8 | Gear owned by `miner_owner` cannot be burned by any `land_owner` action | Cross-check all land-side actions | No path from land_owner's actions to gear scope of miner_owner | |
| I9 | Miner health/cooldown decrement always affects `miner_owner`'s row, not `land_owner` | `resolve_mine` | Explicit scope | |
| I10 | Land durability decrement always affects `land_owner`'s row, regardless of who mined | `resolve_mine` | Explicit scope | |

---

## Section J — Destructive actions (irreversible operations)

| # | Check | Where to look | Expected | Status |
|---|---|---|---|---|
| J1 | `removeland` requires the land row exists and belongs to the caller's slot | `removeland` | Two `find()` checks | |
| J2 | `removeland` fails cleanly if the NFT burn fails, without half-updating state | `removeland` | Burn first, then erase | |
| J3 | `gearrem` distinguishes "unequip only" from "burn"; the master brief spec has burn — verify this is what the contract does | `gearrem` | Burn inline; documented UX warning covered by frontend, not contract | |
| J4 | `craftclaim` cannot double-claim (`status != claimable` → reject) | `craftclaim` | Explicit check | |
| J5 | `configclear` is guarded against being called while contract has any pending state (or documented as an admin recovery hatch with acknowledged risk) | `configclear` | Explicit check OR written rationale | |
| J6 | No admin action can delete a template that's currently in use (e.g. `minerdel` on a template that some player owns) — or if allowed, existing instances gracefully handle the missing config | Template deletes + `resolve_mine` reads | One of the two behaviors, documented | |

---

## Section K — RAM & resource safety

| # | Check | Where to look | Expected | Status |
|---|---|---|---|---|
| K1 | Player-scoped tables have the player as RAM payer, not `_self` | All player tables | Verify at every `emplace`/`modify` call | |
| K2 | `_self` pays RAM for admin-authored contract-scoped tables (`config`, templates, `landdef`, etc.) | Admin actions | Correct | |
| K3 | Deposit path RAM payer matches pre-flight decision #2 | NFT + Silver `on_notify` | As documented | |
| K4 | No unbounded loops that could exceed CPU limits (e.g. scanning all lands across all accounts in `mine`) | All actions | Bounded by per-owner scope; any cross-account scan is over a small, indexed set | |
| K5 | Vector fields (`balances`, `req_ft`, `req_nft`, `results`, `items`) have a documented max length and enforce it at admin-set time | Template admin actions + `resolve_craft` | Max length checks present | |
| K6 | Deep cycle checks (referral) have a hard depth cap that terminates | `setreferrer` | Cap enforced | |

---

## Section L — Failure-mode & recovery drills

Reviewer must run each of these against a testnet deployment and record the outcome. This is the "chaos test" section.

| # | Scenario | Expected outcome | Status |
|---|---|---|---|
| L1 | `orng.wax` never calls back for 24h — what breaks? | Documented; a manual recovery path exists OR players understand the wait | |
| L2 | Contract runs out of RAM mid-transaction on a deposit | Deposit reverts cleanly; the sender's NFT is returned or held in `deposits` correctly | |
| L3 | Silver token contract is paused/upgraded mid-operation | `wdrawsilver` fails cleanly; balance not debited on failure | |
| L4 | Player deletes their account (`eosio` account deletion is rare but possible on WAX) mid-session | Referral payouts to a nonexistent referrer do not brick `resolve_mine` (per H6) | |
| L5 | Malicious contract tries to spoof AtomicAssets notify (fake sender) | Rejected via `get_first_receiver()` check (per A8) | |
| L6 | Two `mine` transactions on the same miner in the same block | Second rejected (miner cooldown / already-in-mines check) | |
| L7 | Landlord unlists mid-session (per H8 design) | Active session either continues to resolve using captured rate, or is blocked from unlisting | |
| L8 | Rebuild scenario: contract redeployed with a new WASM — do existing rows remain readable? | Migration plan exists; struct layout backward-compatible OR explicit migration action provided | |

---

## Section M — Configuration hygiene

Before mainnet deploy, verify the initial admin-configured state.

| # | Check | Expected | Status |
|---|---|---|---|
| M1 | `config.fee` set to intended production value, not a testnet dev value | Confirmed | |
| M2 | `config.referral_rate` set to intended value; documented in a public place users can read | Confirmed + published | |
| M3 | `config.fee_account` is a real, controlled, multi-sig protected account | Confirmed; multi-sig or comparable protection | |
| M4 | `config.collection_name` matches the real production AtomicAssets collection | Confirmed | |
| M5 | `config.silver_token_contract` + `silver_symbol` match the production Silver token | Confirmed | |
| M6 | `config.gold_template_id` matches the real Gold NFT template; the contract has authority to mint it | Confirmed via test mint on testnet with the same collection setup | |
| M7 | `landslotcost` populated for the intended number of tiers (e.g. slots 1–10) | Populated | |
| M8 | At least one `tosconfig` version exists before players are allowed to onboard | Confirmed | |
| M9 | `freeplaystate` bootstrapped via `fpstart` and self-rotating | Confirmed on testnet observation | |
| M10 | Free-play rarity weights (`fprarityweights`) match the intended distribution | Confirmed | |
| M11 | Maintenance mode ON at deploy, OFF only after M1–M10 verified | Confirmed | |

---

## Section N — External review requirements (must be complete before mainnet)

| # | Requirement | Status |
|---|---|---|
| N1 | Full external smart-contract audit by a reputable firm covering all sections above | |
| N2 | All `FAIL` items from this checklist remediated; all `DEFERRED` items have written waivers | |
| N3 | Public bug bounty program stood up, funded, with clear scope | |
| N4 | Mainnet contract account keys held under multi-sig | |
| N5 | Upgrade path documented: who can push a new WASM, under what governance | |
| N6 | Emergency pause procedure documented and rehearsed (maintenance mode + rollback plan) | |
| N7 | Post-launch monitoring in place: watching balance identity, stuck `rngassocs`, unusual reward outputs | |
| N8 | Phased rollout plan: initial per-account caps, gradual removal as confidence builds | |

---

## Reviewer sign-off

- Auditor name:
- Firm:
- Date:
- Commit hash reviewed:
- Contract account (testnet):
- Total FAIL count:
- Total DEFERRED count:
- Recommendation: **APPROVE FOR MAINNET** / **BLOCK — remediate FAILs** / **CONDITIONAL — waivers required**

Signature: __________________

---

## Appendix — Cross-references

- Master brief §7: invariants → Section G
- Master brief §8: security requirements → Sections A, C, D, E, F
- Phase 6 report: RNG plumbing details → Section F
- Phase 7 report: reward math → Section C
- Phase 8 report: cross-player mining → Section I
# 2026-08-07 implementation verification addendum

- [x] Contract compiles with Antelope CDT 3.1.0 and generates ABI/WASM.
- [x] All 57 declared actions have matching definitions and EOS-safe names.
- [x] Oracle callback requires `orng.wax`; event actions require contract-self authority.
- [x] Mining request terms and crafting rules are snapshotted before RNG.
- [x] Failure, death, and NFT-drop rolls use separate checksum lanes.
- [x] FT rewards are limited by a funded pool and pending liabilities are reserved.
- [x] Destructive paths issue AtomicAssets burns and adjust template custody counts.
- [x] Configuration/rule deletion is blocked while referenced by custody or recipes.
- [x] Frontend production TypeScript/Vite build passes.
- [ ] WAX testnet oracle, AtomicAssets, FT, permission, and reconciliation suite executed.
- [ ] Independent smart-contract and economic audit completed before mainnet.
