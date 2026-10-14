# Warforzlands — Contract Code Review

Reviewed against: master brief (tables, actions, invariants §7, security §8), the golden rules, and
the appendix pre-flight decisions.

This file has two halves:

- **Part A — new findings (current review pass).** These are **open**: found by re-reading the
  contract as it stands today, and *not* fixed.
- **Part B — first review pass.** All **fixed**, kept as a record of what was changed and why.

> The contract has still never been compiled — there is no `cdt-cpp`/`cmake` toolchain on this
> machine. Everything below is from reading the source. Build before trusting any of it.

---
---

# PART A — NEW FINDINGS (open)

## CRITICAL

### N1. Land and gear NFTs can never leave the contract — permanent asset lock
`aa_transfer()` — the only path that sends an NFT back to a player — is called from exactly **one**
place, `wdrawminer` ([src/warforzlands.cpp:1774](src/warforzlands.cpp#L1774)), which explicitly refuses
anything that is not a miner:

```cpp
check(mconf.find((uint64_t)(uint32_t)dit->template_id) != mconf.end(), "asset is not a miner");
```

So for the other two asset classes there is **no exit at all**:

| Asset | State | How it can leave |
|---|---|---|
| Land | sitting in `deposits` (never activated) | **nothing — stuck forever** |
| Land | activated (`lands`) | only `removeland` → **burned**, or durability hits 0 → **burned** |
| Gear | sitting in `deposits` (never equipped) | **nothing — stuck forever** |
| Gear | equipped (`gear`) | only `gearrem` → **burned**, or uses hit 0 → **burned** |

A player who deposits a land NFT and changes their mind has two options: leave it in the contract
forever, or activate it and then `removeland`, which **destroys** it. The same is true of gear.
This is real user property being irrecoverably lost, and `removeland` in particular is a trap — the
name says "remove", the code says `aa_burn`.

**Fix:** add `wdrawland` / `wdrawgear` (or generalise `wdrawminer` into `wdrawnfts`) covering both
the unassigned-`deposits` case and the placed case (`lands` with no occupancy / `gear` with
`miner_asset_id == 0`), and split the burn behaviour out of `removeland`/`gearrem` into explicitly
named destructive actions. Depletion-burn (durability/uses exhausted) is correct and should stay.

---

## HIGH

### N2. Nothing backs the Silver the contract owes players
`resolve_mine` credits mining rewards with `credit_safe(...)` — in-game numbers created from
nothing. `wdrawsilver` pays them out with a **real** `token_transfer` from the contract's own
token balance ([src/warforzlands.cpp:1714](src/warforzlands.cpp#L1714)). The contract never mints
Silver and never tracks how much it owes.

So the treasury only ever receives Silver from player deposits, while withdrawals are funded by
deposits *plus* every reward ever mined. Once mined rewards exceed deposits, `wdrawsilver` starts
failing inside the token contract with `overdrawn balance` — and it will fail for whoever happens
to withdraw last, not for whoever caused the shortfall.

**Fix:** decide the model explicitly and encode it — either (a) the contract is an authorized
issuer and `wdrawsilver` mints/issues on withdrawal, or (b) the admin funds the treasury and the
contract tracks total outstanding liability (sum of credited balances) so the shortfall is
visible on-chain before it bites, ideally with a guard that refuses to credit rewards beyond a
configured backing ratio.

### N3. `configclear()` breaks the RNG id sequence and the Silver-symbol invariant
`configclear` deletes the config singleton, and `next_assoc_id` lives inside it
([src/warforzlands.cpp:324](src/warforzlands.cpp#L324)). After `configclear` + `configset`, the
counter restarts at 1 while old `rngassocs` rows may still exist, so `request_random`'s
`assocs.emplace` aborts on a duplicate primary key — `mine()` and `craft()` become impossible
until the counter climbs past the highest surviving row.

The same round-trip also bypasses the `silver_symbol` immutability guard added in the last pass:
the check only fires when the singleton already exists. Change the symbol after players have
registered and every pre-seeded balance slot stops matching, so `credit_safe` returns false for
everyone — mining rewards would be silently rerouted and then dropped.

If config is cleared while a free-play rotation is in flight, `resolve_freeplay_rotation` →
`next_assoc_id()` → `cfg.get()` aborts, the oracle callback fails permanently, and the
self-perpetuating rotation stops for good.

**Fix:** either delete `configclear` (it exists for test convenience and has no production use),
or make it refuse while any `rngassocs`, `accounts`, or `lands` rows exist, and move
`next_assoc_id` out of the config singleton into its own row so clearing config cannot reset it.

### N4. A craft that never resolves locks its inputs forever
`craft()` sets `deposits.locked = true` on every non-burn input and records them in
`crafts.locked_assets`. The **only** thing that clears the flag is `craftclaim`
([src/warforzlands.cpp:1690](src/warforzlands.cpp#L1690)), which requires `status == CRAFT_CLAIMABLE`
— i.e. requires the oracle to have called back.

If `receiverand` never arrives (oracle outage, an assoc row erased by hand, a resolver that
aborts), the craft stays `CRAFT_PENDING` forever and the locked NFTs are unusable and
un-withdrawable **permanently** — `activateland`, `mineradd`, `gearadd`, `craft` and `wdrawminer`
all refuse a locked row. The FT inputs are already gone too.

**Fix:** add a `craftcancel(owner, assoc_id)` that, after a generous timeout measured from
`rngassocs.request_time`, releases the locks, refunds or forfeits the FT inputs per your policy,
and erases the craft + assoc rows. The same timeout escape is worth having for a stuck `mines` row.

---

## MEDIUM

### N5. A `gold_template_id` typo silently burns player assets
`on_nft_transfer` classifies Gold **first** and burns it on sight
([src/warforzlands.cpp:761](src/warforzlands.cpp#L761)), while `configset` accepts any
`gold_template_id` without checking it against the miner/gear/land tables. Point it at a miner
template by mistake and every deposit of that miner is burned and credited as 1 Gold —
irreversible, from a single admin typo, with no confirmation step.

**Fix:** in `configset`, reject a `gold_template_id` that is already a configured miner, gear or
land template; and in `minerset`/`gearset`/`landset`, reject a template that equals the configured
`gold_template_id`. Consider freezing `gold_template_id` once players hold Gold, as was done for
`silver_symbol`.

### N6. `listland` has no occupancy check, so a land can be listed but unminable
`unlistland` and `removeland` both refuse while any miner occupies the land, but `listland`
([src/warforzlands.cpp:1097](src/warforzlands.cpp#L1097)) has no such check. Combined with plot
exclusivity (design rule #1), a landlord whose own miner sits on the plot can list it, see it
appear as publicly available, and have every cross-player `mine()` against it fail with
"another miner is already on that land".

Not a fund-loss bug — just a listing that cannot work, and a confusing one for the miner who tries
to use it.

**Fix:** either add the occupancy check to `listland` (symmetric with `unlistland`), or leave it
and have the frontend hide occupied lands — but the contract should be the source of truth.

### N7. A bad NFT result template can permanently block `craftclaim`
`ruleitemadd` validates only that an NFT outcome has a non-empty `schema_name`
([src/warforzlands.cpp:561](src/warforzlands.cpp#L561)); it never checks that `template_id` exists in
the collection or that the schema matches it. If the template is wrong, the inline `mintasset` in
`craftclaim` fails — and since the inputs were already burned at `craft()` time, the player is left
with a permanently unclaimable craft and nothing to show for it.

**Fix:** validate in `ruleitemadd` against `atomicassets::templates` (template exists in
`config.collection_name`, and `schema_name` matches the template's schema) — the same lookup
`wdrawgold` already does.

### N8. Deleting a template soft-bricks every asset referencing it
`minerdel` / `geardel` / `landdel` erase config rows with no check for live references. Afterwards
`mine()` and `heal()` abort ("miner template missing"), and `resolve_mine` bails without paying.
Nothing is destroyed and re-adding the template restores everything, so this is recoverable — but
it is silent, and an admin cleaning up "unused" templates has no way to know they are in use.

**Fix:** at minimum document it; better, refuse deletion while any row references the template, or
add an `active` flag so templates can be retired without being erased.

### N9. `tosdel` can brick the entire contract
`latest_tos_version()` asserts when no version exists, and it is called by `check_tos_accepted`,
which every player action and **both notification handlers** run. Deleting the last ToS version
therefore stops all gameplay *and* makes every inbound NFT/Silver transfer to the contract abort
until a new version is set. Deleting a *newer* version silently re-validates everyone who had only
accepted an older one.

**Fix:** refuse `tosdel` when it would remove the highest (or the only) version.

---

## LOW

- **Cooldown is charged twice.** `mine()` sets `available = now + cooldown` (the busy-lock fix) and
  `resolve_mine` sets it again to `resolve_time + cooldown`
  ([src/warforzlands.cpp:1472](src/warforzlands.cpp#L1472)), so the real cooldown is
  `configured + RNG latency`. A few seconds today; worth being deliberate about.
- **`bail()` shortens the cooldown to 60s**, overriding whatever `mine()` set. That is the intent
  (a failed mine should be retryable) but it means a bailed mine has a *shorter* cooldown than a
  successful one. Not exploitable — a bail never pays out — just asymmetric.
- **No batch caps on `claimdeps` and `wdrawminer`.** Both loop over a caller-supplied vector. The
  caller pays the CPU, so this is self-limiting, but `MAX_DEPOSIT_BATCH` exists for exactly this
  reason elsewhere and these two are inconsistent with it.
- **`maintset` and `next_assoc_id` call `cfg.get()` without an `exists()` check**, so with no
  config they fail with the singleton's generic message instead of the helpful one `get_config()`
  produces.
- **`landdef` is write-only.** `landdset`/`landddel` maintain it and nothing in the contract ever
  reads it. That is legitimate (it is frontend display metadata) but it is the same shape as the
  `plotdef` dead code removed in the last pass — worth a comment saying so deliberately.
- **`cost_gold` is still stored and never charged.** Now trivially implementable via
  `sub_gold(owner, n)` since `accounts.gold` exists. Deferred by decision, not oversight.

---
---

# PART B — FIRST REVIEW PASS (all fixed)

Condensed. Each item is the original finding plus what the code does now.

### C1. Crafting was non-functional — admin CRUD entirely missing — **FIXED**
`craft()` read `craftrecipes`/`craftrules` but nothing could populate them, so it always failed
with `recipe not found`. Added `ruleset`/`ruledel`/`ruleitemadd`/`ruleitemdel` and
`recset`/`recdel`/`recreqaddft`/`recreqaddnft`/`recreqdel`/`recresadd`/`recresdel`, with
`total_weight` recomputed inside the same `modify` that changes the items so the cache cannot
drift. Also added the missing `fprwset` + `fprweights` singleton; the free-play rotation now does
a weighted pick, falling back to uniform when unset.

### C2. `craft()` never validated NFT inputs against the recipe — **FIXED**
It burned whatever the caller passed. Now it validates everything before consuming anything: the
recipe exists and is in its window; its result rules still exist and carry weight; every supplied
asset is a non-duplicate, unlocked deposit in the caller's scope; and the assets cover
`nft_inputs` exactly, by template, with no unrequested extras. `ReqNFT` gained the `burn` flag —
burn-vs-lock is now representable, with `deposits.locked` honoured by every consumer and released
by `craftclaim`. (Its permanent-lock failure mode is N4 above.)

### C3. No busy lock on own-land mining → health could go negative — **FIXED**
Three layers: a busy lock (`mines.byminer` — one in-flight mine per miner), a cooldown that starts
at `mine()` time rather than at resolution, and a health re-check at resolution that bails cleanly
(no reward, **no health spent**) instead of subtracting into the negative.

### C4. No plot exclusivity → multiple miners per plot — **FIXED**
Decision confirmed: one land per plot, one miner per land. `occupancy` gained `byplot` and `byland`
indexes; `mineradd` and `mine` both reject an occupied plot; `mine` additionally enforces
`plot_id == land_slot`. Known consequence: a landlord's own parked miner blocks cross-player
mining (see N6).

### C5. Contract sponsored unbounded user-scoped RAM — **FIXED**
Registration moved into `tosaccept` (player-authorized, player-paid), and every user-scoped row
written from a player-authorized action is now billed to that player, including the cross-scope
`occupancy` row and the player's `rngassocs` request row. Balances are pre-seeded with a zero
Silver entry so RNG-callback credits never grow the row; `silver_symbol` was made immutable to keep
that valid (see N3 for the `configclear` hole in that guard).

The one row the chain refuses to bill to the player is the `deposits` row written from the
notification handler ("Cannot charge RAM to other accounts during notify"). It is bounded three
ways — registered depositor, configured template, `MAX_PENDING_DEPOSITS` — and `claimdeps` lets the
player take it over. Gold deposits write no row at all.

### H1. `unlistland()` missing the occupancy guard — **FIXED**
Now runs the same guard as `removeland`, both via the `occupancy.byland` index instead of a scan.

### H2. Commission rate read live at resolution — **FIXED**
`mine_s.commission_rate` snapshots the landlord's rate at call time and `resolve_mine` uses only
that. `reward_rate` / `land_bonus` / gear `capacity_boost` are deliberately *not* snapshotted —
they are admin-controlled, carry no PvP vector, and freezing them would block legitimate
rebalancing.

### H3. `heal()` overcharged past the health cap — **FIXED**
Clamps the request to `health_max - current` before pricing it; a miner already at full health is
rejected rather than charged. `logheal` reports the clamped amount.

### M1–M3 — **FIXED**
Dead `plotdef`/`plotset`/`plotdel` removed (the plot model is now fixed by design rule #1). The
`orng.wax::requestrand` and AtomicAssets `mintasset`/`burnasset`/`transfer` ABIs were verified and
documented at both the call sites and in the `ext/` headers; the RNG signing value now mixes
`tapos_block_prefix()` and the microsecond clock instead of being derivable from public state.

### Bugs found while applying those fixes — **FIXED**
- **`buylandslot` refunded its own charge**: it read the account singleton, called `sub_balance`
  (which writes it), then wrote back the stale local — reverting the debit. **Land slots were
  free.** Now re-reads after the debit.
- `configset` now validates `silver_token_contract`/`fee_account` are real accounts and rejects a
  `silver_symbol` change.
- `minerset` now enforces `health_consumed > 0` and `gold_rate ∈ [0,1]` (a `gold_rate` above 1
  made every mine drop Gold).
- Underflow guards on `durability_remaining - 1` and `uses_remaining - 1`.
- `resolve_mine` credits go through `credit_safe()` so an uncreditable recipient reroutes to the
  miner's net instead of stranding the callback; `setreferrer` requires a registered referrer.

### Follow-up requests — **IMPLEMENTED**
- **Land-plot unlocking is admin-configurable**: `slotconf` singleton + `slotcfgset(free_slots,
  max_slots)`. `free_slots` replaces the hardcoded 1 (bounded by `MAX_FREE_LAND_SLOTS`);
  `max_slots` caps purchases (`0` = uncapped). Defaults reproduce the old behaviour exactly.
  Not retroactive by design.
- **Gold is an in-game count backed 1:1 by the NFT.** `accounts.gold` (uint64) added.
  *Deposit* → NFTs burned, `gold += N`, **zero RAM** (no `deposits` row, fixed-width field, so
  `same_payer` works inside the notify handler). *Withdraw* → `wdrawgold` debits and mints back,
  capped at `MAX_GOLD_WITHDRAW`. *Mining drop* → credits `gold += GOLD_PER_DROP` instead of
  minting, which takes `mintasset` off the oracle callback and removes the old
  mint→deposit→burn round-trip; it goes through the non-asserting `credit_gold_safe()` so a drop
  can never strand the callback. All three emit `loggold(owner, amount, direction)`.
  The `gold_template_id >= 0` guard matters: AtomicAssets uses `-1` for template-less assets.

---
---

## Summary

| # | Issue | Severity | Status |
|---|---|---|---|
| **N1** | **Land & gear NFTs can never be withdrawn — permanent asset lock** | **Critical** | **Open** |
| **N2** | **No Silver backing the balances the contract owes** | **High** | **Open** |
| **N3** | **`configclear` resets `next_assoc_id` and bypasses symbol immutability** | **High** | **Open** |
| **N4** | **An unresolved craft locks its inputs forever (no cancel path)** | **High** | **Open** |
| **N5** | **A `gold_template_id` typo silently burns player assets** | **Medium** | **Open** |
| **N6** | **`listland` lacks the occupancy check `unlistland` has** | **Medium** | **Open** |
| **N7** | **Bad NFT result template permanently blocks `craftclaim`** | **Medium** | **Open** |
| **N8** | **Template deletion soft-bricks assets referencing it** | **Medium** | **Open** |
| **N9** | **`tosdel` of the last version bricks the contract** | **Medium** | **Open** |
| N10–N15 | Double cooldown, `bail()` cooldown asymmetry, missing batch caps, opaque config errors, write-only `landdef`, unused `cost_gold` | Low | Open |
| C1 | Crafting admin CRUD missing | Critical | Fixed |
| C2 | `craft()` didn't validate NFT inputs | Critical | Fixed |
| C3 | No busy lock → health could go negative | Critical | Fixed |
| C4 | No plot exclusivity | Critical | Fixed |
| C5 | Contract sponsored user RAM | Critical | Fixed |
| H1 | `unlistland` missing occupancy guard | High | Fixed |
| H2 | Commission read live at resolution | High | Fixed |
| H3 | `heal()` overcharged past the cap | High | Fixed |
| — | `buylandslot` reverted its own charge (land slots were free) | High | Fixed |
| M1–M3 | Dead `plotdef`; unverified RNG/mint ABIs | Medium | Fixed |

**Recommended order of work:** N1 first (it is the only one destroying user property), then N3 and
N5 (both are one admin action away from unrecoverable damage), then N4, then N2 — which is not a
code bug so much as an economic decision that has to be made before mainnet.

---

## Still open before testnet

1. **Nothing here has been compiled.** No `cdt-cpp`/`cmake` on this machine. Build first:
   `cdt-cpp -abigen -I include -o warforzlands.wasm src/warforzlands.cpp`.
2. **Frontend ABI reconciliation.** Removed `plotset`/`plotdel`; thirteen new admin actions
   (crafting CRUD, `fprwset`, `slotcfgset`); new player actions `claimdeps` and `wdrawgold`; new
   log action `loggold`; new/changed fields `accounts.gold`, `deposits.locked`,
   `mines.commission_rate`, `crafts.locked_assets`, `ReqNFT.burn`, `fprweights`, `slotconf`;
   `occupancy` gained `byplot`/`byland`. Behavioural changes the UI must reflect: `tosaccept` must
   precede any deposit, a new player's starting slot count is `slotconf.free_slots` rather than 1,
   Gold NFTs sent in are burned (show `accounts.gold`, they will not appear in `deposits`), and
   `logmine.gold_dropped` now means "+1 to `accounts.gold`" — not "check your wallet".
3. **Tests.** `tests/` is still empty. Highest-value cases: double-`mine()` during the RNG window
   (must fail); resolution with insufficient health (must bail, health unchanged); landlord raising
   commission mid-flight (must pay the snapshot); two miners on one plot (must fail); `unlistland`
   while occupied (must fail); over-healing (charged only the deficit); craft with
   wrong/extra/missing NFTs (must fail); craft with a non-burn input (locks, then releases on
   claim); deposit before ToS (must fail); `buylandslot` at `max_slots` (must fail); registration
   under a non-default `free_slots`; the Gold round-trip (deposit N → burned, `gold == N`, no
   `deposits` rows → `wdrawgold(N)` → N minted back, `gold == 0`; `wdrawgold(N+1)` must fail); and
   a mine resolving with `gold_rate = 1.0` → `gold += 1` with **no** `mintasset` in the trace.
