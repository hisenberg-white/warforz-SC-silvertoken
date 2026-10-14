# WarForz Lands — Contract Audit

Date: 2026-08-17
Scope: `SC/mininggame/src/warforzlands.cpp` (2,721 lines), `include/warforzlands.hpp` (760 lines), `include/ext/*.hpp`, Ricardian sources
Coverage: all **67 actions**, both notification handlers, all three RNG resolvers, the three new recovery paths, and every helper

| | |
|---|---|
| Audited build | `38f444c7e1bea197fb4c50c5ecf6cea4d3e1d5b35437d87375611ed2f36ac2f7` |
| Toolchain | CDT 4.1.1 — 0 errors, 0 warnings |
| ABI | 67 actions, 67/67 Ricardian, 8 clauses, 7/7 singleton names correct |
| Currently deployed (testnet) | `c6f6541fef6f4c66af4b388db3a4de4bd9d79f736d3fa9e175cfe13cb12fbcf4` |
| Status | **Audited build is NOT deployed and has never executed** |

**Method:** line-by-line source review, plus `tests/static_contract_checks.ps1`
(action declaration/definition parity, EOSIO name limits, table-name limits).

**Not done:** no unit tests, no testnet execution, no fuzzing, no formal
verification, no live exploitation. **No test suite exists.** This is a reading
audit. The reviewer also wrote the 2026-08-17 remediations, which is a real
limitation — self-review does not substitute for an independent one.

---

## Summary

| Severity | Count | Findings |
|---|---|---|
| **High** | 0 | — |
| **Medium** | 6 | M1–M6 |
| **Low** | 8 | L1–L8 |

**No finding allows theft of player funds or NFTs, and no finding lets a
non-admin escalate privilege.** The authorization model is correct throughout.

The previous audit's five HIGH findings are all closed. What remains is a
mixture of economic policy decisions, admin-configuration footguns, and
cosmetic issues — plus one structural gap (M1) that is inherited from the
reward-pool design rather than from any single line of code.

### What is solid

- **Authorization.** Every admin action opens with `require_auth(get_self())`.
  Every player action runs `require_auth(owner)` plus `check_not_maintenance()`
  and `check_tos_accepted()` (which itself calls `check_not_blocked`).
  `receiverand` is gated to `orng.wax` alone and validates the association
  exists. The three log actions require contract auth. I found **no missing or
  weakened auth check anywhere**, including on the three new recovery actions.
- **Snapshot-before-RNG.** `mine()` captures all economic and destructive terms
  into the `mines` row before requesting randomness; `resolve_mine` never
  re-reads config. `craft` does the same via `rule_snapshots`. A mid-flight
  admin edit cannot change a pending request's economics.
- **RNG lane separation.** Failure, death and drop rolls consume non-overlapping
  64-bit lanes (offsets 0, 8, 16).
- **Integer money math.** All splits go through `bps_of` with `int128_t`
  intermediates. Asset `+=`/`-=` are checked. The reward waterfall sums exactly
  to gross.
- **Reservation model.** `reserve_reward` before RNG means FT liabilities can
  never exceed funded liquidity, and concurrent mines cannot double-reserve.
- **Template-usage accounting is coherent** across every lifecycle — deposit
  `+1`, exactly one `-1` on whichever terminal path consumes it. I re-traced all
  of them including the new resumable `resetuser`, and found no double-decrement
  or leak.
- **No `require_recipient` anywhere.** The callback-griefing class of bug that
  was the previous audit's H1 is structurally absent; receipts are emitted as
  self-authenticated inline actions that dispatch to nobody.
- **Every stranded state now has an exit.** Stuck mine, stuck craft, stuck
  rotation, orphaned association, oversized account — each has a bounded,
  authorised recovery path, and none of them can pay a reward.

---

## Closed since the previous audit

| # | Previous finding | How it is closed |
|---|---|---|
| **H1** | `require_recipient` griefing could permanently stall a mine | Removed entirely; receipts are stateless inline actions with no recipient dispatch |
| **H2** | Stuck contract-owned RNG association was unrecoverable and blocked `wipeall` | New `assocdel(assoc_id)` — admin, maintenance-gated, staleness-gated; clears the rotation latch and tolerates orphans |
| **H3** | `tosdel` on the last version bricked the contract | `tosdel` refuses the **highest** version, so the table can never be emptied |
| **H4** | Unresolved craft locked inputs and reservation forever | New `craftcancel` / `minecancel`, player-callable, staleness-gated |
| **H5** | `resetuser` aborted above 50 NFTs | `resetuser` is now resumable across calls |
| **M4** (old) | `listland` missing occupancy check | `listland`/`unlistland` removed with the public-land feature |
| **M1,M2,M5,M6,M7** (old) | Config validation gaps | Guards added — see the current M-list for what was deliberately left |
| **L2,L3,L4,L5,L6,L9** (old) | Dead code, missing caps/guards, stale comments | Fixed |

