# Mining Game — Frontend Build Plan & Agent Prompts

This document has three parts:

1. **Build plan** — the phased order the agent should execute in, and why.
2. **Master brief** — the always-on prompt describing the game, wallets, and business logic. Provided to the agent at every phase.
3. **Per-phase prompts** — what you paste into the agent when kicking off each phase.

The agent should complete one phase, you review it, then move to the next.

---

## Part 1 — Build Plan

The frontend is built in **7 phases**, each ~1 unit of work, in strict order. Each phase must produce a working, verifiable result before the next begins.

| # | Phase | Deliverable | Depends on |
|---|---|---|---|
| 0 | **Project setup** | Next.js + TypeScript + Tailwind app, folder structure, env vars, contract config file | — |
| 1 | **Wallet connect** | Connect / disconnect for WAX Cloud Wallet, Anchor, Wombat; session persistence; account display | 0 |
| 2 | **Read-only chain layer** | Typed hooks/services that fetch all game tables (config, land/miner/gear templates, player state); no writes yet | 0 |
| 3 | **Player dashboard (read-only)** | Home screen showing account, Silver balance, land slots, activated lands, miners, gear, referrer — using phase 2 data | 1, 2 |
| 4 | **Custody flows (deposit/withdraw)** | Deposit miners/gear/lands (NFT transfer to contract), deposit Silver, withdraw Silver, withdraw miners | 3 |
| 5 | **Setup actions (non-mining)** | Buy land slot, activate land, remove land (with warning), equip/unequip gear, place/remove miner, set referrer, accept ToS | 4 |
| 6 | **Core gameplay (mine + heal)** | Own-land mining (including free-play RNG rarity gate), heal, live reward log, cooldown timers, land durability | 5 |
| 7 | **Cross-player mining + crafting + polish** | List/unlist land, mine on public lands (commission split), forge (craft/craft-claim), full transaction toasts, error states, mobile polish | 6 |

