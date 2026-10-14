# WarForz Lands — Frontend Reference

**Single source of truth for the web client.** Supersedes `mining_game_frontend_plan.md`, `Frontend/README.md`, and `Frontend/PHASE-0-REPORT.md` … `PHASE-7-REPORT.md`.

Last verified against source: **2026-08-13**. `tsc -b` and `vite build` pass; 184 modules.

Contract behaviour this client talks to is documented in `WARFORZLANDS_CONTRACT.md`. Economy numbers are in `WARFORZLANDS_ECONOMY_CONFIG_V1.md`.

| Field | Value |
|---|---|
| Stack | Vite + React 18 + TypeScript, SPA (not Next.js) |
| Styling | Tailwind CSS, tokens in `tailwind.config.ts` |
| Wallet | `@wharfkit/session` — WAX Cloud Wallet, Anchor, Wombat |
| State | zustand (wallet, mining, toast, processing) |
| Data | SWR through typed hooks |
| Routing | react-router-dom |
| Repo | `Frontend/` is its own git repo |

---

## 1. Core conventions

These are load-bearing. Breaking them is how bugs get in.

- **Reads go only through typed hooks** in `lib/chain/hooks.ts`. No ad-hoc `fetch` in components.
- **Writes go through one path:** `useTransaction().run(actions, …)` → `signTransaction()` → toast → `revalidatePlayer()`. Action objects are built in `lib/chain/actions.ts`.
- **Write gating** (`useWriteGuard`) blocks actions during maintenance or before ToS acceptance, mirroring the contract.
- **The contract is authoritative.** Client-side checks are UX only — they exist so users don't fire doomed transactions, never as enforcement.
- **Never compute a final reward client-side.** Outcomes come from the on-chain `logmine` receipt.
- **All countdowns share one 1-second clock** (`useClock`). Timers never trigger refetches.
- **Every data section has loading / empty / error states** via `AsyncState`.
- **Chain config derives from on-chain tables**, with env values only as startup fallbacks.

---

## 2. Layout

```
src/
  app/
    routes.tsx           route table
    pages/               one file per route
  components/
    layout/              AppLayout, GameTopBar, GameBottomNav
    gameplay/            MineControls, SendMinerModal, HealModal, MiningWatcher
    dashboard/           AccountSummary, ActivityFeed, grids, checklist
    treasury/            deposit/withdraw panels
    setup/               TosGate, SetReferrer
    wallet/              ConnectWallet, ConnectPrompt
    ui/                  Card, Modal, StatBar, Countdown, Toaster, confirm modals…
  lib/
    chain/               config → tables → queries → hooks → actions → useTransaction
    wallet/              SessionKit singleton, WalletProvider, useWallet
    state/               zustand stores
    types/               typed rows mirroring every contract table
    utils/               format, time, useClock, rewards, cn
```

---

## 3. Routes

`/` is a public marketing page needing no wallet. The game lives under `/play`.

| Route | Page | Purpose |
|---|---|---|
| `/` | `LandingPage` | Public game info, no wallet required |
| `/play` | `HomePage` | **Primary gameplay** — land slot strip, mining expedition |
| `/play/dashboard` | `DashboardPage` | Account summary, activity feed, onboarding checklist |
| `/play/lands` | `LandsPage` | Slot management, activate/destroy land, list/unlist, unlock slots |
| `/play/miners` | `MinersPage` | Miner inventory — stake, heal, unstake |
| `/play/gear` | `GearPage` | Equipment inventory — stake, destroy |
| `/play/warfront` | `PublicLandsPage` | Directory of listed lands for cross-player mining |
| `/play/forge` | `ForgePage` | Smithy — craft and claim |
| `/play/cashout` | `TreasuryPage` | Deposit/withdraw FT, Gold, miners |
| `/play/settings` | `SettingsPage` | Referrer, session, preferences |
| `/play/admin` | `AdminPage` | Admin-only configuration console |
| `/play/debug` | `DebugPage` | Raw dump of every read hook |

