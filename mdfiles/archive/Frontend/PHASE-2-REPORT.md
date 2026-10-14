# PHASE 2 — Read-only Chain Layer — Report

## What was built

- **`src/lib/types/tables.ts`** — TypeScript interfaces for every table row.
  Field names/types/order mirror the **contract plan §5** exactly (this is the
  authoritative source, more precise than the frontend brief §7).
- **`src/lib/chain/tables.ts`** — generic `getTableRows<T>()` /
  `getTableRow<T>()` over `/v1/chain/get_table_rows`, with automatic `more`
  pagination (20-page safety cap), single-endpoint config, and `AbortSignal`.
- **`src/lib/chain/queries.ts`** — typed, game-aware queries (`getConfig`,
  `getMinerTemplates`, `getPlayerAccount`, `getPlayerLands`, `getPlayerMiners`,
  `getPlayerGear`, `getPlayerDeposits`, `getPlayerReferrer`, `getFreePlayState`,
  `getLatestTos`, `getTosUser`, `getLandSlotCosts`, `getPendingRng`, …).
- **`src/lib/chain/hooks.ts`** — SWR hook per query with tuned refetch
  intervals: templates 60 s, player state 15 s, pending RNG 3 s. Player hooks
  self-disable (null SWR key) until an account is known.

## Verification

Hidden **`/debug`** page dumps raw output of every hook for the connected
account (collapsible JSON + row counts + error badges). Confirmed rendering
in-browser; with `VITE_CONTRACT` unset each hook correctly shows its **error**
state (RPC rejects an empty `code`), which also exercises the shared
`AsyncState` error path. Point `VITE_CONTRACT` at a deployed contract to see
live rows.

## Serialization conventions encoded in the types

- `asset` → `"12.3456 SILVER"` string; `uint64_t` ids (asset_id, assoc_id) →
  **string** (may exceed JS safe-integer range); int32/uint32 counters →
  number; `time_point_sec` → zone-less UTC string (`time.ts` appends `Z`).

## Unclear / assumed table fields

- **`accounts` scope:** contract plan says singleton **scope = owner**; frontend
  brief §7 said "scope: contract, key: account". Followed the **contract plan**
  (scope = account) — this is the actual implementation source. ⚠️ confirm.
- **`craftrecipes` / `craftrules` / `craftcounts`:** row fields are
  under-specified in the contract plan ("key=recipe_id, sub-scoped by
  category"). Typed permissively (index signature) — tighten in Phase 7 when the
  forge schema is final. Not read on the dashboard.
- **`referrals` / `tosuser`** are contract-scoped, keyed by account name;
  queried via `lower=upper=account`, `key_type: 'name'`.
