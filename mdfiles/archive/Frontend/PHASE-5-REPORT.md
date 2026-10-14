# PHASE 5 — Setup Actions — Report

Everything a player does before mining. All writes reuse the Phase 4 path
(`useTransaction` → toast → revalidate) and are blocked by `useWriteGuard`
(maintenance / ToS), except `tosaccept` itself.

## What was built

**Action builders** (`lib/chain/actions.ts`) — exact names/params from contract
plan §6: `tosaccept`, `setreferrer`, `buylandslot`, `activateland`,
`removeland`, `listland`, `unlistland`, `mineradd`, `minerrem`, `gearadd`,
`gearrem`.

**ToS gate** (`components/setup/TosGate.tsx`, mounted app-wide in `AppLayout`):
banner shown to any connected account whose accepted version ≠ latest
`tosconfig.version`. "Read" opens the full ToS text; "Accept" fires
`tosaccept`. This is the one write not gated by ToS acceptance (§8).

**Set referrer** (`components/setup/SetReferrer.tsx`, in the dashboard account
card): modal with a permanent-and-immutable warning, WAX-name validation, and a
self-referral block. Fires `setreferrer`.

**Territories page** (`/lands`, `LandsPage`):
- **Buy slot** — shows the next slot's cost from `landslotcost[slot_index ==
  unlocked_land_slots]`; fires `buylandslot`.
- **Activate land** — each empty slot offers a dropdown of land-type deposits;
  a free-play template is disabled in the dropdown when a free-play land is
  already active (§8). Fires `activateland(owner, slot_id, asset_id)`.
- **List / unlist** — activated (non-free-play) lands get a commission input
  (0–100, validated) + List, or an Unlist button. The List controls are hidden
  entirely for free-play land (§8). Fires `listland` / `unlistland`.
- **Remove land** — red button opens the destructive modal; fires `removeland`.

**Warband page** (`/miners`, `MinersPage`): place/remove miners. Removal is
deterministic (uses `miner.plot_id`) and disabled while the miner is in an
active mine. See the plot caveat below.

**Armory page** (`/gear`, `GearPage`): equip gear onto a **placed** miner
(dropdown of placed miners only, per §6), or unequip. Unequip opens the
destructive modal because `gearrem` **burns** the gear.

**Destructive confirmation** (`components/ui/ConfirmDestructiveModal.tsx`): shows
the exact master-brief §8 wording — *"Removing this [land/gear] will destroy it
permanently. You cannot recover, sell, or re-use it. Remaining uses will be
lost."* — and requires typing `DESTROY` before the red button unlocks. Used by
both `removeland` and `gearrem`.

Dashboard stubs for now-built actions were replaced with links to the new pages;
nav phase-tags removed from Territories / Warband / Armory (Forge stays P7).

## Open item — miner placement `plot_id`

The contract plan **explicitly leaves plot numbering undecided** (§6, line 417:
"is `plot_id` global or per-land? CONFIRM"). No table the frontend reads
enumerates a land's plots. Rather than invent a plot model, the Warband page
exposes a direct **plot id input** for `mineradd`, with an on-page notice.
**Removal needs no id.** Once the plot design is finalized, replace the input in
`MinersPage` with a proper per-land plot picker — no action-builder change
needed.

## Verification

- `tsc -b` clean; `vite build` succeeds.
- Rendered in-browser: `/lands`, `/miners`, `/gear` (connect prompts + nav
  un-gated), no console errors.
- End-to-end signing requires a deployed contract + connected wallet (human,
  testnet). Free-play/listing/destructive guards are enforced client-side and
  re-checked by the contract.
