# PHASE 4 — Custody Flows (deposit / withdraw) — Report

First phase that **signs transactions**. All writes go through one path.

## What was built

- **`src/lib/chain/actions.ts`** — action builders returning plain wharfkit
  action objects (ABI-encoded at transact time):
  - `depositNftsAction` → `atomicassets::transfer(from, to=CONTRACT, asset_ids, memo)`
  - `depositSilverAction` → `<silver>::transfer(from, to=CONTRACT, quantity, memo)`
  - `withdrawSilverAction` → `CONTRACT::wdrawsilver(owner, quantity, fee)`
  - `withdrawMinersAction` → `CONTRACT::wdrawminer(owner, asset_ids)`
- **`src/lib/chain/useTransaction.ts`** — the single write path: pending →
  success/error toasts (with a `waxblock.io` tx link), `revalidatePlayer()` on
  success, and a `status` for disabling buttons. Builds authorization from the
  active session (`actor` + `permission`).
- **`src/lib/chain/useWriteGuard.ts`** — client mirror of master brief §8:
  blocks all writes while `config.maintenance_mode` is ON or the account
  hasn't accepted the latest ToS (server still enforces).
- **Read additions:** `getWalletNfts` / `useWalletNfts` (AtomicAssets `assets`
  table, scope = owner, filtered to the game collection — no external indexer)
  and `getPlayerMines` / `usePlayerMines` (to detect in-use miners).
- **Toasts:** `src/lib/state/toastStore.ts` + `src/components/ui/Toaster.tsx`
  (mounted in `App`).
- **Treasury page** (`/cashout`, nav "Treasury") composing four flows, each in
  a `Card`, gated by the write-guard banner:
  - **DepositNfts** — multi-select wallet NFTs → deposit.
  - **DepositSilver** — amount → token transfer (first deposit auto-registers
    the account).
  - **WithdrawSilver** — amount + Max, live fee/net preview from `config.fee`,
    balance validation.
  - **WithdrawMiners** — multi-select; miners that are **placed** (`plot_id != 0`)
    or **in an active mine** (in the `mines` table) are shown locked and cannot
    be selected.

## Memo formats

The contract's `on_notify` handlers credit deposits by matching `to == _self`
(+ collection for NFTs) and **do not parse the memo** (contract plan §4).
Both deposit memos are therefore **empty strings**, centralized in
`config.ts` as `NFT_DEPOSIT_MEMO` / `SILVER_DEPOSIT_MEMO`.
⚠️ **Confirm against the deployed contract before mainnet** — if a future
revision tags deposits, change only those two constants.

## Withdrawal fee

`wdrawsilver` takes `fee` as an asset and the contract **rejects a mismatch**
(plan §6/line 619). `computeSilverFee()` computes it as
`floor(grossUnits × config.fee / 100)` in integer token units.
⚠️ **Assumption:** the contract truncates the same way. If it rounds
differently, reconcile this one function. Verify on testnet before shipping.

## Verification

- `tsc -b` clean; `vite build` succeeds.
- Rendered in-browser: Treasury page, nav ("Treasury" no longer phase-tagged),
  connect prompt, no console errors.
- Full deposit/withdraw round-trip requires a deployed contract +
  `VITE_CONTRACT` / `VITE_SILVER_TOKEN_CONTRACT` / `VITE_COLLECTION_NAME` and a
  connected wallet — to be run by the human on testnet.

## Open items to confirm before mainnet

1. Deposit memo strings (currently empty).
2. `wdrawsilver` fee rounding vs the contract's `int128` math.
3. RAM-payer choice for first-time `deposits` rows (contract-side; no frontend
   impact, but affects whether a brand-new wallet needs sponsored resources).
