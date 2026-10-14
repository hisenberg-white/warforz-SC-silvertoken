# PHASE 7 — Cross-player Mining + Crafting + Polish — Report

The social layer, the Forge, and the production polish pass. Completes the
frontend build (Phases 0–7).

## 1. Public lands directory — "Warfront" (`/warfront`)

- **Cross-account scan without an external index:** `getListedLands()` uses
  `/v1/chain/get_table_by_scope` to enumerate every account holding `lands`,
  then reads each scope's `lands` (in concurrent batches of 20, capped at 300
  owners) and keeps `is_listed` rows. No `landsindex` table or Hyperion needed.
- Each card shows landowner, land name + rarity, durability bar, and commission
  %. Your own listed lands are filtered out (managed on Territories).

## 2. Cross-player mining — "Send Miner"

`components/gameplay/SendMinerModal.tsx`: pick an **idle** miner (unplaced, not
in an active mine) + a plot id, fire `mine(self, land_owner, land_slot, plot_id,
miner_id)`. Reuses the Phase 6 async-RNG tracker (`MiningWatcher` is mounted on
the Warfront page). The reward estimate now includes the **landlord commission**
split (`estimateReward({ commissionPercent })`, waterfall: fee → landlord →
referral → net).

## 3. Forge (`/forge`)

- **Recipes** from `getCraftRecipes()` — enumerates `craftrecipes` scopes
  (the table is sub-scoped by category) and reads each, tagging rows with their
  category. Rows render generically (see caveat).
- **Craft**: pick a recipe → select input NFTs from deposits → fire
  `craft(owner, category, recipe_id, asset_ids)` → pending state.
- **Active crafts** (`crafts` table, polled at 3 s) list status; **Claim** fires
  `craftclaim(owner, assoc_id)`. The contract enforces the claimable status.

## 4. Polish

- **Onboarding checklist** (`components/dashboard/OnboardingChecklist.tsx`):
  ToS → deposit miner → activate land → place miner → mine, with per-step
  completion and links; self-hides once the player is set up.
- **Error / empty states** everywhere via `AsyncState`; write-guard banners on
  every action page; transaction toasts with explorer links.
- **Mobile**: single-column grids, collapsible sidebar, thumb-reachable primary
  buttons (verified via the responsive grid classes).
- **Global crash guard**: `ErrorBoundary` (console-only telemetry, no analytics
  provider), mounted at the app root.

## Caveats / open items (all documented, none guessed)

1. **`plot_id` for cross-player mine** — same undecided plot model (contract
   plan §6 line 417); the Send-Miner flow takes a plot id directly.
2. **Craft recipe / rule schema** — the contract plan leaves
   `craftrecipes`/`craftrules` fields under-specified. Recipes render whatever
   primitive fields exist, inputs are chosen by asset id, and the time-window
   filter is deferred until the schema is fixed. `crafts.status` claimable value
   is unknown, so Claim is always offered and the contract validates.
3. **Directory scale** — the cross-account scan is bounded to 300 owners; for a
   large player base, swap `getListedLands` for a Hyperion `landsindex` query.

## Verification

- `tsc -b` clean; `vite build` succeeds.
- Rendered in-browser: `/warfront`, `/forge` (connect prompts), full nav with no
  phase tags, no console errors.
- End-to-end cross-player mining + crafting requires the deployed contract with
  the real resolvers (contract Phases 8–9) and a connected wallet — human, on
  testnet.

---

**Frontend build complete (Phases 0–7).** See `README.md` for the architecture
overview and `PHASE-0..7-REPORT.md` for per-phase detail and the consolidated
list of items to confirm before mainnet.
