# Mining Game — Forge of Battle (Frontend)

Web frontend for a WAX blockchain mining game with a **medieval / ancient-battle**
theme. Players deposit NFTs (miners, gear, lands) and Silver, mine for rewards,
and withdraw. Built as a **Vite + React + TypeScript** SPA talking to WAX via
`@wharfkit`.

> **Build status: complete — all 7 phases of `mining_game_frontend_plan.md`.**
> Foundation, wallet connect (WAX Cloud Wallet / Anchor / Wombat), typed chain
> layer, dashboard (War Room), custody (Treasury: deposit/withdraw), setup
> actions (ToS, referrer, buy/activate/list/remove land, place miners, equip
> gear — with type-to-confirm destructive modals), core gameplay (own-land mine
> with async-RNG resolve + reward estimate, heal, live timers, activity feed),
> and the social + crafting layer (Warfront public-lands directory + cross-player
> mining with landlord split, and the Forge: craft / craft-claim), plus the
> onboarding checklist and polish pass.
>
> Full end-to-end signing needs the deployed contract with its real resolvers
> and the env values filled in; see the per-phase reports for the short list of
> items to confirm before mainnet (deposit memos, fee rounding, the `plot_id`
> model, and the crafting schema).

## Theme

Medieval ancient-battle: forged-iron surfaces, aged bronze-gold accents, blood
crimson for irreversible/war actions, minted silver for currency. Headings use
the engraved **Cinzel** typeface; nav is themed (War Room, Territories, Warband,
Armory, Forge, Treasury). Palette tokens live in `tailwind.config.ts` and can be
re-skinned without touching component class names.

## Getting started

```bash
npm install
cp .env.example .env      # then fill in VITE_CONTRACT and token vars
npm run dev               # http://localhost:3000
```

Other scripts: `npm run build`, `npm run preview`, `npm run typecheck`.

## Configuration

All chain config is env-driven (see `.env.example`). The app runs without a
contract set (you'll see the connect prompt and empty/error states), but live
data needs at minimum `VITE_CONTRACT`, `VITE_SILVER_TOKEN_CONTRACT`, and a
working `VITE_RPC_URL`. The default `VITE_CHAIN_ID` is WAX mainnet —
**confirm before shipping**.

## Architecture

```
src/
  lib/chain/    config → tables (generic get_table_rows) → queries → hooks (SWR)
  lib/wallet/   SessionKit singleton, WalletProvider (restore), useWallet
  lib/state/    zustand wallet store (single source of truth)
  lib/types/    typed rows for every game table (mirror contract plan §5)
  lib/utils/    formatting, UTC time, shared 1s clock, cn
  components/   layout/, wallet/, dashboard/, ui/ (Card, StatBar, Countdown, …)
  app/          routes + pages (Dashboard, /debug, phase stubs)
```

Key conventions:

- **Reads** go only through typed hooks (`lib/chain/hooks.ts`) — no ad-hoc
  `fetch` in components. Refetch: templates 60 s, player 15 s, pending RNG 3 s.
- **Writes** go through one path: `useTransaction().run(actions, …)` →
  `signTransaction()` (wallet-agnostic) → pending/success/error toast →
  `revalidatePlayer()`. Action objects are built in `lib/chain/actions.ts`.
- **Write gating** (`useWriteGuard`) blocks actions during maintenance mode or
  before ToS acceptance, mirroring the contract.
- Every data section has **loading / empty / error** states (`AsyncState`).
- All countdowns share **one** 1-second clock; timers never trigger refetches.
- `/debug` dumps raw output of every read hook for manual verification.

## Phase reports

`PHASE-0-REPORT.md` … `PHASE-7-REPORT.md` document each phase, including
assumptions to confirm before mainnet — notably the `accounts` table scope, the
**deposit memo formats** (currently empty — Phase 4), and the **`wdrawsilver`
fee rounding** (Phase 4), plus the still-open appendix items (contract account,
indexer availability).
