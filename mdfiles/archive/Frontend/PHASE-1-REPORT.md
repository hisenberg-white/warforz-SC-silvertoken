# PHASE 1 — Wallet Connect — Report

## What was built

- **`src/lib/wallet/session.ts`** — single `SessionKit` (lazy singleton) with
  three `WalletPlugins` (CloudWallet, Anchor, Wombat), the env-driven `CHAIN`
  definition, and a `WALLET_PLUGIN_ID` map to the plugin `id` strings.
- **`src/lib/state/walletStore.ts`** — zustand store: the single source of
  truth for connection state (`status`, `session`, `account`, `permission`,
  `walletName`, `error`) with `restore` / `connect` / `disconnect` /
  `signTransaction` actions.
- **`src/lib/wallet/WalletProvider.tsx`** — restores a persisted session once
  on mount (the required context/provider).
- **`src/lib/wallet/useWallet.ts`** — the single accessor hook (adds
  `isConnected` / `isBusy` conveniences).
- **`src/components/wallet/ConnectWallet.tsx`** — header button + 3-wallet
  selection modal; shows account name + wallet + Disconnect when signed in.
- **`src/components/wallet/ConnectPrompt.tsx`** — signed-out placeholder for
  account-scoped pages.

## Session persistence

Handled by wharfkit `SessionKit` (localStorage). `WalletProvider` calls
`sessionKit.restore()` on load; `disconnect` calls `logout()` to clear it.
The dashboard shows a "Restoring session…" state while this runs.

## `signTransaction()` uniformity

All three wallets share one path: `session.transact({ actions })`. Phases 4+
call `useWallet().signTransaction(actions)` — wallet choice is transparent.

## Verification

- Header renders "Connect Wallet"; clicking opens the 3-option modal
  (verified in-browser via the accessibility tree).
- Selecting a wallet triggers the wharfkit login handshake (WebRenderer popup
  for the actual signing UI). Full end-to-end login requires the wallet apps
  and is performed by the human on testnet/mainnet.

## Gotchas / notes

- `SessionKit.login({ walletPlugin })` expects the plugin **id string**, not an
  index. Confirmed ids from the installed packages: `cloudwallet`, `anchor`,
  `wombat`.
- WebRenderer renders the login/signing UI; our custom modal only selects which
  wallet to log in with (passed straight to `login`), so the two don't conflict.
