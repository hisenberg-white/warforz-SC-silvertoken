# PHASE 6 — Core Gameplay (mine + heal) — Report

The own-land game loop, including the async-RNG pending/resolve flow.

## What was built

**Action builders** (`lib/chain/actions.ts`): `mine(miner_owner, land_owner,
land_slot, plot_id, miner_id)` and `heal(owner, miner_id, amount)`.

**Mine flow** (`components/gameplay/MineControls.tsx`, on the Warband page under
each placed miner):
- Client-side preconditions mirror contract plan §7: miner off cooldown
  (`available <= now`), `health >= health_consumed`, land `durability > 0`, all
  attached gear `uses > 0` and off cooldown, and — for free-play land — miner
  rarity == `freeplaystate.current_allowed_rarity`. The button is disabled with
  the specific blocking reason as its label/title.
- A **land-slot selector** (see caveat) picks which activated land to mine;
  auto-selected when the player has exactly one.
- An **estimated reward breakdown** (gross → fee → referral → net + gold-drop %)
  from the §3/§4 formula, clearly labelled "estimate only".
- Fires `mine(self, self, slot, miner.plot_id, miner_id)` and enters a
  "Mining… awaiting randomness" state.

**Async resolution** (`state/miningStore.ts` + `components/gameplay/MiningWatcher.tsx`):
the mine is tracked by miner asset id. `useMinesFast` polls the `mines` table at
3 s while any session is in flight. A session resolves when its `mines` row is
observed and then disappears (the RNG callback erases it), with a 25 s grace
fallback for very fast resolutions. On resolve: a receipt toast fires and
`revalidatePlayer()` refreshes balances, durability, cooldowns, and the feed.

**Heal flow** (`components/gameplay/HealModal.tsx`): a slider from 1 to the
health deficit, with a live Silver cost preview (`amount × health_cost` from
`minerconf`). Fires `heal`.

**Live timers**: each placed miner shows a per-second cooldown `Countdown`
(shared clock). Durability/health bars update automatically after resolution via
revalidation; a burned land simply vanishes from its slot on the next fetch.

**Activity feed** (`components/dashboard/ActivityFeed.tsx`): reads `mine`/`heal`
(+ `logmine`/`logheal`) traces from a **Hyperion** endpoint
(`VITE_HYPERION_URL`, optional) via `get_actions`. When unconfigured it shows an
informational empty state. Because the contract plan does not fix the
`logmine`/`logheal` field names, the row renders whatever asset/number fields
each log carries rather than assuming a schema.

Dashboard Phase-6 stubs were replaced with links to the Warband page.

## Caveats / open items

1. **`land_slot` for `mine`** — the mine action needs both `plot_id` (known:
   `miner.plot_id`) and `land_slot`. Mapping a plot back to its land slot
   depends on the still-undecided plot model (contract plan §6 line 417), so the
   UI asks the player to pick the land. Resolve once plots are finalized.
2. **Reward estimate** — the gross formula's exact gear-capacity combination and
   rounding aren't fully specified; the estimate is a projection only. The
   authoritative amounts come from `resolve_mine` / the activity feed.
3. **`logmine` schema** — field names unknown; feed renders generically.

## Verification

- `tsc -b` clean; `vite build` succeeds.
- Rendered in-browser (Warband + dashboard), no console errors.
- End-to-end mine/heal + RNG resolution requires a deployed contract with the
  real `resolve_mine` (contract Phase 7/9) and a connected wallet — human, on
  testnet. Note the contract plan ships `resolve_mine` as a **stub** until its
  own Phase 7, so a full reward round-trip needs that contract phase live.