**Ordering rationale:** wallets first (nothing works without them). Read before write (Phase 2 → 3 proves data flow; only then do we touch transactions in Phase 4). Custody before setup (you can't activate a land you haven't deposited). Setup before mining (you can't mine without a placed miner). Own-land mining before cross-player (simpler auth model first). Crafting last because it uses the same async-RNG pattern already proven by mining.

**Rules the agent follows across every phase:**
- Never invent contract action names or table names — always use the ones in the master brief.
- Never assume contract behavior — for anything not in the brief, ask the human before coding.
- All chain writes go through a single `signTransaction()` helper so wallet-swapping is transparent.
- All chain reads go through typed hooks — no ad-hoc `fetch` calls scattered in components.
- Every screen has: loading state, empty state, error state.
- After each phase, produce a short **PHASE-N-REPORT.md** listing what was built, what's stubbed, and any assumptions made.

---

## Part 2 — Master Brief (attach to every phase prompt)

> The text between the fences below is the always-on brief. Paste it once at the top of every phase prompt so the agent has full context.

```
=========================
MASTER BRIEF — MINING GAME FRONTEND
=========================

## 1. What you are building

A web frontend for a blockchain mining game deployed on the WAX blockchain (EOSIO-family). Players deposit NFTs (miners, gear, lands) and Silver tokens into a smart contract, use them to mine Silver rewards (with a rare chance of Gold NFT drops), and later withdraw. The frontend must talk to three wallets and to the game's smart contract.

## 2. Wallets you must support

The user picks one on connect. All three follow standard WAX signing patterns.

- **WAX Cloud Wallet** — use the official `@wharfkit/wallet-plugin-cloudwallet` (or equivalent from the wharfkit ecosystem).
- **Anchor Wallet** — use `@wharfkit/wallet-plugin-anchor`.
- **Wombat Wallet** — use `@wharfkit/wallet-plugin-wombat`.

Use `@wharfkit/session` as the unified session layer so the same `signTransaction()` call works for all three. Persist the chosen wallet + account across reloads.

Chain constants:
- Chain ID: `1064487b3cdcc7a58a4d0d2b1e0c2c8a4e4e2e2e2e2e2e2e2e2e2e2e2e2e2e2e` (WAX mainnet — CONFIRM before shipping)
- RPC endpoint: user-configurable, default `https://wax.greymass.com`
- Contract account: configurable via env var `NEXT_PUBLIC_CONTRACT`

## 3. Game concept

Player hierarchy: **player → land slots → activated land → plots → miner (+ optional gear)**.

- **Miner** — NFT worker. Has health and cooldown. Reusable: withdraw and redeposit freely.
- **Gear** — NFT tool (sword, axe, pick, etc.). Boosts a miner's mining capacity. Consumable: on activation, becomes account-bound; wears down with use and burns when depleted; can be manually removed (with warning) but not recovered.
- **Land NFT** — NFT arena. Consumable: on activation, becomes account-bound; durability decrements each mine; burns when depleted. Can be manually removed (with warning). Can be listed publicly so other players can mine it for a commission.
- **Free-play land** — a special land template. **Max one per account.** Never burns. Its miner selection is RNG-rarity-gated (only a specific miner rarity is allowed to mine there, and the allowed rarity rotates on a timer set by the RNG oracle). **Cannot be listed publicly — private/owner-only.**
- **Land slot** — a holder on the player's account for one activated land. **1 unlocked by default at registration.** More can be bought with Silver/Gold.
- **Plot** — a mining position on a land, holds one miner.
- **Silver** — the main token. Earned by mining, withdrawable, has a withdrawal fee.
- **Gold** — a rare NFT drop from mining; kept as a collectible.

## 4. Currencies & the reward waterfall

Every mine session produces a gross Silver reward:

```
gross = miner.reward_rate × gear_mining_capacity_multiplier × land_bonus
```

The reward is split **out of** the gross (zero-sum, no minting on top):

1. Platform fee → fee account
2. If mining on someone else's listed land: landlord commission % → landowner
3. Referral cut % of the miner-owner's remaining share → their referrer (if any, single-level, immutable)
4. Remainder → miner owner
5. Rare Gold NFT drop (chance based on `gold_rate`) → miner owner
6. Decrement land durability (landowner's land) — burn if zero
7. Decrement gear uses (miner-owner's gear) — burn if zero
8. Decrement miner health (refill by heal)

## 5. Randomness (async)

Some actions (mine, craft) request randomness from the WAX RNG oracle (`orng.wax`). These actions do NOT resolve instantly: the contract stores a pending request and the outcome is delivered a moment later via a `receiverand` callback. The frontend must:
- Show a "pending" state after firing the action
- Poll the relevant table (rngassocs / brawls / crafts) for resolution
- Show the outcome and emit a receipt toast once resolved

## 6. Smart-contract surface (what the frontend calls)

Contract account: configured via env var.

Action names, parameter order, and rules are exact — do not rename or reorder.

### Admin actions (not called from player frontend; ignore unless building an admin panel)
- `configset`, `configclear`, `maintset`
- `minerset` / `minerdel`, `gearset` / `geardel`
- `landset` / `landdel`, `landdset` / `landddel`
- `plotset` / `plotdel`
- Crafting: `ruleset`/`ruledel`, `ruleitemadd`/`ruleitemdel`, `recset`/`recdel`, `recreqaddft`/`recreqaddnft`/`recreqdel`, `recresadd`/`recresdel`
- `tosset` / `tosdel`

### Player actions (frontend calls these)

Setup:
- `tosaccept(account)` — accept current terms
- `setreferrer(account, referrer)` — one-time immutable binding of a referrer
- `buylandslot(owner)` — pay Silver/Gold to unlock another land slot
- `activateland(owner, land_slot, land_asset_id)` — bind a deposited land NFT to a slot
- `removeland(owner, land_slot)` — permanently burn the land in a slot (frontend MUST show a warning before calling)
- `mineradd(owner, plot_id, miner_id)` / `minerrem(owner, plot_id, miner_id)` — place/remove a miner
- `gearadd(owner, miner_id, gear_id)` / `gearrem(owner, miner_id, gear_id)` — equip/unequip gear (removal burns gear — warn)
- `listland(owner, land_slot, commission_rate)` / `unlistland(owner, land_slot)` — public mining
  - Rejects free-play land templates

Gameplay:
- `mine(miner_owner, land_owner, land_slot, plot_id, miner_id)` — start a mine session; async via RNG
- `heal(owner, miner_id, amount)` — spend Silver to restore miner health
- `craft(owner, category, recipe_id, asset_ids)` — start a craft; async via RNG
- `craftclaim(owner, assoc_id)` — collect resolved craft rewards

Cash out:
- `wdrawminer(owner, asset_ids)` — withdraw miners back to wallet (only if not deployed/placed)
- `wdrawsilver(owner, quantity, fee)` — withdraw Silver, fee applied

### Notification-based (not called directly — happen via transfers)
- Send NFTs to the contract → auto-recorded as deposited miners/gear/lands
- Send Silver to the contract → credited to balance

### System (never call from frontend)
- `receiverand`, `logmine`, `logcraft`, `logheal` — oracle callback + inline logs

## 7. Tables the frontend reads

All via `/v1/chain/get_table_rows`.

- `config` (scope: contract) — global settings, fees, gold template id, maintenance mode
- `tosconfig` (scope: contract) — ToS versions
- `tosuser` (scope: contract) — which ToS version each account accepted
- `minerconf`, `gearconf`, `landconf`, `landdef`, `plotdef` (scope: contract) — templates
- `craftrecipes`, `craftrules`, `craftcounts` (scope: contract) — forge content
- `accounts` (scope: contract, key: account) — the player's in-game wallet (Silver, Gold balances)
- `landslots` (scope: owner) — the player's land slots (unlocked count + what land occupies each)
- `lands` (scope: owner) — the player's activated lands (durability, listing status, commission)
- `miners` (scope: owner) — deposited miners (health, cooldown, plot placement)
- `gear` (scope: owner) — deposited/activated gear (uses remaining, attached miner)
- `mines` (scope: owner) — active mine sessions
- `crafts` (scope: owner) — active craft sessions
- `deposits` (scope: owner) — NFTs deposited but not yet activated/placed
- `rngassocs` (scope: contract) — pending RNG requests (poll for resolution)
- `referrals` (scope: contract, key: referee) — one-time referrer binding
- `freeplaystate` (scope: contract) — current allowed miner-rarity + next-rotation timestamp for free-play land

The frontend never assumes fields not listed in the design reference; when a field is needed but missing, ask before proceeding.

## 8. Rules the frontend enforces (client-side pre-check + server verifies)

- Maintenance mode ON → block all player writes with a friendly message.
- ToS: block player writes until `tosuser.version == tosconfig.latest_version`.
- Removing a land or gear shows a **destructive-action warning modal** with the exact wording: *"Removing this [land/gear] will destroy it permanently. You cannot recover, sell, or re-use it. Remaining uses will be lost."* — user must type-to-confirm or click a distinct red button.
- Free-play land: exactly one per account; the "Activate" button on a free-play template is disabled if one is already activated.
- Free-play land is never listed publicly; hide the "List" button for that land.
- Withdrawing a miner requires it to be not placed and not in an active mine session.
- Mining on someone else's land requires the land to be currently listed (`is_listed = true`).
- Miner cooldown / land durability > 0 / gear uses > 0 checked before enabling the Mine button.

## 9. UX conventions

- Every action is one clear button, one clear outcome, one clear receipt (toast).
- Loading states for all reads; pending states for all writes (including the async RNG wait for mine/craft).
- Numbers formatted with locale thousands separators; Silver shown to 4 decimals (WAX asset precision).
- Timers (cooldowns, RNG windows) live-update every second without refetching from chain.
- On mobile: single-column, thumb-reachable primary actions.

## 10. What to do when unclear

If any table field, action parameter, or business rule needed for the phase is not in this brief or the mining-game design reference, STOP and ask the human. Do not invent, guess, or improvise contract behavior.
=========================
END OF MASTER BRIEF
=========================
```

---

## Part 3 — Per-phase Prompts

For each phase: paste the master brief above, then the phase prompt below, into a fresh agent session. Review the deliverable and the PHASE-N-REPORT.md before moving on.

---

### Phase 0 — Project setup

```
Execute Phase 0 of the mining-game frontend build plan.

Goal: create the project skeleton and nothing more.

Tasks:
1. Initialize a Next.js 14+ app with TypeScript, App Router, and Tailwind CSS.
2. Add these dependencies: @wharfkit/session, @wharfkit/wallet-plugin-cloudwallet, @wharfkit/wallet-plugin-anchor, @wharfkit/wallet-plugin-wombat, @wharfkit/contract, zustand (state), swr (data fetching).
3. Create the following folder structure:
   - src/app/                    (routes)
   - src/components/             (UI components)
   - src/lib/chain/              (contract config, table readers, action senders)
   - src/lib/wallet/             (wallet session)
   - src/lib/state/              (zustand stores)
   - src/lib/types/              (typed table/action interfaces)
4. Create src/lib/chain/config.ts exporting:
   - CHAIN_ID, RPC_URL (from env), CONTRACT (from env), ATOMICASSETS_CONTRACT, SILVER_TOKEN_CONTRACT, SILVER_SYMBOL
5. Add .env.example with all required vars.
6. Wire up Tailwind with a base color palette (dark theme, mining/industrial aesthetic — dark grays, amber/silver accents).
7. Create a placeholder home page that just says "Mining Game — Phase 0 OK".

Deliverables:
- Working `npm run dev` on http://localhost:3000
- PHASE-0-REPORT.md listing package versions, env vars, folder tree, and any assumption made.

Do NOT: implement wallet connect, contract calls, or any UI beyond the placeholder. Those are Phase 1+.
```

---

### Phase 1 — Wallet connect

```
Execute Phase 1 of the mining-game frontend build plan.

Goal: users can connect and disconnect any of three wallets, and the session persists.

Tasks:
1. In src/lib/wallet/session.ts, initialize a wharfkit SessionKit with three WalletPlugins: cloudwallet, anchor, wombat. Chain from src/lib/chain/config.ts.
2. Create a WalletProvider React context that exposes: session, account, connect(walletName), disconnect(), signTransaction(actions).
3. Persist the active session in localStorage; restore on app load.
4. Build a "Connect Wallet" button in the header with a modal showing three wallet options. Show the connected account name + a "Disconnect" option when signed in.
5. Ensure `signTransaction()` works identically for all three wallets (this is what phases 4+ depend on).

Deliverables:
- Working connect/disconnect for all three wallets on WAX mainnet (or testnet if configured).
- Header shows account (e.g. myplayer.wam) when connected.
- PHASE-1-REPORT.md with screenshots or curl-equivalent confirmation, plus any wallet-specific gotchas.

Do NOT: fetch any game data, or call any contract action. Reads are Phase 2, writes are Phase 4+.
```

---

### Phase 2 — Read-only chain layer

```
Execute Phase 2 of the mining-game frontend build plan.

Goal: typed hooks/services that fetch every game table listed in section 7 of the master brief.

Tasks:
1. In src/lib/types/, define TypeScript interfaces for every table row: Config, TosConfig, TosUser, MinerConf, GearConf, LandConf, LandDef, PlotDef, CraftRecipe, CraftRule, CraftCount, Account, LandSlot, Land, Miner, Gear, Mine, Craft, Deposit, RngAssoc, Referral, FreePlayState. Fields must match the mining-game design reference exactly.
2. In src/lib/chain/tables.ts, implement a generic `getTableRows<T>(table, scope, options)` helper.
3. In src/lib/chain/queries.ts, expose typed queries: getConfig(), getTosConfig(), getMinerTemplates(), getPlayerAccount(name), getPlayerLandSlots(name), getPlayerLands(name), getPlayerMiners(name), getPlayerGear(name), getPlayerDeposits(name), getPlayerReferrer(name), getFreePlayState(), etc.
4. Wrap each in a SWR hook: usePlayerAccount(name), usePlayerLands(name), etc. Sensible refetch intervals (60s for templates, 15s for player state, 3s while a mine/craft is pending).

Deliverables:
- All hooks compile and return typed data.
- A hidden `/debug` page dumps raw output of each hook for the connected account, for manual verification.
- PHASE-2-REPORT.md listing every hook and any table fields that were unclear.

Do NOT: build user-facing UI (Phase 3), or any write actions.
```

---

### Phase 3 — Player dashboard (read-only)

```
Execute Phase 3 of the mining-game frontend build plan.

Goal: a home dashboard for the connected player showing all their game state, using Phase 2 hooks. Read-only — no write actions yet.

Tasks:
1. Layout: header (from Phase 1), left nav (Dashboard, Lands, Miners, Gear, Forge, Cash Out — future links stubbed), main content.
2. Dashboard sections:
   - Account summary: Silver balance, active referrer (or "Set referrer" hint — stubbed button), ToS acceptance status.
   - Land slots: cards showing each slot (unlocked/locked), and what's activated in each (land name, rarity, durability bar, listed status).
   - Free-play land status: current allowed miner rarity + next rotation timer.
   - Miners: grid of deposited miners with health bar, cooldown timer, placed-in-plot info.
   - Gear: grid of deposited/activated gear with uses-remaining bar, equipped-to-miner info.
   - Deposits (unassigned): NFTs deposited but not yet activated/placed.
3. Every section has loading, empty, and error states.
4. Live timers (cooldowns, free-play rotation) tick every second without refetching.

Deliverables:
- Dashboard fully renders for a connected account.
- All Phase 2 hooks visibly used.
- PHASE-3-REPORT.md with screenshots and any UX decisions made.

Do NOT: implement any writes yet — buttons that would trigger a chain action should be visible but disabled with a "Coming in Phase 4/5/6" tooltip.
```

---

### Phase 4 — Custody flows

```
Execute Phase 4 of the mining-game frontend build plan.

Goal: deposit and withdraw. This is the first phase that signs transactions.

Tasks:
1. Deposit NFTs (miners/gear/lands): a "Deposit" page listing the player's wallet-side NFTs from the game's collection (fetched from AtomicAssets). Multi-select + "Deposit to game" button that fires an AtomicAssets transfer to the contract account with the correct memo. Show pending → success → updated deposits list.
2. Deposit Silver: a form with amount + "Deposit" button that fires a Silver token transfer to the contract with the correct memo.
3. Withdraw Silver: form → calls `wdrawsilver(owner, quantity, fee)`. Show fee preview from config.
4. Withdraw miners: multi-select on deposited/unplaced miners → calls `wdrawminer(owner, asset_ids)`. Block selection of miners that are placed or in an active mine.
5. All actions go through the single `signTransaction()` helper. All successful actions trigger a table refetch of affected hooks and a toast receipt.

Deliverables:
- Full deposit/withdraw round-trip verified on testnet.
- PHASE-4-REPORT.md documenting the memo formats used for deposits (these MUST match the contract's on-notify handlers — confirm with the human before shipping if unsure).

Do NOT: implement setup or gameplay actions yet.
```

---

### Phase 5 — Setup actions

```
Execute Phase 5 of the mining-game frontend build plan.

Goal: everything a player does before mining.

Tasks (each is a button/flow calling the named action):
1. `tosaccept` — a banner shown until accepted, blocking all other writes.
2. `setreferrer` — an onboarding modal or settings page. One-shot, immutable — show a clear warning that it cannot be changed later.
3. `buylandslot` — from the Lands page, shows current slot count and the cost of the next slot; on confirm, fires the action.
4. `activateland` — from a land NFT in Deposits, "Activate into slot [dropdown of empty slots]". If the NFT is the free-play template, verify the player doesn't already have one active; if they do, the button is disabled with a tooltip.
5. `removeland` — destructive; type-to-confirm modal with the exact wording from master brief §8.
6. `mineradd` / `minerrem` — drag or button-driven placement of a miner into a plot.
7. `gearadd` / `gearrem` — attach/detach gear. `gearrem` is destructive; show the same-style warning modal.
8. `listland` / `unlistland` — from an activated land, a "List for public mining" toggle with a commission-rate input (0–100). Free-play land: toggle hidden.

Deliverables:
- All setup flows work end-to-end. Dashboard reflects state after every action.
- PHASE-5-REPORT.md.

Do NOT: implement mine, heal, craft, or cross-player mining yet.
```

---

### Phase 6 — Core gameplay (mine + heal)

```
Execute Phase 6 of the mining-game frontend build plan.

Goal: the actual game loop, own-land only.

Tasks:
1. Mine flow (own land): "Mine" button on each placed miner. Preconditions checked client-side (miner off cooldown, has health, land durability > 0, gear uses > 0, free-play miner-rarity matches allowed). On click:
   - Fire `mine(miner_owner=self, land_owner=self, land_slot, plot_id, miner_id)`.
   - Show a "Mining… waiting for randomness" pending state.
   - Poll `rngassocs` + `mines` tables every 2–3s until the session resolves.
   - Once resolved, show the reward breakdown (gross → fee → referral → net Silver, plus any Gold NFT drop) as a receipt toast + an activity feed entry.
   - Refetch player state.
2. Heal flow: a "Heal" button per miner opens a slider (health points needed → Silver cost preview using `health_cost` from config). Fires `heal(owner, miner_id, amount)`.
3. Live cooldown timers on miners and lands.
4. Land durability bar decrements after each successful mine; when a land burns, show a clear notification and empty the slot in the UI.
5. Activity feed on the dashboard showing the last N mines/heals for this account, reading from log traces (via a history endpoint like hyperion / atomichub).

Deliverables:
- End-to-end own-land mine works reliably (including free-play RNG gate).
- PHASE-6-REPORT.md.

Do NOT: implement cross-player mining or crafting yet.
```

---

### Phase 7 — Cross-player mining + crafting + polish

```
Execute Phase 7 of the mining-game frontend build plan.

Goal: the social layer + forge + production polish.

Tasks:
1. Public lands directory: a "Public Lands" page listing all lands with `is_listed = true` (scoped scan across accounts via a hyperion-style index or a `landsindex` table if provided). Show landowner, land rarity, durability remaining, commission %.
2. Mine on someone else's land: on a public land, "Send Miner" flow — pick a miner + gear from your own inventory. Fires `mine(miner_owner=self, land_owner=other, land_slot, plot_id, miner_id)`. Reward breakdown now shows the landlord split.
3. Forge:
   - Recipes list from `craftrecipes` filtered by current time window.
   - `craft` flow: pick recipe + input NFTs, confirm, fire action, pending state, poll `crafts` table for resolution.
   - `craftclaim` when status becomes claimable.
4. Polish pass:
   - Full mobile responsive review.
   - All error paths (insufficient balance, cooldown, missing ToS, maintenance mode) surface a specific, helpful message.
   - Empty states are welcoming, not blank.
   - A minimal onboarding flow for a brand-new account: connect wallet → accept ToS → set referrer (optional) → deposit first miner → deposit/activate free-play land → first mine.
5. Global error boundary + telemetry hook (console-only if no analytics provider).

Deliverables:
- Everything from Phases 1–6 plus cross-player mining, crafting, and polish.
- PHASE-7-REPORT.md summarizing the full app.

Do NOT: begin an admin panel or new features unless the human requests it.
```

---

## Appendix — Things worth telling the agent up-front (or verifying yourself)

Before Phase 0, confirm or fill in for the agent:

| Item | Where it lives |
|---|---|
| Actual contract account name | env var `NEXT_PUBLIC_CONTRACT` |
| Silver token contract + symbol/precision | env vars |
| WAX chain (mainnet vs testnet) + RPC endpoint | env vars |
| AtomicAssets collection name accepted by the contract | env var / config table |
| Exact memo formats the contract expects on NFT/Silver deposits | must be confirmed against the deployed contract |
| Whether hyperion/atomichub indexers are available for reading logs and cross-account scans (needed for Phase 6 activity feed + Phase 7 public lands directory) | infra decision |

Anything on this list that's unresolved should be handed to the agent as a note in the Phase 0 prompt — otherwise the agent will (correctly) stop and ask.