Navigation is themed: War Room, Territories, Warband, Armory, Forge, Treasury.

---

## 4. Application gates

Evaluated in order, before any game content renders.

1. **Maintenance gate** — when on-chain maintenance is enabled, `/play` shows a dedicated maintenance page instead of login, Terms, content or navigation. Refreshes every 5s and on window focus.
2. **Blocked-account gate** — polls the connected wallet's `blocked` status and replaces the whole shell with an Account Blocked screen showing the configured reason and a disconnect option. Gated behind `VITE_BLOCKLIST_ENABLED` so the client doesn't query a table the deployed ABI may lack.
3. **ToS gate** — a **blocking first-login registration dialog**. Rejecting disconnects the wallet; accepting signs `tosaccept`, which creates the player account and initial free slot before gameplay is exposed.

Loader discipline: these gates enter loading state only when no initial/cached response exists. SWR polling and focus revalidation preserve the rendered game and enabled controls — no loader flashes on background refresh. Fullscreen loaders remain only for session restoration and signed transactions.

---

## 5. Gameplay — Home

Home is the centre of the game. Everything else is inventory management.

### Land strip

Every contract-provided Active, Empty, or Locked slot renders in **one horizontally scrollable row** — no pagination. Cards keep a stable responsive width; the row stays centred while it fits, so a single card is centred and shifts left as a new slot appears beside it. Overflow stays reachable by horizontal scroll while the shell height stays fixed.

Slots come only from the account's player-scoped `landslots` rows, plus exactly one next sequential enabled `slotconf` unlock. Actions use physical on-chain slot ids. Empty and locked cards use their actual compact width rather than reserving a full land-card width, keeping sequential slots contiguous.

Active land cards are framed, glowing and fully clickable: centred uppercase land name, right Active status pill, artwork status overlays, and a translucent HUD over the bottom of the artwork carrying **Durability, Land Boost and Allowed Miner**. Slot-number medallions are intentionally omitted from active cards. A prominent **Mine Now!** control sits inside the card. Artwork uses `object-contain` so plots are never cropped.

Free-play cards show only the gameplay-relevant current **Allowed Miner**; rotation mechanics stay internal.

### Mining Expedition

Clicking an active land opens a wide command panel styled as an ancient mining facility: carved timber command plates, soot-dark stone, weathered parchment and sandstone work bays, aged bronze/copper frames and rivets, oxidised equipment metal, a parchment mission ledger, and a mine-rail horizontal scrollbar. The three columns stack automatically on small screens. The full expedition interface uses the project's chunky Fredoka display face for a Clash-of-Clans-like game treatment.

The Mission Ledger uses a high-contrast bronze title plate and lined aged parchment with dark ink. Its scoped text colors intentionally override the shared cream-modal inheritance so the title, labels, and values remain legible.

- Visual AtomicAssets tiles for miners and equipment, with cooldown overlays and selection rings
- Numbered crew-building stages and mission buttons — not dropdowns
- **One miner, one equipment.** Selecting another equipment replaces the prior selection; selecting it again clears it. The contract enforces the same rule.
- Miner and Equipment galleries use one-row horizontal snap scrolling with no pagination controls; every available asset remains directly reachable and the footer shows only the total count
- Empty Miner or Equipment galleries show a single centred message across the full selection area, without a nested outlined placeholder card
- Live mission summary: miner, health, equipment, mission, reward boost, NFT luck
- Free-play preflight guards disable mining with an actionable status when the rotation isn't initialised or the selected miner doesn't match the current selector; the inventory is filtered to eligible miners with a specific empty state
- Cooling miners render as disabled choices; Send to Mine is independently disabled for a cooling miner or a cooling land

One signed transaction temporarily places/initialises the selected assets, attaches equipment, and starts the secure ORNG mine. Resolution or a guarded bailout always returns surviving miner and equipment to idle in-game inventory while retaining health, durability and cooldown changes.

