# PHASE 3 — Player Dashboard (read-only) — Report

## What was built

Layout (`AppLayout` + `Header` + `Sidebar`): header with wallet control, left
nav (Dashboard, Lands, Miners, Gear, Forge, Cash Out), routed main content.
Future destinations render `PhaseStubPage` and are tagged with their phase (P4+)
in the nav.

Dashboard sections (each with its own loading / empty / error state via
`AsyncState`):

- **AccountSummary** — Silver balance, unlocked land slots, referrer (or a
  disabled "Set referrer" stub), ToS acceptance status, maintenance flag.
- **LandSlots** — a card per slot (unlocked/empty vs activated), land name +
  rarity + durability bar, listed status + commission, free-play badge. Renders
  empty slots up to `unlocked_land_slots` even when no `landslots` rows exist.
- **FreePlayStatus** — current allowed miner rarity + live "rotates in"
  countdown.
- **MinersGrid** — health bar, live cooldown countdown, plot placement, rarity;
  disabled Mine/Heal stubs (P6).
- **GearGrid** — uses-remaining bar, capacity boost, equipped-to-miner; disabled
  Equip/Unequip stub (P5).
- **DepositsList** — unassigned NFT deposits with a disabled Activate/Place stub
  (P5).

## Live timers without refetching

A single shared 1-second clock (`useClock`, backed by `useSyncExternalStore`)
drives every `Countdown`. Dozens of cooldown/rotation timers tick in sync from
one `setInterval` — no per-timer intervals, no chain refetch on tick.

## Disabled writes

All action buttons are present but disabled via `StubButton`, each with a
"Coming in Phase N" tooltip — no chain write can fire in this build.

## Phase 2 hooks used on the dashboard

`usePlayerAccount`, `usePlayerReferrer`, `useTosUser`, `useLatestTos`,
`useConfig`, `usePlayerLandSlots`, `usePlayerLands`, `useLandTemplates`,
`useLandDefs`, `useFreePlayState`, `usePlayerMiners`, `useMinerTemplates`,
`usePlayerGear`, `useGearTemplates`, `usePlayerDeposits`.

## UX decisions

- Numbers use locale separators; Silver uses the token precision from the symbol
  (`format.ts`).
- Chain timestamps are treated as UTC (append `Z`) before parsing (`time.ts`).
- A brand-new player with no `accounts` row shows a friendly empty state, not an
  error.
- Signed-out users see a `ConnectPrompt`; the whole app is wrapped in an
  `ErrorBoundary` (console-only telemetry).

## Verification

Rendered in-browser: dashboard connect-prompt, wallet modal (3 wallets), nav
with phase tags, `/debug`. `tsc -b` clean; `vite build` succeeds.
Live account data requires `VITE_CONTRACT` + a connected wallet.