### The recovery design, and why it is safe

All three cancel paths measure staleness from `rngassocs.request_time` and
refuse until `STUCK_REQUEST_AGE_SEC` (1 hour) has elapsed. **Erasing the
association is the interlock**: a late oracle callback for a cancelled id finds
no `rngassocs` row and is rejected, so it can neither recreate state nor pay a
reward. There is no window in which both a cancellation and a settlement can
take effect.

`unwind_mine` and `unwind_craft` return `false` rather than asserting when the
underlying row is missing, so `assocdel` can clear an **orphaned** association —
which is precisely the state that blocked `wipeall` permanently. An earlier
draft of this fix asserted instead, and would have reproduced the original bug;
that is corrected in the audited build.

`craftcancel` deliberately **does not refund consumed inputs**. `craft` burns
NFTs and debits FT/Gold before the request is made, so re-crediting them from a
player-callable action would be a mint path — a player could stage a craft, wait
out the timeout, cancel, and be made whole with no oracle outage. Cancellation
restores only what is *locked*; what was *spent* is forfeit. This is disclosed
in the `stale_request_cancel` Ricardian clause. **It is a product decision, not
a technical one, and should be confirmed by the project owner.**

---

## MEDIUM

### M1 — Reward-pool sinks are one-way, so the pool drains at the gross rate

`heal` debits the player with `sub_balance` and `craft` debits FT inputs the
same way, but **neither returns anything to `rewardpool`**. `add_reward_pool` is
reached only from an inbound transfer memo'd `rewardpool` from the fee account,
and from `release_reward` (which only returns *unused reservations*).

Sunk FT therefore accumulates as real tokens held by the contract that are
credited to nobody. The pool drains at the **gross** reward rate rather than net
of sinks, so the operator must continuously re-fund it from newly issued supply,
while an ever-growing unallocated surplus sits in the contract account.

It is recoverable — the account's own key can sign a transfer out — but only as
a manual treasury operation, with no on-chain accounting for it.

**This is the single most consequential open finding**, because it determines
the SILVER token's required supply. At ~210 FT average gross per mine and ~10
mines/day, one billion SILVER covers roughly 15 months at 1,000 daily actives.

**Fix:** decide the model explicitly. Either recycle sinks into the pool
(`add_reward_pool(cost)` in `heal` and the craft FT path), or burn them via
`warforzvault::burn` and re-issue to fund the pool. The second is cleaner and
fully auditable on-chain, and is why `burn` exists on the token. Resolve this
together with the `max_supply` decision — they are the same decision.

### M2 — `wdrawgold` always mints the first configured template

`wdrawgold` mints `nft.template_ids.front()` regardless of which Gold template
the player actually deposited. With more than one currency template configured,
a player who deposits template B withdraws template A.

**Fix:** either restrict `nftconfig.template_ids` to one entry, or track
per-template Gold counts and let the player choose what to mint back.

### M3 — Unconfigured tokens sent to the contract are silently kept

`on_token_transfer` returns early when `get_first_receiver() != ft.contract`.
The tokens arrive, the contract holds them, and nothing is credited or logged.
There is no sweep action, so recovery requires the account's own key.

**Fix:** accept only the configured token and let anything else fail, or add an
admin sweep. Failing loudly is better than silently retaining a user's funds.

### M4 — A resolved-but-unclaimed craft holds its reservation indefinitely

`resolve_craft` sets `status = CRAFT_CLAIMABLE`, rewrites `reserved_ft` to the
actual amount, and **erases the association**. `craftcancel` is therefore
unreachable for such a craft (no assoc, and it refuses non-`PENDING` status),
so the reservation is held until the player claims — or forever if they never do.

Severity is well below the original H4: the player is strongly incentivised to
claim (the rewards are theirs), and there is no external cause. But pool
liquidity is held hostage to player inaction, and only `resetuser` clears it.

**Fix:** a claim deadline would need a timestamp on the craft row, which changes
the table layout. Given the incentive alignment, monitoring `crafts` for stale
`CRAFT_CLAIMABLE` rows may be the proportionate response.

### M5 — `ruleitemadd` now requires `nftconfig` to be configured first

The new M2-era template validation calls `get_nft_config()`, which asserts when
`nftconfig` is unset. This introduces an **ordering dependency**: `nftconfigset`
must run before any `ruleitemadd` with an NFT outcome.

`scripts/seed-config.sh` already satisfies this (`nftconfigset` at line 119,
`ruleitemadd` at line 213), so the shipped path is fine. The risk is a hand-run
or re-ordered configuration failing with a message about NFT config that does
not obviously point at the ordering.

**Fix:** none required; documented here so the dependency is not rediscovered
the hard way. The validation is worth the constraint — it converts a permanently
unclaimable craft into a configuration-time error.