### Reward preview

`lib/utils/rewards.ts` mirrors the contract's formulas exactly:

```
gross = base_reward_rate × equipment boost × land_bonus × match bonus × mining multiplier
gold  = miner + equipment + land + mining type   ← ADDITIVE percentage points
        floored at 0, capped by config.max_nft_drop_rate, clamped to 1
```

Then the waterfall: platform fee → landlord commission → referral → net.

Equipment "NFT Luck" renders percentage points at two decimals (+2.50%, not a rounded +3%). Miner health preconditions multiply `minerConf.health_cost_per_mine × miningType.health_cost` — the mining type value is a multiplier, not an absolute cost.

**This is a projection for UX only.** Authoritative amounts come from the chain.

### MiningWatcher

A global watcher follows mines launched from any page, waits for ORNG resolution and Hyperion indexing, then reports net/gross reward, mining fee, land commission, referral payment and Gold drop outcome from the on-chain `logmine` receipt. It never calculates or invents the result client-side; if indexing is delayed past the safety window it refreshes balances and says the receipt is still syncing.

The brief oracle interval is labelled **Resolving reward**, not presented as a long-running mine.

---

## 6. Inventory pages

- Active Home land cards use the shared ice-cream visual language: a vanilla/pink/mint shell and header, layered white outline, plum typography/stat overlay, and mint active state. NFT artwork and the orange primary mining action retain their original identity.
- Home land artwork is slightly taller. **Mine Now** is no longer a permanent footer: it appears as a centered artwork overlay on card hover or keyboard focus, while the entire land card remains the interaction target.
- The hover action is a mining command plaque rather than a flat button: an angular beveled gold frame, forge-orange face, pickaxe medallions, pulsing glow, and **Start Expedition** sub-label reinforce the game UI while adding no nested click target.
- Active land artwork remains centered inside its `contain` frame. The horizontal land rail reserves extra top clearance so each card's layered outer outline and hover glow render below the top bar without clipping.

### Miners

Wallet → staked → placed. Cards are image-first with a shared **21rem minimum height** and flex-column shell so footers anchor to the bottom and Miner and Equipment cards line up.

- Identity and cooldown/status overlay the top of the artwork; a translucent blurred cooldown badge sits top-right
- Health overlays the bottom as a thick meter with state gradients, percentage/numeric labels, gloss, segmentation and animated width transitions
- Wallet cards omit the health overlay — health is necessarily maximum there
- Footer is a single equal-width two-column **Heal / Unstake** row
- No mining controls on miner cards — deployment happens from the Home expedition
- **Recovery Chamber** heal UI: decoded artwork, current/result health, restore slider, cost card, full-health completion state. Heal is disabled at `health_max` with a non-interactive Full Health label
- `wdrawminer` supports both initialized idle rows and uninitialized deposits; active-mine guards disable withdrawal

### Equipment

Compact premium collectible cards — cream frame, violet tier banner, layered artwork stage, icon-led Reward Power and NFT Luck badges.

- Reward power overlays the top of the artwork; remaining/max durability with a progress bar overlays the bottom
- Wallet and legacy-deposit cards omit the full-durability overlay — it's only meaningful once mining has reduced it
- Reward boosts normalise to readable percentages, not raw floats
- **Permanent consumable lifecycle:** staking submits the AtomicAssets transfer and `equipstake` atomically. There is no withdrawal path. Destroy removes only the logical row.
- In-Game reads only logical `equipment` rows. Pre-upgrade deposits appear in Stash with a one-time **Finish Activation** control so they're recoverable rather than invisible.

Both carousels use a shared ice-cream-themed scrollbar with Firefox/WebKit support.

### Lands

Same permanent lifecycle as equipment: a wallet transfer and `activateland` go out in **one signed transaction**, and the physical NFT burns immediately. The activation selector shows template image, land name, asset id, loading/fallback state and an explicit burn warning.

---

## 7. Smithy (Forge)

