# PHASE 0 — Project Setup — Report

Framework note: the plan text specified Next.js; per the explicit decision at
kickoff, the project was built as a **Vite + React SPA** (cleaner fit for the
browser-only `@wharfkit/*` wallet libraries, no SSR concerns). Env vars use the
`VITE_` prefix instead of `NEXT_PUBLIC_`.

## Stack / package versions

| Package | Version |
|---|---|
| react / react-dom | ^18.3.1 |
| react-router-dom | ^6.28.0 |
| vite | ^6.0.7 (resolved 6.4.3) |
| typescript | ^5.7.2 |
| tailwindcss | ^3.4.17 |
| zustand | ^5.0.2 |
| swr | ^2.3.0 |
| @wharfkit/session | ^1.5.0 |
| @wharfkit/contract | ^1.2.0 |
| @wharfkit/web-renderer | ^1.4.0 |
| @wharfkit/wallet-plugin-cloudwallet | ^1.4.0 |
| @wharfkit/wallet-plugin-anchor | ^1.4.0 |
| @wharfkit/wallet-plugin-wombat | ^1.3.0 |

## Env vars (`.env.example`)

`VITE_CHAIN_ID`, `VITE_RPC_URL`, `VITE_CONTRACT`, `VITE_ATOMICASSETS_CONTRACT`,
`VITE_SILVER_TOKEN_CONTRACT`, `VITE_SILVER_SYMBOL`, `VITE_COLLECTION_NAME`,
`VITE_APP_NAME`.

## Folder tree

```
src/
  app/            routes.tsx + pages/ (Dashboard, Debug, PhaseStub, NotFound)
  components/     layout/, wallet/, dashboard/, ui/, ErrorBoundary
  lib/
    chain/        config.ts, tables.ts, queries.ts, hooks.ts
    wallet/       session.ts, WalletProvider.tsx, useWallet.ts
    state/        walletStore.ts (zustand)
    types/        tables.ts, index.ts
    utils/        format.ts, time.ts, cn.ts, useClock.ts
  App.tsx, main.tsx, index.css
```

## config.ts exports

`CHAIN_ID`, `RPC_URL`, `CONTRACT`, `ATOMICASSETS_CONTRACT`,
`SILVER_TOKEN_CONTRACT`, `SILVER_SYMBOL` (+ derived `SILVER_PRECISION`,
`SILVER_CODE`), `COLLECTION_NAME`, `APP_NAME`, `RNG_ORACLE`.

## Theme

Tailwind dark, industrial palette: `ore.*` grays, `gold` primary accent,
`silver` currency accent. Base component classes (`.panel`, `.btn-primary`,
`.btn-ghost`, `.chip`) in `index.css`.

## Verification

- `npm install` — 241 packages, ok.
- `npx tsc -b` — clean, no errors.
- `npx vite build` — succeeds; vendor code-split into `react` + `wharfkit`
  chunks (app bundle ~45 kB gzip 15 kB).
- `npm run dev` — serves on http://localhost:3000; home renders.

## Assumptions

- `@wharfkit/web-renderer` added (not in the original dep list) because
  `SessionKit` requires a `ui`; it is the canonical wharfkit UI renderer.
- WAX mainnet chain id from the brief is used as the default and is flagged
  "CONFIRM before shipping" in `.env.example`.