### M6 — Template validation strictness may surface latent seeder misconfiguration

`ruleitemadd` now rejects an NFT outcome whose template does not exist in the
configured collection, or whose schema does not match. `seed-config.sh` defaults
several tiers (`MINER_ARTIFACT`, `MINER_LEGENDARY`, `EQUIP_EPIC`,
`EQUIP_LEGENDARY`) to `0`, which is not a minted template.

Seeding those tiers will now **fail** where it previously succeeded and produced
rules that could never be claimed. That is the correct behaviour, but it is a
behavioural change to an existing script.

**Fix:** supply real template ids, or continue to use `ALLOW_MISSING_TIERS` to
skip them. Treat any failure here as a genuine misconfiguration, not noise.

---

## LOW

| # | Finding |
|---|---|
| **L1** | **`wdrawft` fee truncates to zero on dust.** `bps_of` integer-divides, so at a 5% fee any withdrawal below 20 base units pays no fee. Uneconomical to exploit at any plausible CPU price. |
| **L2** | **`resetuser` scans every ToS user** to clear cross-scope occupancy. O(users) CPU per call, and the resumable rewrite repeats that scan on each batch. Fine at current scale; will not scale to a large player base. |
| **L3** | **`resolve_craft` derives rules 2..n from an LCG** rather than independent ORNG lanes. Still unpredictable before the callback, but weaker than the lane discipline `resolve_mine` uses. Changing the derivation is riskier than the finding — treat as a known deviation, not a defect. |
| **L4** | **`config.collection_name` is set but never enforced.** Deposits validate against `nftconfig.collection`, and `aa_mint` uses that too. If the two ever diverge, `config.collection_name` is silently ignored. Remove it or enforce it. |
| **L5** | **Non-burn craft inputs are locked in the random path but not the deterministic one.** Consistent with "non-burn inputs are a gate, not a cost", but the asymmetry is undocumented in the code. |
| **L6** | **`assocdel` accepts an unknown `assoc_type`** and simply erases the row. Correct as a catch-all, but it means a future association type gains a silent admin delete path unless the dispatch is extended alongside it. |
| **L7** | **`STUCK_REQUEST_AGE_SEC` is a compile-time constant.** Tuning the cancellation timeout requires a code upgrade. One hour is a reasonable default given ORNG's normal latency, but an admin-settable value would be more operable. |
| **L8** | **`equipadd`'s legacy-count loop is bounded by the limit, not by the data.** Rows written before `MAX_EQUIPMENT_PER_MINER` existed may carry several items on one miner; the count stops at the limit, so the check is correct but pre-existing over-equipped miners are not cleaned up — they simply cannot gain more. |

---

## Required before mainnet

Ordered by what blocks what.

1. **Nothing in the audited build has ever executed.** The three recovery paths
   touch reward-pool accounting and NFT-lock state — exactly where a mistake is
   expensive. Deploy to testnet and verify at minimum:
   - cancel a stale craft → pool returns to its prior balance, locked deposits unlock
   - cancel a stale mine → miner released, no reward paid, no health spent
   - `assocdel` on a rotation assoc → `fprotate` then succeeds
   - `assocdel` on an orphaned assoc (no mine/craft row) → succeeds, `wipeall` unblocked
   - `resetuser` on an account with >50 NFTs → completes across calls, `templateuse` reaches zero
   - `tosdel` on the only version → rejected
2. **Resolve M1 with the SILVER supply decision.** They are one decision.
3. **Write a test suite.** Both contracts have none. Compilation proves the code
   is well-formed, not correct.
4. **Independent review.** This audit and the token's were both written by the
   author of the code under review.
5. **Key custody.** Mainnet accounts must not reuse testnet keys, and private
   keys must not live in the repository as they currently do in
   `testnet/testnet.txt`. See `WARFORZVAULT_AUDIT.md` H3.

---

## Verdict

The contract is in materially better shape than at the previous audit: the five
HIGH findings are closed, every stranded state now has a bounded and authorised
exit, and the authorization model — which was already the strongest part of the
codebase — is unchanged and still correct.

What is left divides cleanly:

- **M1 is an economic design decision**, not a bug, and it is the one that
  matters. It sets the token's supply requirement and should be settled before
  either contract goes to mainnet.
- **M2, M3, M4** are real but bounded, each with a clear fix and no path to
  unauthorised loss.
- **M5, M6** are consequences of the new validation being stricter — working as
  intended, recorded so the behaviour change is not mistaken for a fault.
- **The LOW list is cosmetic, performance, or documented deviation.**

The honest limiting factor is not the finding count. It is that **none of this
code has run**, and that both audits of it were written by the person who wrote
it. An independent review and a real test suite are worth more at this point
than any further reading of the source.