Constrained to the game viewport: on desktop only the left thumbnail rail scrolls vertically while the selected artwork, metadata, costs and Craft action stay fixed. The compact/mobile selector scrolls horizontally.

- Decoded AtomicAssets recipe artwork with image-loading state; the detail preview contains the full artwork rather than cropping it
- The selected craft result joins its template ID to the live `minerconf`, `equipconf`, `landconf`/`landdef`, or `slotconf` row and renders category-specific on-chain mechanics. Miner results show base FT reward, base Gold chance, health, damage, cooldown, healing cost and compatibility; equipment shows reward multiplier, Gold bonus, durability, restrictions and lifecycle; lands show reward/Gold boosts, durability, class and restrictions; slot NFTs show the unlocked slot, availability and permanent-burn rule.
- Smithy rates are formatted by contract semantics (`0.05` Gold chance = `5%`; `1.35` reward boost = `1.35x (+35%)`). Empty compatibility arrays display as **All**, matching contract enforcement. A missing or older mechanics row shows an inline warning but never blocks an otherwise valid craft.
- Crafted NFT mechanics use compact `key : value` rows with separators instead of individual statistic tiles. On desktop the rows span two columns so the complete mechanics and craft controls remain visible without a separate details scrollbar; mobile keeps the natural page scroll.
- The selected recipe image/name remains in the center preview only. The mechanics now begin at the top of the right pane, with recipe costs and the Craft action sharing a compact footer so the action stays visible.
- Smithy intentionally shows only the decision-critical craft summary (reward/drop power, health or durability, cooldown where applicable, and slot burn behavior). Rarity and extended compatibility/lifecycle explanations are omitted so costs and the Craft action remain above the fold; players can inspect full NFT metadata externally.
- The Smithy Craft action pre-checks in-game FT balances, the player Gold counter, and unlocked deposited NFT ingredients. It stays disabled while balances load, when verification fails, or when resources are insufficient, and names missing resources inline. Locked deposits never count as craft inputs; the contract remains the final authority at transaction time.
- **Buy on AtomicHub** opens the selected output template's cheapest listings in a new tab, filtered to the configured collection and WAX testnet/mainnet selected by chain ID.
- The Smithy footer reserves separate fixed rows for costs, resource validation, and actions. Background balance refreshes update the status in place without moving the buttons; the medium-sized **Buy** and **Craft** actions stay aligned at the lower right.
- Recipe identity, availability window, output template and per-rule weighted result probability are displayed separately from NFT mechanics. Recipes with multiple NFT outcomes expose a horizontal result selector so every output can be inspected; closed or not-yet-open recipes have a disabled Craft button. These are intrinsic stats only—the frontend does not invent a final mining reward without a selected miner, land, equipment and mission.
- Long mechanics panels scroll inside the Smithy on short/mobile viewports, while the desktop recipe rail and selected-result panes keep their independent game-frame layout.
- **Cost pills show Gold and FT.** Gold reads from the recipe's `gold_amount` and is validated against the player-scoped `goldbalance` singleton — not the FT balances list. Insufficient Gold blocks crafting with an explicit shortfall message.
- Input confirmation distinguishes FT-only recipes from recipes requiring deposited NFTs
- Deterministic recipes mint in the same transaction; genuinely random recipes go through ORNG and `craftclaim`

---

## 8. Treasury

- **FT deposits** refresh `get_currency_balance` immediately before signing and clamp/abort if the amount exceeds the latest transferable balance, defending against stale liquid balances
- **Gold vault** accepts whole-number amounts and selects exactly that many wallet NFTs matching the on-chain `nftconfig` collection, schema and template IDs. Incoming Gold is separated from ordinary deposits, burned atomically and credited to `goldbalance`. `wdrawgold` debits first, then mints back. Both capped at 20 per transaction.
- Withdrawal fee display polls `ftconfig` every 5s, since the contract re-rolls it hourly between 5–9%
- When testnet WAX stands in for the Silver token, duplicate WAX presentation is suppressed and the transferable `eosio.token::accounts` amount is labelled with the configured FT symbol from `ftconfig`, excluding CPU/NET stake

---

## 9. Slot unlocking

The modal discovers the configured unlock NFT in **both** the player's AtomicAssets wallet and contract deposits. Wallet-held NFTs execute the AtomicAssets transfer plus `unlockslot` atomically; deposited NFTs call `unlockslot` directly. The modal reports where the NFT was found and refreshes both inventories after success.

Every matching NFT renders as a horizontally scrollable image card with asset id and storage location. The player must explicitly select which NFT to burn; clicking the selected card deselects it and disables Unlock until one is chosen again.

---

## 10. Destructive-action confirmations

A reusable yes/no permanent-burn confirmation is wired into every destructive onboarding flow: wallet/deposited land activation, wallet/legacy-deposit equipment binding, and slot-unlock consumption. The warning states explicitly that the NFT is burned on-chain and cannot be withdrawn, sold, transferred or recovered.

Withdrawable miner deposits are deliberately confirmation-free — nothing is destroyed.

---

## 11. Admin console

Admin-only, wallet-gated client-side; every underlying action still enforces `require_auth(_self)` on-chain, so a spoofed frontend cannot bypass authorization.

- Safe controls for maintenance toggle, slot tiers and mining-type defaults
- **Advanced content CRUD** covering every configuration action, encoded against the **live ABI at signing time** — so it adapts automatically to a redeployed ABI. Writes require an explicit browser confirmation.
- Action list includes `recreqaddgld` for recipe Gold pricing

---

## 12. Transaction handling

`useTransaction` centralises post-action receipts. It first walks the broadcast response, including nested inline traces, and renders a self-authorized `warforzlands::notify` payload only when `owner` matches the connected wallet. The `info[]` response is deduplicated and length-capped before it reaches a toast. Existing `logmine`, `logheal`, and `logcraft` payloads provide typed player-facing fallbacks. Hyperion transaction lookup handles wallet/RPC responses that omit inline traces; unrelated contracts, other recipients, and arbitrary action payloads are never printed. If no trusted receipt is available, the UI falls back to execution status, contract action names, block/transaction identity, and the explorer link.

**Failure detection is strict.** Broadcast exceptions, non-executed receipts and Hyperion `executed: false` results are all treated as failures — no success notification or success callback fires for a reverted transaction. Hyperion can transiently report `executed: false` before indexing completes, so the client keeps polling and relies on the authoritative broadcast receipt for rejection.

The global transaction loader covers wallet signing and broadcast only; history lookup and player-state refresh continue without covering the game.

---

## 13. Chain read layer

Keyed name-table reads use a name lower bound with `limit: 1` and explicitly validate the returned account — avoiding the ambiguous identical lower/upper bound while preventing the next lexicographic account being mistaken for the requested one. `getTableRow` performs exactly one RPC request and never follows an EOSIO `next_key` encoded as numeric text.

Absent keyed rows cache `null` after a completed not-found lookup, reserving `undefined` for the true initial state — this is what stops polling loader flashes.

Refetch intervals: templates 60s, player state 15s, pending RNG 3s, free-play state and `ftconfig` 5s.

### Hooks

**Global config** `useConfig` · `useFtConfig` · `useNftConfig` · `useLatestTos` · `useSlotConfig` · `useFreePlayState` · `useFpSelectors` · `useLandMinerMatches`

**Templates** `useMinerTemplates` · `useGearTemplates` · `useLandTemplates` · `useLandDefs` · `useMiningTypes` · `useCraftRecipes` · `useCraftRules` · `useAtomicTemplate`

**Player** `usePlayerAccount` · `useGoldBalance` · `useTosUser` · `useBlockedAccount` · `usePlayerReferrer` · `usePlayerLandSlots` · `usePlayerLands` · `usePlayerLandCooldowns` · `usePlayerMiners` · `usePlayerGear` · `usePlayerMines` · `useMinesFast` · `usePlayerCrafts` · `usePlayerDeposits` · `usePendingRng`

**External** `useWalletBalance` · `useWalletNfts` · `useListedLands` · `useActivityFeed`

---

## 14. Formatting

Token balances, withdrawal fees, RNG probabilities, commissions, land bonuses and compact K/M values retain only meaningful fractional digits — `0 WAX`, `12.5%`, `1.25×` — rather than padding with chain-precision zeroes. Signed transaction quantities still preserve exact token precision.

Locale thousands separators throughout. Timers live-update every second without refetching.

---

## 15. Environment

All chain config is env-driven with on-chain values taking precedence at runtime. See `.env.example`.

| Var | Notes |
|---|---|
| `VITE_CHAIN_ID` | **Defaults to WAX mainnet in `.env.example` — confirm before shipping.** Testnet is `f16b…8a12`. |
| `VITE_RPC_URL` | Reads and signing; user-overridable in-app |
| `VITE_CONTRACT` | Deployed game contract account |
| `VITE_ATOMICASSETS_CONTRACT` | Default `atomicassets` |
| `VITE_SILVER_TOKEN_CONTRACT` / `VITE_SILVER_SYMBOL` | Startup fallback; live values come from `ftconfig` |
| `VITE_COLLECTION_NAME` | AtomicAssets collection |
| `VITE_ATOMIC_API_URL` | Decoded metadata API — use the test endpoint for testnet |
| `VITE_HYPERION_URL` | History endpoint for receipts and the activity feed; blank disables the feed |
| `VITE_BLOCKLIST_ENABLED` | Defaults false. Set true and rebuild **after** deploying an ABI containing the `blocked` table. |
| `VITE_APP_NAME` | Wallet login popup label |

`.env` is gitignored. `dist/` is gitignored — the build output is not committed.

---

## 16. Theme

Medieval ancient-battle: forged-iron surfaces, aged bronze-gold accents, blood crimson for irreversible actions, minted silver for currency. Headings use the engraved **Cinzel** typeface. Palette tokens live in `tailwind.config.ts` and can be re-skinned without touching component class names.

The gameplay shell is a **fixed-height** game frame. Card sizing is tuned so a complete land card fits above desktop navigation without vertical page scrolling; overflow is horizontal and isolated to specific rails.

---

## 17. Known gaps

- **No test suite.** No unit, component or e2e tests exist.
- **Chunk size** — the wharfkit bundle is ~586KB minified, over Vite's 500KB warning. Pre-existing; needs manual chunking or dynamic import if it matters.
- **`VITE_CHAIN_ID` defaults to mainnet** in `.env.example`. A misconfigured deploy would point the client at the wrong chain.
- **Client-side admin gating is UX only** — correct by design, but never treat it as security.
- **NFT drop animation** — the original brief called for a skippable animation/video on a Gold drop, replayable from inventory. Not implemented; drops currently surface through the `logmine` receipt notification.
- **Pages named in the original PRD that don't exist:** Marketplace, Leaderboard, Profile, dedicated Referral page. Referral setting lives in Settings.

---

## 18. Rules for anyone (human or AI) working on this frontend

1. **Reads through hooks, writes through `useTransaction`.** No exceptions.
2. **Never compute a final gameplay outcome client-side.** Preview freely; report only what the chain says.
3. **Mirror the contract's formulas exactly** when writing a preview — if you change one, change both. The Gold formula is additive and capped; the mining-type health cost is a multiplier.
4. **Derive from on-chain config**, using env only as a startup fallback.
5. **Every destructive action needs the burn confirmation modal** before signing.
6. **Preserve the loader discipline** — background revalidation must never blank the game or disable controls.
7. **Keep the fixed-height shell.** New content scrolls inside its own rail; the page body must not grow.
8. **Update typed rows in `lib/types/tables.ts`** whenever a contract table gains a field, or reads silently return `undefined`.
