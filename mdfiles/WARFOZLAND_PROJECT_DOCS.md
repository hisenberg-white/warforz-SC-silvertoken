# Warfozland / Land-Forge-Quest — Complete Project Documentation

> **Purpose of this file:** Provide complete context for any future Claude session working on this codebase. Read this before making any changes. Covers both the frontend (`land-forge-quest`) and backend (`warfozloand-BE_ronin`) in full.

---

## Table of Contents

1. [Project Overview & Goals](#1-project-overview--goals)
2. [Tech Stack](#2-tech-stack)
3. [Architecture & Data Flow](#3-architecture--data-flow)
4. [Backend — Django (`warfozloand-BE_ronin`)](#4-backend--django-warfozloand-be_ronin)
   - [Directory Structure](#directory-structure-backend)
   - [All Django Apps & Models](#all-django-apps--models)
   - [All API Endpoints](#all-api-endpoints)
   - [Game Mechanics (Business Logic)](#game-mechanics-business-logic)
   - [Authentication Flow](#authentication-flow-in-detail)
   - [Battle Simulation](#battle-simulation)
   - [Known Bugs (Backend)](#known-bugs-backend)
5. [Frontend — React (`land-forge-quest`)](#5-frontend--react-land-forge-quest)
   - [Directory Structure](#directory-structure-frontend)
   - [All Components](#all-components)
   - [All Hooks](#all-hooks)
   - [State Management](#state-management)
   - [API Layer](#api-layer-frontend)
   - [Routing](#routing)
   - [Styling System](#styling-system)
   - [Known Stubs / Incomplete Frontend](#known-stubs--incomplete-frontend)
6. [Complete vs Incomplete Features](#6-complete-vs-incomplete-features)
7. [Known Bugs Across Both Projects](#7-known-bugs-across-both-projects)
8. [Environment & Configuration](#8-environment--configuration)
9. [Key File Reference (Quick Lookup)](#9-key-file-reference-quick-lookup)

---

## 1. Project Overview & Goals

**Warfozland** is a blockchain-based, Clash-of-Clans-style NFT strategy game.

- Players own **NFT assets** (lands, miners, raiders, towers) on-chain (Ronin EVM + planned WAX).
- Gameplay state (health, durability, timers, balances) is tracked **off-chain** in a Django database.
- Players mine resources, raid each other's lands, upgrade/craft stronger units.
- An admin panel allows the game operators to control features, configs, and player accounts.

**Business model:**
- Fees on crafting and withdrawals.
- Premium pack sales.
- Gold premium currency (rare, requires real effort to earn).

**Roadmap (per landing page):**
- Phase 1: Mining, Raiding, Tower Defense ← **CURRENT PHASE** (mostly complete)
- Phase 2: Crafting & Packs ← partially implemented
- Phase 3: Marketplace ← not started
- Phase 4: Clans & Alliances ← models exist, no endpoints

---

## 2. Tech Stack

### Backend
| Component | Tech | Version |
|---|---|---|
| Web framework | Django | 5.2.6 |
| REST API | Django REST Framework | 3.16 |
| Auth | SimpleJWT | 5.5.1 |
| WebSockets | Django Channels + Daphne | 4.2.2 |
| Blockchain | web3.py + eth_account | 7.13 / 0.13.7 |
| Database | SQLite (dev) / MySQL or Postgres (prod) | — |
| API docs | drf-spectacular (Swagger + ReDoc) | 0.28 |
| Config | python-decouple | 3.8 |

### Frontend
| Component | Tech | Version |
|---|---|---|
| Framework | React + TypeScript | 18.3.1 / 5.8.3 |
| Build | Vite + SWC | 6.4.3 |
| UI | shadcn-ui (Radix UI) + Tailwind CSS | — / 3.4.17 |
| Animations | Framer Motion | 12.23.22 |
| Server state | TanStack React Query | 5.83.0 |
| Forms | React Hook Form + Zod | 7.61.1 / 3.25.76 |
| Blockchain (Ronin) | ethers.js | 6.15.0 |
| Blockchain (WAX) | @wharfkit/session + plugins | 1.6.1 |
| Routing | React Router | 6.30.1 |
| Toasts | Sonner | 1.7.4 |

---

## 3. Architecture & Data Flow

```
Player Wallet (Ronin / WAX)
        │
        │  1. Sign nonce (EIP-191)
        ▼
 ┌─────────────────┐     JWT tokens     ┌──────────────────────┐
 │   FRONTEND      │◄──────────────────►│    DJANGO BACKEND    │
 │ land-forge-quest│   REST API calls   │ warfozloand-BE_ronin │
 └────────┬────────┘                    └───────────┬──────────┘
          │                                         │
          │ ethers.js / Wharfkit                    │ web3.py
          ▼                                         ▼
  Ronin / WAX Blockchain              Ronin RPC / WAX AtomicAssets API
  (NFT ownership, token balances)     (verify tx, read NFT state)
```

**Core loop:**
1. Player signs nonce with wallet → receives JWT
2. All game actions require JWT + fresh nonce signature
3. Backend verifies signature, updates off-chain state, returns response
4. Frontend polls/refetches via React Query
5. On-chain operations (stake/unstake/withdraw) involve prepare → on-chain tx → confirm pattern

---

## 4. Backend — Django (`warfozloand-BE_ronin`)

### Directory Structure (Backend)

```
warfozloand-BE_ronin/
├── warforzland/              # Project settings
│   ├── settings.py           # All config (JWT, CORS, DB, etc.)
│   ├── urls.py               # Root API v1 router
│   ├── asgi.py               # Daphne + Channels ASGI
│   └── wsgi.py
├── accounts/                 # Users, profiles, nonces, auth
├── land/                     # Land staking & ownership
├── miner/                    # Mining mechanics
├── raider/                   # Raider attack mechanics
├── towers/                   # Tower defense placement
├── battle/                   # Battle simulation & history
├── shop/                     # Crafting & packs
├── chat/                     # WebSocket chat (consumer only)
├── configurations/           # NFT templates, system settings, feature flags
├── logs/                     # Audit trail + blockchain event logging
├── onchain/                  # Multi-chain NFT/token bridge (Ronin + WAX)
│   ├── models.py             # All config/state/request models (19 classes)
│   ├── adapters/             # base.py, ronin.py (web3.py), wax.py (AtomicAssets)
│   ├── services/             # Business logic layer (see below) — 12 modules
│   └── management/commands/  # listen_ronin_events, listen_wax_events, reconcile_onchain_state
├── adminpanel/               # Admin-only REST endpoints
├── permissions.py            # IsPlayer, IsSuperUser permission classes
├── utils/                    # crypto_utils.py, response helpers
├── docs/                     # ONCHAIN_MODULE.md — deep-dive on the on-chain bridge
├── PROJECT_DOCUMENTATION.md  # Older backend-only doc (pre-onchain-rewrite; partly superseded by this file)
├── manage.py
├── db.sqlite3                # Main game database
├── logs.sqlite3              # Separate logs database
└── requirements.txt          # Dependencies (NOTE: encoded UTF-16, may look garbled)
```

> **Companion docs (keep in sync with this file):**
> - `warfozloand-BE_ronin/docs/ONCHAIN_MODULE.md` — authoritative deep-dive on the on-chain module (models, endpoints, invariants, listeners, go-live checklist).
> - `land-forge-quest/docs/WALLETS_AND_LOGIN.md` — frontend wallet linking + login flow.
> - `warfozloand-BE_ronin/PROJECT_DOCUMENTATION.md` — earlier backend-only doc; several of its "known bugs" have since been fixed (see §7).

---

### All Django Apps & Models

#### `accounts` — Users & Auth

**User** (custom user model, keyed on wallet_address)
- `wallet_address` (unique), `username`, `email`, `is_staff`, `is_active`, `is_player`, `date_joined`
- No password for game players; admin staff have passwords

**PlayerProfile** (1:1 with User)
- `nickname`, `avatar_url`
- Balances: `ingame_silver_balance`, `ingame_gold_balance`, `ingame_ron_balance`
- Progress: `trophies`, `current_league`
- Spend totals: `total_spent_silver`, `total_spent_gold`, `total_spent_ron`
- Status: `is_banned`, `ban_reason`
- Referral: `referral_code` (UUID), `referred_by` (FK → User)

**UserActionNonce** — Replay-attack prevention
- `user` (FK), `action_type` (enum: login, stake_miner, claim_miner_rewards, mine, heal_miner, stake_land, claim_land, upgrade_land, unstake_land, destroy_land, deploy_tower, repair_tower, unlock_tower_slot, unstake_tower, heal_raider, recover_raider, raid, start_battle, stake_raider, unstake_raider, craft, exchange_gold, stake_pack, unstake_pack, open_pack, link_wallet, withdraw)
- `nonce` (UUID-based string), `used` (bool), `created_at`

**UserNFTInventory** — Synced on-chain holdings
- `contract_address`, `token_id`, `standard` (ERC721/ERC1155), `balance`, `is_playable`
- `template` (FK → NFTTemplateConfig)

**Blacklist**
- `wallet_address`, `comment`, `created_at`

---

#### `land` — Land Staking & Ownership

**LandConfig** — Template/catalog per rarity
- Identity: `contract_token_id`, `standard`, `name`, `rarity`
- Gameplay: `base_plots`, `max_plots`, `base_tower_slots`, `max_towers`
- Commission: `miner_commission_percentage` (% of miner output to land owner)
- Treasury: `min_silver_treasury` (floor; can't claim below this)
- Tower slot cost: `additional_tower_slot_cost_silver/gold/ron`
- Craft: `craft_cost_silver/gold/ron`, `is_nft_required_to_craft`, `nft_required_to_craft` (FK → NFTTemplateConfig)

**StakedLand** — Active land instance per player
- Identity: `user` (FK), `contract_address`, `token_id`, `land_config` (FK)
- Status: `staked_at`, `is_active`, `is_staked`, `level`
- Slots: `total_plots`, `used_plots`, `total_tower_slots`, `tower_slots_used`
  - Properties: `plots_available`, `tower_slots_available`
- Commission: `miners_commission_percentage`
- Treasury: `total_silver_collected`, `claimable_silver`, `total_gold_collected`
- Claim cooldown: `claim_cooldown_seconds`, `next_claim_time`, `last_claimed_at`
- Raid state: `is_under_raid`, `raid_defense_cooldown_seconds`, `next_raid_available_time`, `last_raid_defended_at`
- Unstake: `unstaked_at`, `unstaked_cooldown_seconds`, `unstake_available_at`
- On-chain: `onchain_chain`, `game_nft` (FK → GameNFTState), `stake_tx_hash`, `unstake_tx_hash`

---

#### `miner` — Mining Mechanics

**MinerConfig** — Template per rarity
- Identity: `contract_token_id`, `standard`, `name`, `rarity`
- Mining: `base_silver_mine_rate` (per hour), `base_gold_percentage` (% chance gold drops), `miner_cd` (cooldown seconds)
- Durability: `max_durability`, `durability_consumption_per_mine`, `durability_repair_silver_cost`, `durability_repair_gold_cost`
- Post-mine cooldown: `cooldown_time_seconds_after_mining`
- Craft: `silver_craft_cost`, `gold_craft_cost`, `ron_craft_cost`, `is_nft_required_to_craft`

**StakedMiner** — Active miner instance
- Identity: `user` (FK), `contract_address`, `token_id`, `miner_config` (FK)
- Status: `staked_at`, `is_staked`, `is_active`, `current_level`
- Mining: `last_mined_land` (FK → StakedLand), `last_mined_plot`, `last_mined_at`
- Pending rewards: `last_balance_silver_mined`, `last_balance_gold_mined`
- Durability: `current_durability`, `max_durability`
- Timers: `next_mining_time`, `next_claim_time`, `last_collected_at`
- Upgrade cost: `upgrade_cost_silver_to_next_level`, `upgrade_cost_gold_to_next_level`, `upgrade_cost_ron_to_next_level`
- Unstake: `unstaked_at`, `unstaked_cooldown_seconds`, `unstake_available_at`
- On-chain: `onchain_chain`, `game_nft` (FK), `stake_tx_hash`, `unstake_tx_hash`

---

#### `raider` — Raider Attack Mechanics

**RaiderConfig** — Template per rarity
- Identity: `contract_token_id`, `standard`, `name`, `rarity`
- Combat: `base_attack_per_second`, `attack_speed`, `attack_type` (Single/Multiple), `base_health`, `max_health`
- Specialty: `specialty_damage_target` (FK → TowerConfig), `specialty_damage_target_percentage` (% bonus vs that tower type)
- Repair: `health_recovery_silver_cost`, `health_recovery_gold_cost`
- Defeat penalty: `defeat_health_loss_percentage` (permanent max_health_left loss per defeat)
- Per-attack cost: `health_consumption_per_attack`
- Cooldowns: `attack_cd`
- Craft: `silver_craft_cost`, `gold_craft_cost`, `ron_craft_cost`, `is_nft_required_to_craft`

**StakedRaider** — Active raider instance
- Identity: `user` (FK), `contract_address`, `token_id`, `raider_config` (FK)
- Status: `staked_at`, `is_staked`, `is_active`, `current_level`
- Health: `current_health`, `initial_health` (health at stake), `max_health_left` (permanent max, degrades on defeat)
- Combat: `last_raided_at`, `next_raiding_time`
- Loot: `last_balance_silver_looted`, `last_balance_gold_looted`
- Burn state: `is_burned`, `burned_at`, `burned_reason`
- Unstake: `unstaked_at`, `unstaked_cooldown_seconds`, `unstake_available_at`
- On-chain: `onchain_chain`, `game_nft` (FK), `stake_tx_hash`, `unstake_tx_hash`
- Method: `can_raid()` — checks is_active, current_health > 0, max_health_left > 0, cooldown passed

---

#### `towers` — Tower Defense

**TowerConfig** — Template per rarity (mirrors RaiderConfig)
- Identity: `contract_token_id`, `standard`, `name`, `rarity`
- Combat: `base_attack_per_second`, `attack_speed`, `attack_type` (Single/Multiple), `base_health`, `max_health`
- Specialty: `specialty_damage_target` (FK → RaiderConfig), `specialty_damage_target_percentage`
- Repair: `health_recovery_silver_cost`, `health_recovery_gold_cost`
- Per-attack cost: `health_consumption_per_attack`
- Cooldowns: `attack_cd`
- Craft: `silver_craft_cost`, `gold_craft_cost`, `ron_craft_cost`, `is_nft_required_to_craft`

**StakedTower** — Active tower instance
- Identity: `user` (FK), `contract_address`, `token_id`, `tower_config` (FK)
- Deployed to: `land` (FK → StakedLand, null = in stash), `placed_land_slot_number`
- Status: `staked_at`, `is_staked`, `is_active`, `current_level`
- Health: `current_health`
- Combat: `last_defended_at`, `next_defending_time`
- Upgrade cost: `upgrade_cost_silver_to_next_level`, etc.
- Unstake: `unstaked_at`, `unstaked_cooldown_seconds`, `unstake_available_at`
- On-chain: `onchain_chain`, `game_nft` (FK), `stake_tx_hash`, `unstake_tx_hash`

---

#### `battle` — Combat Simulation & History

**BattleHistory**
- `attacker` (FK → User), `defender` (FK → User)
- `started_at`, `ended_at`, `result` (WIN/LOSE/DRAW)
- Loot: `silver_looted`, `silver_looted_percentage`
- M2M: `raiders_used` (FK → StakedRaider), `towers_defended` (FK → StakedTower)

**Clans** (modeled, NOT wired)
- `name`, `code`, `description`, `members` (M2M → User), `leader` (FK → User)
- `max_members`, `required_trophies_to_join`
- `clan_badge_url`, `clan_points`, `clan_rank`, `is_active`

**TargetShown** — Anti-spam raid target lock
- `attacker` (FK → User), `land` (FK → StakedLand)
- `shown_at`, `expires_at`
- Method: `is_expired()`

---

#### `shop` — Crafting & Packs

**PackConfig** — Pack template
- Identity: `contract_token_id`, `standard`, `name`, `pack_type` (miner/raider/tower/land), `category` (starter/premium/event/special)
- Supply: `supply`, `max_supply`, `items_count`
- Rarity odds: `rarity_common_percent`, `rarity_uncommon_percent`, `rarity_rare_percent`, `rarity_epic_percent`, `rarity_legendary_percent`
- Craft: `silver_craft_cost`, `gold_craft_cost`, `ron_craft_cost`, `is_nft_required_to_craft`
- Status: `is_active`, `allowed`

**StakedPack** — User's pack instance
- `user` (FK), `contract_address`, `token_id`, `pack_config` (FK)
- `staked_at`, `is_active`, `is_blacklisted`, `blacklisted_reason`
- `opened_at`, `is_opened`, `mint_number`
- On-chain: `onchain_chain`, `game_nft` (FK), `stake_tx_hash`, `unstake_tx_hash`

**CraftedHistory** — Crafting audit log
- `user` (FK), `craft_type` (tower/raider/miner/land)
- `crafted_config_id`, `crafted_item_name`
- Resources: `silver_spent`, `gold_spent`, `ron_spent`
- Base NFTs: `base_nft_used` (FK → NFTTemplateConfig), `number_of_base_nfts_used`, `base_land_used` (FK → StakedLand)
- `crafted_at`, `success`, `notes`, `transaction_hash`, `is_transferred`

**PackOpenedHistory** — Pack opening results
- `user` (FK), `staked_pack` (FK), `opened_at`
- `miners_generated`, `raiders_generated`, `towers_generated`, `lands_generated`
- `details` (JSON — token_ids, rarities)

---

#### `configurations` — System Settings & Metadata

**NFTTemplateConfig** — Canonical NFT catalog
- `contract_address`, `token_id`, `standard`, `category` (Miner/Raider/Tower/Land), `rarity`, `default_img`
- Unique: `(contract_address, token_id)`

**GoldNftTemplateConfig** — NFTs mintable as gold rewards
- `contract_address`, `token_id`, `standard`, `default_img`

**SystemConfig** — Global economy settings
- Fees: `default_silver_withdraw_fee_percentage`, `default_withdraw_ron_fee_amount`, `gold_nft_minting_fee`, `silver_withdraw_fee_ron_amount`
- Exchange: `gold_to_silver_rate`, `is_gold_exchange_enabled`, `min_gold_per_exchange`, `max_gold_per_exchange`

**FeatureFlag** — Admin-controlled toggles
- `key` (unique), `label`, `description`, `enabled`, `updated_at`
- Enforced by `FeatureGateMiddleware` and WebSocket chat consumer

**NotificationMessage** — In-game notifications
- `title`, `details`, `is_urgent`, `visible_from`, `visible_until`
- `send_to_email`, `is_deleted`, `image`, `is_maintenance`

**TokenContractConfig** — Supported tokens (SILVER, GOLD, RON, WAX)
- `contract_address`, `symbol`, `decimals`, `is_active`, `name`, `default_image`

**NFTMetadata** — ERC-721 metadata (for marketplaces)
- `token_id` (unique), `name`, `description`, `image`, `external_url`
- `category`, `rarity`, `uri` (auto), `animation_url`, `background_color`
- `total_supply`, `max_supply`, `level`, `is_burned`, `is_active`

**NFTMetadataAttribute** — ERC-721 trait attributes
- `nft` (FK → NFTMetadata), `trait_type`, `value`

**TimerCounter** — Per-day cooldown counters
- `counter`, `year`, `month`, `day`, `cooldown`, `counter_day`, `status` (A/I)

---

#### `logs` — Audit Trail

**GameLog** (not yet written from gameplay code)
- `timestamp`, `wallet_address`, `action`, `details`, `amount`

**BlockchainEventLog** (scaffold only)
- `wallet_address`, `user_id`, `event_type`, `contract_address`, `token_id`
- `payload` (JSON), `success`, `error_message`, `created_at`
- BUG: `created_at` default calls `timezone.now()` at import time, not as callable

**RequestAuditLog** — Every HTTP request (written by AuditLogMiddleware)
- `created_at`, `method`, `path`, `action`, `status_code`
- `wallet_address`, `user_id`, `ip_address`, `user_agent`, `referer`
- `is_suspicious`, `duration_ms`, `error_message`
- Indexes: `(ip_address, created_at)`, `(wallet_address, created_at)`, `(is_suspicious, created_at)`, `(status_code, created_at)`

---

#### `onchain` — Multi-Chain NFT/Token Bridge

Uses adapter pattern: `BaseChainAdapter` → `RoninAdapter` (web3.py) + `WaxAdapter` (AtomicAssets API).

**Models** (19 classes total in `onchain/models.py`; includes enums `Chain`, `NFTType`, `TokenStandard`, `ContractType`, `ActionType`, `NFTLifecycle`, `InventoryLocation`):
- **ChainConfig** — Per-chain setup (chain_id, public/internal RPC URLs, confirmations needed, enabled actions; internal RPC never exposed)
- **ChainContractConfig** — Every contract/account/token per chain (STAKING, TREASURY, NFT, TOKEN, ATOMICASSETS, CRAFTING). No address hardcoded anywhere
- **ChainFeeConfig** — Per-(chain, action, token) fee config
- **ChainSyncCheckpoint** — Restart-safe listener cursor/block position (used by the event listeners)
- **GameNFTState** — Permanent NFT progress (level, xp, health, durability, lifecycle) — follows NFT through sales; `active_owner` changes but progress never resets
- **OnChainInventory** — Normalized view of "what a wallet holds now"
- **ProcessedChainEvent** — Idempotency via `(chain, tx_hash, log_index | action_ordinal)` uniqueness
- **BlockchainTransaction** — Audit of every confirmed action
- **UserLinkedWallet** — Player's Ronin wallet + WAX account (proof-verified, one wallet per chain)
- **WithdrawalRequest** — Withdrawal lifecycle (pending → processing → completed)
- **CraftingRecipe** — Config: N×source NFT → 1×target NFT
- **CraftingRequest** — Crafting lifecycle state

**Services layer** (`onchain/services/` — the business logic; views are thin wrappers over these):
- `chain_registry.py` — `get_chain_adapter(chain)`, the only chain→adapter map
- `chain_config.py` — `build_public_chain_config()` (frontend-safe config)
- `event_processor.py` — shared idempotency layer used by both API confirms and listeners (claim/record/mark). Listeners *record* events but never mark them processed, so they can't block the confirm path
- `balances.py` — in-game balance `credit`/`debit` with `select_for_update`
- `inventory_sync.py` — `sync_wallet_inventory()` (no dupes, progress preserved, transfers-out flipped to TRANSFERRED)
- `staking.py` — stake/unstake engine + per-type handlers (Miner/Land/Raider/Tower/Pack) + gameplay guards
- `deposits.py` — `confirm_deposit()` (credits chain-verified amount, once)
- `withdrawals.py` — `request_withdrawal()` (balance lock + fee + broadcast/queue + refund-on-fail)
- `crafting.py` — `prepare_craft`/`confirm_craft`/`cancel_craft`
- `reconciliation.py` — `reconcile()` DB-vs-chain custody drift check (`--apply` to fix)
- `listener_runner.py` — generic restart-safe listener loop

**Management commands** (`onchain/management/commands/`):
- `listen_ronin_events` `[--once] [--interval N]` — Ronin event listener
- `listen_wax_events` `[--once] [--interval N]` — WAX event listener
- `reconcile_onchain_state` `[--chain RONIN] [--apply] [--limit N]` — custody reconciliation

> Full detail, invariants, and the go-live checklist live in `warfozloand-BE_ronin/docs/ONCHAIN_MODULE.md`.

---

### All API Endpoints

All endpoints are under `/api/v1/`.

#### Accounts / Auth
| Method | Endpoint | Auth | Purpose |
|---|---|---|---|
| POST | `nonce/` | None | Get signing nonce (creates user if new) |
| POST | `login/` | None | Wallet signature login → JWT |
| POST | `token/refresh/` | Refresh token | Refresh access JWT |
| POST | `create/profile/` | JWT | Create player profile (+ optional referral) |
| GET | `get/profile/` | JWT | Own profile (balances, trophies, league) |
| GET | `get/leaderboards/` | Optional JWT | Trophy leaderboard |
| POST | `update/profile/` | JWT | Add referral code |
| GET | `exchange/gold/rate/` | JWT | Gold→Silver rate + min/max limits |
| POST | `exchange/gold/silver/` | JWT + nonce | Exchange gold for silver (atomic, row-locked) |

#### Land
| Method | Endpoint | Auth | Purpose |
|---|---|---|---|
| GET | `get/lands/all/` | JWT | User's staked lands |
| POST | `get/land/upgrade-cost/` | JWT | Preview upgrade cost |
| POST | `claim/land/commission/` | JWT + nonce | Claim accumulated commission (above treasury floor) |
| POST | `upgrade/land/` | JWT + nonce | Upgrade land (increments level + total_plots) |
| POST | `destroy/land/` | JWT + nonce | Destroy land (halves treasury, force-unstakes towers) |
| POST | `unstake/land/` | JWT + nonce | Schedule land unstaking (cooldown window) |

#### Miner
| Method | Endpoint | Auth | Purpose |
|---|---|---|---|
| GET | `get/all/staked_miners/` | JWT | User's staked miners |
| POST | `mine/` | JWT + nonce | Start mining on random available plot |
| POST | `claim/mine/` | JWT + nonce | Claim pending mining rewards |
| POST | `heal/miner/` | JWT + nonce | Restore durability to max |
| POST | `unstake/miner/` | JWT + nonce | Schedule miner unstaking |

#### Raider
| Method | Endpoint | Auth | Purpose |
|---|---|---|---|
| GET | `get/all/raiders/` | JWT | User's staked raiders |
| POST | `heal/raider/` | JWT + nonce | Restore current_health up to max_health_left |
| POST | `recover/raider/` | JWT + nonce | Restore max_health_left to base (tiered cost) |
| POST | `get/recover-cost/raider/` | JWT | Preview recovery cost |
| POST | `unstake/raider/` | JWT + nonce | Schedule raider unstaking |

#### Towers
| Method | Endpoint | Auth | Purpose |
|---|---|---|---|
| GET | `get/staked/towers/` | JWT | Undeployed towers (land == null) |
| POST | `get/land/towers/` | JWT | Towers deployed on a specific land |
| POST | `deploy/tower/` | JWT + nonce | Place tower on land slot |
| POST | `unlock/tower/slot/` | JWT + nonce | Unlock additional tower slot (cost scales with #) |
| POST | `get/tower/slot/unlock/cost/` | JWT | Preview slot unlock cost |
| POST | `repair/tower/` | JWT + nonce | Restore tower health to max |
| POST | `get/self/tower/` | JWT | Tower combat stats |
| POST | `unstake/tower/` | JWT + nonce | Remove tower from land + schedule unstaking |

#### Battle
| Method | Endpoint | Auth | Purpose |
|---|---|---|---|
| POST | `find/next/target/` | JWT + nonce | Find power-matched raid target |
| POST | `start/battle/` | JWT + nonce | Execute battle simulation |
| POST | `raid/` | JWT + nonce | Launch raid (loot treasury) |

#### Shop

`shop/urls.py` currently exposes **only these three read endpoints:**

| Method | Endpoint | Auth | Purpose |
|---|---|---|---|
| POST | `get/craftable/items/` | JWT | Available crafts by type + rarity |
| GET | `get/craft/requirements/` | JWT | Base cost + NFT requirements for a craft |
| GET | `get/staked/packs/` | JWT | Unopened, non-blacklisted staked packs |

The following exist as views/concepts but are **not routed in `shop/urls.py`** — pack unstake and crafting now flow through the on-chain module:

| Method | Endpoint | Auth | Purpose |
|---|---|---|---|
| POST | `craft/` (`CraftItemAPIView`) | JWT + nonce | ⚠️ View exists but **no URL route** — still not wired |
| POST | `onchain/unstake/*` | JWT + nonce | Pack unstaking now handled via on-chain stake/unstake flow |
| POST | `onchain/craft/prepare/`+`confirm/` | JWT + nonce | Crafting lifecycle (the wired path — see On-chain endpoints) |

#### Configurations
| Method | Endpoint | Auth | Purpose |
|---|---|---|---|
| GET | `notifications/` | Optional JWT | Active in-game notifications |
| GET | `metadata/<token_id>/` | None | ERC-721 metadata JSON (for marketplaces) |
| GET | `features/` | None | Feature flags (all enabled/disabled states) |

#### Logs (Admin-only)
| Method | Endpoint | Auth | Purpose |
|---|---|---|---|
| GET | `logs/audit/` | Admin JWT | Request audit trail |
| GET | `logs/game/` | Admin JWT | Game action logs |

#### Admin Panel (is_staff=True required)
| Method | Endpoint | Purpose |
|---|---|---|
| POST | `admin/login/` | Admin password login |
| GET | `admin/overview/` | KPIs (player count, balances, battles) |
| GET | `admin/players/` | List/filter players (paginated) |
| POST | `admin/players/ban/` | Ban a player |
| POST | `admin/blacklist/` | Add wallet to blacklist |
| GET | `admin/configs/` | List all NFT configs |
| POST | `admin/configs/toggle/` | Enable/disable a config |
| POST | `admin/staked/revoke/` | Revoke staked NFT |
| GET | `admin/logs/` | View audit logs |
| POST | `admin/players/balance/` | Adjust player silver/gold/RON balance |
| POST | `admin/notifications/` | Create/update notifications |
| POST | `admin/features/` | Toggle feature flags |

#### On-chain (Multi-chain bridge)
| Method | Endpoint | Purpose |
|---|---|---|
| GET | `onchain/config/?chain=RONIN` | Frontend-safe chain config |
| POST | `onchain/wallets/link/prepare/` | Nonce for wallet linking |
| POST | `onchain/wallets/link/confirm/` | Confirm link (Ronin: signature; WAX: tx_hash) |
| GET | `onchain/wallets/` | List linked wallets |
| DELETE | `onchain/wallets/<uuid>/` | Unlink wallet |
| POST | `onchain/wallets/login/wax/prepare/` | WAX login nonce |
| POST | `onchain/wallets/login/wax/confirm/` | WAX login verify → JWT |
| POST | `onchain/inventory/sync/` | Sync on-chain NFTs → game (idempotent) |
| GET | `onchain/inventory/` | View synced inventory |
| POST | `onchain/stake/prepare/` | Prepare staking tx |
| POST | `onchain/stake/confirm/` | Confirm staking |
| POST | `onchain/unstake/prepare/` | Prepare unstaking tx |
| POST | `onchain/unstake/confirm/` | Confirm unstaking |
| GET | `onchain/tx-status/<chain>/<tx_hash>/` | Check tx confirmation |
| POST | `onchain/deposit/confirm/` | Credit in-game balance from deposit (idempotent) |
| POST | `onchain/withdraw/` | Withdraw token/NFT |
| POST | `onchain/craft/prepare/` + `confirm/` + `cancel/` | Crafting lifecycle |
| GET | `onchain/craft/requests/` | List crafting requests |
| GET | `onchain/craft/requests/<uuid>/` | Crafting request detail |

#### Docs
| Endpoint | Purpose |
|---|---|
| `schema/` | OpenAPI JSON |
| `swagger/` | Swagger UI |
| `redoc/` | ReDoc UI |

---

### Game Mechanics (Business Logic)

#### Mining Flow (`miner/views.py`)

**MineOnLand** (`POST mine/`)
- Validates: signature OK, miner not on cooldown, durability ≥ `durability_consumption_per_mine`
- Picks random free plot: `get_random_available_land_plot()` in `miner/utils.py` — finds plot not occupied by an unclaimed miner
- Rolls gold: if random ≤ `base_gold_percentage`, sets `last_balance_gold_mined = 1`
- Consumes durability, sets `next_mining_time`, awards +1 trophy

**ClaimMined** (`POST claim/mine/`)
- Validates: cooldown passed, pending rewards > 0
- Commission = `total_mined_silver * land.miners_commission_percentage`
- Credits player with `(total_mined_silver - commission)` silver + gold
- Credits land's `total_silver_collected` with commission amount
- Resets miner pending balances, awards +1 trophy

**HealMiner** (`POST heal/miner/`)
- Cost = `(max_durability - current_durability) * durability_repair_silver_cost`
- Deducts silver, restores durability to max

#### Land Flow (`land/views.py`)

**ClaimLandCommission** (`POST claim/land/commission/`)
- Claimable = `total_silver_collected - min_silver_treasury` (treasury floor enforced)
- Gated by `claim_cooldown_seconds`
- Credits player, resets treasury to floor

**UpgradeLand** (`POST upgrade/land/`)
- Costs from `LandConfig`: `craft_cost_silver/gold/ron`
- Increments `level`, increments `total_plots` by 1

**DestroyLand** (`POST destroy/land/`)
- Guard: all towers must be at full health (prevents destroying defended land)
- Halves treasury (50% penalty)
- Returns remaining claimable silver to player
- Force-unstakes all towers (sets `land=null`, starts unstake cooldown)
- Marks land inactive
- BUG: Writes `user.silver_balance` (non-existent) instead of `user.profile.ingame_silver_balance`

#### Tower Flow (`towers/views.py`)

**DeployTower** (`POST deploy/tower/`)
- Validates: tower not already placed on another land, slot number not occupied
- BUG: Guard condition has `or` precedence issue — may reject valid deployments when slot is non-null
- Links tower to `land` + `placed_land_slot_number`

**UnlockTowerSlot** (`POST unlock/tower/slot/`)
- Cost scales with `tower_slots_used`; capped at `land_config.max_towers`
- Increments `total_tower_slots`, deducts resources

**RepairTower** (`POST repair/tower/`)
- Cost = `(max_health - current_health) * health_recovery_silver_cost`
- Restores health to max

#### Raider Flow (`raider/views.py`)

**HealRaider** (`POST heal/raider/`)
- Cost = `(max_health_left - current_health) * health_recovery_silver_cost`
- Restores `current_health` to `max_health_left` (not to base — permanent max may be degraded)

**RecoverRaider** (`POST recover/raider/`)
- Restores `max_health_left` to `raider_config.base_health`
- Tiered cost based on remaining health:
  - ≤ 20% health: 75% of craft cost
  - 20–50% health: 50% of craft cost
  - 50–100% health: 25% of craft cost

---

### Authentication Flow in Detail

```
1. POST /api/v1/nonce/
   Body: { wallet_address, action_type }
   → Creates User if missing
   → Returns: { nonce: "user_id-uuid4", created_at }

2. Frontend signs nonce (EIP-191):
   message = encode_defunct(nonce_string)
   signature = wallet.signMessage(nonce_string)

3. POST /api/v1/<action>/
   Body: { ...action_params, signature, action_type }
   → Backend: verify_signature(wallet_address, signature, nonce_str)
   → Recovers signer via eth_account.Account.recover_message()
   → Compares to request user's wallet_address
   → If match: mark nonce used, proceed
   → If fail: 400 Bad Request
   
   BUG: verify_signature() raises ValidationError on bad sig instead of returning False
        → Surfaces as 500 instead of 400

4. JWT on login:
   Access token: 20 minutes
   Refresh token: 7 days (rotation + blacklist enabled)
```

---

### Battle Simulation

**Location:** `battle/views.py` + `battle/utils.py`

**FindTargetLandAPIView** (`POST find/next/target/`)
- Computes total raider power = Σ `calculate_raider_power(raider, land)` for each raider
- `calculate_raider_power` = `(base_attack_per_second * attack_speed)` + specialty bonus if tower type matches
- Searches active lands: not self, not under raid, raid cooldown passed, has silver treasury
- Filters: tower power within ±20% of raider power OR no towers
- Excludes: lands shown to attacker in last 1 minute (TargetShown)
- Picks random candidate, records in TargetShown (expires 1 min), returns land details

**StartBattle** (`POST start/battle/`)

Undefended land (no towers):
- Auto-WIN for attacker
- Loot ≤ 90% of `total_silver_collected`
- Trophy shift: +5 attacker, -5 defender
- Sets raid cooldown on land

Defended land — tick-based simulation in `simulate_battle(raiders, towers)`:
```
max 100 ticks:
  each tick:
    1. Each live raider attacks:
       - Single type: picks random live tower
       - Multiple type: splits damage across all towers
       - Specialty bonus: if raider.config.specialty_damage_target == tower.config → +bonus %
       - Tower takes damage; raider consumes health_consumption_per_attack
    2. Each live tower attacks:
       - Same logic (reversed roles)
    3. Remove dead raiders/towers from tick list

Win: all towers dead → raiders win
Lose: all raiders dead → towers win
Draw: both die same tick
```

Post-battle:
- Raiders win: loot ≤ 90% treasury, +5/-5 trophies, set raid cooldown
- Raiders lose: defeated raiders drop to 0 health, permanent `max_health_left` reduced by `defeat_health_loss_percentage`
- Defeated towers drop to 0 health
- Records `BattleHistory`
- BUG: Can remove items from list while iterating — potential IndexError in edge cases

**Power formula:**
- `calculate_raider_power(raider, land)` = `(base_attack_per_second * attack_speed)` + specialty_bonus_if_target_present
- `calculate_tower_power(tower, raiders)` = `(base_attack_per_second * attack_speed)` + specialty_bonus_if_raider_match

---

### Known Bugs (Backend)

> **Status update (verified against code 2026-07-11):** Five of the six bugs previously listed here have since been **fixed**. Only the missing crafting URL route remains open.

| Location | Bug | Status |
|---|---|---|
| `shop/urls.py` | `CraftItemAPIView` still has no URL route (`shop/urls.py` exposes only `get/craftable/items/`, `get/craft/requirements/`, `get/staked/packs/`) | ⚠️ **OPEN** — crafting endpoint still inaccessible |
| `land/views.py` `DestroyLandView` | Previously wrote non-existent `user.silver_balance` | ✅ Fixed — now uses `profile.ingame_silver_balance` |
| `towers/views.py` DeployTower | Previously had `or`-precedence guard issue | ✅ Fixed — guard is now `land is not None or placed_land_slot_number not in (None, 0)` |
| `battle/utils.py` simulate_battle | Previously removed list items while iterating | ✅ Fixed — rebuilds survivor lists via comprehensions; never mutates while iterating / never indexes an empty list |
| `utils/crypto_utils.py` verify_signature | Previously raised `ValidationError` on bad sig | ✅ Fixed — now returns `False` (typed `-> bool`) |
| `logs/models.py` BlockchainEventLog | `created_at` default previously called `timezone.now()` at import time | ✅ Fixed — now `default=timezone.now` (callable) |

---

## 5. Frontend — React (`land-forge-quest`)

### Directory Structure (Frontend)

```
land-forge-quest/src/
├── api/                         # Typed backend API wrappers
│   ├── lands.ts                 # Land fetch, upgrade, claim commission
│   ├── miners.ts                # Miner actions: mine, claim, heal
│   ├── raiders.ts               # Raider actions: heal, recover, raid
│   ├── packs.ts                 # Pack staking/unstaking
│   ├── towers.ts                # Tower fetch, repair, deploy, unstake
│   └── profile.ts               # User profile fetch
├── admin/
│   └── adminApi.ts              # Admin login, feature toggle, player management
├── components/
│   ├── auth/
│   │   ├── AuthGate.tsx         # Login screen & auth guard
│   │   ├── WalletConnectModal.tsx # Ronin/MetaMask/WAX connection UI
│   │   └── RegistrationModal.tsx  # New player signup
│   ├── game/
│   │   ├── GameContext.tsx      # Game state: section, vault, currencies, profile
│   │   ├── GameLayout.tsx       # Main container (header, nav, sections, side dock)
│   │   ├── GameHeader.tsx       # Top banner (logo, currency, profile, leaderboard)
│   │   ├── NavigationTabs.tsx   # Bottom nav (miners, raiders, lands, smithy, vault, packs)
│   │   ├── SectionTabs.tsx      # Left vertical tabs (In-Game, Stash, Defence)
│   │   ├── CurrencyDisplay.tsx  # Gold/Silver/RON balance tiles
│   │   ├── UserProfile.tsx      # User dropdown (profile, settings, wallets)
│   │   ├── NFTCard.tsx          # Generic NFT card (stats, actions, rarity)
│   │   ├── Leaderboard.tsx      # League rankings display
│   │   ├── LeaderboardButton.tsx # Leaderboard trigger
│   │   ├── League.tsx           # League component
│   │   ├── SettingsPanel.tsx    # SFX volume, language, theme
│   │   └── SideDock.tsx        # Clash-style chat + news sidebar (stubbed)
│   ├── sections/
│   │   ├── MinersSection.tsx    # Mine, claim, heal, unstake miners
│   │   ├── RaidersSection.tsx   # Raid, heal, recover, unstake + battle results
│   │   ├── LandsSection.tsx     # Land claim, upgrade, unstake, deploy towers
│   │   ├── SmithySection.tsx    # Craft/upgrade items (land, miners, towers, troops)
│   │   ├── VaultSection.tsx     # Deposit/withdraw assets, exchange Gold↔Silver
│   │   ├── PacksSection.tsx     # Open packs (lazy-loaded)
│   │   └── NewsSection.tsx      # Game announcements (no data source yet)
│   ├── lands/
│   │   └── LandLayoutModal.tsx  # Land plot/tower slot editor
│   ├── miners/
│   │   └── MinerClaimModal.tsx  # Claim rewards confirmation
│   ├── raids/
│   │   ├── RaidTargetModal.tsx  # Select raid target
│   │   └── BattleResultModal.tsx # Battle outcome display
│   ├── exchange/
│   │   └── ExchangeModal.tsx    # Gold to Silver exchange UI
│   ├── onchain/
│   │   └── WalletManagerModal.tsx # Linked wallets + inventory sync (WAX/Ronin)
│   ├── vault/
│   │   └── VaultModal.tsx       # The Vault presented as a game-themed modal (wraps <VaultSection bare/>)
│   ├── landing/
│   │   └── Reveal.tsx           # Scroll-reveal animation
│   ├── UiSounds.tsx             # Root-mounted; plays a click sound on every button press (capture phase)
│   ├── PointerTorch.tsx         # Cursor-following torch/glow effect
│   └── ui/                      # 50+ shadcn-ui components (button, card, dialog, etc.)
├── hooks/
│   ├── useAuth.ts               # JWT, login/register, WAX login, profile
│   ├── useWallet.ts             # Ronin/MetaMask connect, sign, chain switching
│   ├── useGameActions.ts        # ALL 40+ game actions
│   ├── useOnchain.ts            # Wallet linking, inventory sync, stake/unstake, withdraw
│   ├── useFeatures.tsx          # Feature flags (polls every 8s)
│   ├── useLoading.tsx           # Global loading state (patches window.fetch)
│   ├── useChat.ts               # Chat stub (not functional)
│   ├── use-mobile.tsx           # Mobile breakpoint detection
│   └── use-toast.ts             # Sonner toast wrapper
├── lib/
│   ├── onchain/
│   │   ├── api.ts               # Typed /onchain/* endpoint wrappers
│   │   ├── client.ts            # Authenticated fetch (auto-refresh on 401)
│   │   └── wax.ts               # Wharfkit SessionKit (Anchor, Cloud Wallet)
│   ├── sound.ts                 # Web Audio API click synthesis
│   └── utils.ts                 # cn() = clsx + twMerge
├── pages/
│   ├── Index.tsx                # Game page (GameContext + sections)
│   ├── Landing.tsx              # Marketing landing page
│   ├── AdminDashboard.tsx       # Admin console
│   └── NotFound.tsx             # 404
├── types/
│   └── api.ts                   # TypeScript interfaces (StakedMinerApi, RaiderApi, LandApi, etc.)
├── config/
│   └── game.json                # API_BASE_URL, chain config, sections, currencies
├── App.tsx                      # Root providers (QueryClient, Router, TooltipProvider)
├── main.tsx                     # React root render + PointerTorch
└── index.css                    # Tailwind + custom Clash-of-Clans theme CSS
```

---

### All Components

#### Auth Components
| Component | File | Purpose |
|---|---|---|
| AuthGate | `components/auth/AuthGate.tsx` | Login screen, guards game access, orchestrates modals |
| WalletConnectModal | `components/auth/WalletConnectModal.tsx` | Wallet picker (Ronin, MetaMask, WAX Anchor, WAX Cloud) |
| RegistrationModal | `components/auth/RegistrationModal.tsx` | New player signup (username + optional referral) |

#### Game Shell Components
| Component | File | Purpose |
|---|---|---|
| GameLayout | `components/game/GameLayout.tsx` | Outer container: header + section area + nav + side dock |
| GameHeader | `components/game/GameHeader.tsx` | Top bar: logo, currency display, profile dropdown, leaderboard |
| GameContext | `components/game/GameContext.tsx` | Context provider: activeSection, vault modal, currencies, profile |
| NavigationTabs | `components/game/NavigationTabs.tsx` | Bottom nav: Miners, Raiders, Lands, Smithy, Vault, Packs |
| SectionTabs | `components/game/SectionTabs.tsx` | Left vertical tabs: In-Game, Stash, Defence |
| CurrencyDisplay | `components/game/CurrencyDisplay.tsx` | Gold/Silver/RON balance tiles in header |
| UserProfile | `components/game/UserProfile.tsx` | Dropdown: profile info, settings, linked wallets |
| NFTCard | `components/game/NFTCard.tsx` | Generic NFT card (stats, action buttons, rarity colors, selection) |
| Leaderboard | `components/game/Leaderboard.tsx` | Trophy leaderboard (league-based) |
| SettingsPanel | `components/game/SettingsPanel.tsx` | SFX volume, language, dark/light theme |
| SideDock | `components/game/SideDock.tsx` | Clash-style sidebar (chat stub + news stub) |

#### Section Components (Full-page views)
| Component | File | Purpose |
|---|---|---|
| MinersSection | `components/sections/MinersSection.tsx` | List miners; mine, claim, heal, unstake actions |
| RaidersSection | `components/sections/RaidersSection.tsx` | List raiders; heal, recover, raid, unstake + battle results |
| LandsSection | `components/sections/LandsSection.tsx` | List lands; claim commission, upgrade, deploy towers, unstake |
| SmithySection | `components/sections/SmithySection.tsx` | Craft UI: select type + rarity, see cost/requirements, execute |
| VaultSection | `components/sections/VaultSection.tsx` | Deposit/withdraw assets, Gold↔Silver exchange |
| PacksSection | `components/sections/PacksSection.tsx` | List staked packs, unstake (lazy-loaded) |
| NewsSection | `components/sections/NewsSection.tsx` | Announcements (no data source yet) |

#### Modal Components
| Component | File | Purpose |
|---|---|---|
| LandLayoutModal | `components/lands/LandLayoutModal.tsx` | Visual land plot/tower slot editor |
| MinerClaimModal | `components/miners/MinerClaimModal.tsx` | Claim rewards confirmation dialog |
| RaidTargetModal | `components/raids/RaidTargetModal.tsx` | Find and select raid target |
| BattleResultModal | `components/raids/BattleResultModal.tsx` | Show battle outcome (win/loss, loot) |
| ExchangeModal | `components/exchange/ExchangeModal.tsx` | Gold→Silver exchange UI |
| WalletManagerModal | `components/onchain/WalletManagerModal.tsx` | Linked wallets list + inventory sync |

---

### All Hooks

| Hook | File | What it does |
|---|---|---|
| `useAuth` | `hooks/useAuth.ts` | JWT management, login (Ronin/WAX), register, logout, profile fetch, auto-refresh on 401 |
| `useWallet` | `hooks/useWallet.ts` | Connect Ronin/MetaMask, sign messages, chain switching, error classification |
| `useGameActions` | `hooks/useGameActions.ts` | ALL 40+ game actions: miners, raiders, lands, towers, crafting, exchange, on-chain. Single source of truth for all gameplay mutations |
| `useOnchain` | `hooks/useOnchain.ts` | Wallet linking, inventory sync, stake/unstake NFTs, withdraw to wallet |
| `useFeatures` | `hooks/useFeatures.tsx` | Polls `/features/` every 8s; exposes feature flag map; fail-open (all enabled if error) |
| `useLoading` | `hooks/useLoading.tsx` | Counter-based global loading state; patches `window.fetch` to auto-trigger; skips background endpoints |
| `useChat` | `hooks/useChat.ts` | Stub — exists but not implemented |
| `use-mobile` | `hooks/use-mobile.tsx` | Mobile breakpoint detection |
| `use-toast` | `hooks/use-toast.ts` | Sonner toast wrapper |

---

### State Management

**No Zustand or Redux.** All state is React Context + localStorage.

| Provider | What it stores |
|---|---|
| `QueryClientProvider` | TanStack React Query server cache |
| `AuthProvider` | JWT tokens, user profile, login/logout state |
| `LoadingProvider` | Global loading counter (overlapping requests tracked) |
| `FeatureProvider` | Feature flag map (polled every 8s) |
| `GameProvider` | activeSection, vault modal open/close, currency amounts |

**Persistence:**
- JWT tokens: localStorage
- Profile: AuthContext (re-fetched on page load)
- Section state: React state (resets on refresh)

---

### API Layer (Frontend)

**Base client:** `lib/onchain/client.ts`
- Authenticated fetch with JWT from localStorage
- Auto-refresh on 401 → re-tries request
- Redirects to `/` if refresh also fails

**Game API files** (`api/*.ts`):
- `lands.ts` — fetch lands, upgrade, claim commission
- `miners.ts` — mine, claim, heal, fetch miners
- `raiders.ts` — heal, recover, fetch raiders
- `towers.ts` — deploy, repair, unstake, fetch towers
- `packs.ts` — fetch packs, unstake pack
- `profile.ts` — fetch user profile

**On-chain API** (`lib/onchain/api.ts`):
- Typed wrappers for: `config`, `wallets`, `inventory`, `stake/unstake`, `craft`, `withdraw`

**Game actions all flow through `useGameActions.ts`** — 40+ action functions, all using the base client with nonce signature pattern.

---

### Routing

```
/           → Landing page (marketing, no auth)
/play       → Game page (requires auth via AuthGate)
/admin      → Admin console (requires admin token)
*           → 404 NotFound
```

In-game section navigation is via `GameContext.activeSection` + `NavigationTabs` (client-side, no URL change).

---

### Styling System

**Theme:** Dark wood background with gold accents (Clash of Clans style)

**Custom CSS classes in `index.css`:**
| Class | Purpose |
|---|---|
| `.coc-panel` | Wood texture panel with gold border |
| `.coc-tile` | Small wood tile |
| `.coc-ribbon` | Gold ribbon banner |
| `.coc-navbar` | Bottom navigation bar |
| `.coc-navtab` | Navigation tab item |
| `.coc-btn` | Themed button |
| `.game-gold-light`, `.game-gold-deep` | Gold color tokens |
| `.game-wood-dark`, `.game-wood-light` | Wood background tokens |
| `.rarity-*` | Per-rarity HSL color variables |
| `.text-stroke-dark` | Outlined text effect |

**Color tokens:**
- Background: `hsl(28, 50%, 16%)` (dark wood)
- Gold: `hsl(44, 84%, 52%)`
- Purple/blue overlays for raid/battle sections

---

### Known Stubs / Incomplete Frontend

| Feature | Status | Detail |
|---|---|---|
| Ronin staking | Stub | `sendRoninStub()` throws clear error; awaits contract ABI + address |
| Crafting on-chain (Ronin) | Partial | Backend endpoints wired; SmithySection doesn't call craftPrepare/craftConfirm |
| Chat system | Stub | `useChat` hook + SideDock UI exist; no message history or WebSocket connection |
| News section | Stub | Component exists; no data source |
| Marketplace | Not started | Not implemented |
| Clans & Alliances | Not started | In roadmap, not in game |
| Raid target selection UI | Partial | `findNextTarget` endpoint wired; no visual list to browse targets |
| Tower defense stat display | Partial | Stats fetched but not fully visualized in UI |

---

## 6. Complete vs Incomplete Features

### Complete & Functional

| Feature | Frontend | Backend |
|---|---|---|
| Wallet login (Ronin, MetaMask) | ✓ | ✓ |
| Wallet login (WAX Anchor, Cloud Wallet) | ✓ | ✓ |
| Player registration + profile | ✓ | ✓ |
| Mining (start, claim, heal, unstake) | ✓ | ✓ |
| Raider system (heal, recover, raid, battle) | ✓ | ✓ |
| Land management (claim commission, upgrade, unstake) | ✓ | ✓ |
| Tower system (deploy, repair, unstake) | ✓ | ✓ |
| Crafting UI (all types) | ✓ | Partial |
| Vault (deposit/withdraw UI, Gold↔Silver exchange) | ✓ | Partial |
| Feature flags (admin control) | ✓ | ✓ |
| Admin console (overview, features, players, logs, blacklist) | ✓ | ✓ |
| Trophy system + leaderboard | ✓ | ✓ |
| Referral system | ✓ | ✓ |
| Request audit logging | N/A | ✓ |
| Battle simulation (tick-based) | ✓ | ✓ |

### Incomplete / Scaffolded

| Feature | Frontend | Backend | Blocker |
|---|---|---|---|
| NFT staking entry point | Stub | Backend wired via `onchain/services/staking.py` (needs contract ABIs/config rows to go live) | Ronin contract ABI + address; frontend `sendRoninStub()` still throws |
| In-app crafting (`shop`) | UI exists | `CraftItemAPIView` has no URL route | URL missing in `shop/urls.py` (on-chain crafting path IS wired — see `onchain/craft/*`) |
| Pack opening RNG | UI exists | Logic not coded | Need to implement RNG from PackConfig odds |
| Clans system | Not in game | Models only | No views/URLs |
| Withdrawals/deposits | UI exists | Scaffolded | On-chain event listeners pending |
| Game action logging | N/A | Models exist | Not written from gameplay views |
| Chat WebSocket | Stub | Consumer coded | Not connected |
| Ronin staking contracts | Stub | Adapters exist | Contract ABI/address needed |

---

## 7. Known Bugs Across Both Projects

### Backend Bugs

**Open (still present as of 2026-07-11):**

1. **`shop/urls.py` — CraftItemAPIView:** View exists but has no URL route. In-app (non-onchain) crafting is not reachable. Crafting via the on-chain module (`onchain/craft/prepare|confirm`) IS wired.

**Fixed since the earlier docs were written** (verified against current code — retained here because the older `PROJECT_DOCUMENTATION.md` and prior versions of this file still list them as open):

2. ~~`land/views.py` DestroyLand writes non-existent `user.silver_balance`~~ → **Fixed**: uses `profile.ingame_silver_balance`.
3. ~~`towers/views.py` DeployTower `or`-precedence guard~~ → **Fixed**: guard is now `staked_tower.land is not None or staked_tower.placed_land_slot_number not in (None, 0)` with a clarifying comment.
4. ~~`battle/utils.py` simulate_battle mutates a list while iterating~~ → **Fixed**: rebuilds survivor lists with comprehensions (`[d for d in defenders if d.current_health > 0]`); no in-place mutation, no empty-list indexing.
5. ~~`utils/crypto_utils.py` verify_signature raises on bad sig~~ → **Fixed**: returns `False` (typed `-> bool`).
6. ~~`logs/models.py` BlockchainEventLog `created_at` calls `timezone.now()` at import~~ → **Fixed**: `default=timezone.now` (passes the callable).

### Frontend Gaps

7. **Ronin staking:** `sendRoninStub()` intentionally throws — feature is intentionally blocked pending contract address.

8. **Crafting on-chain:** `SmithySection.tsx` does not call `craftPrepare`/`craftConfirm` from `lib/onchain/api.ts`. The UI flow is incomplete.

9. **Raid target UI:** `findNextTarget` returns a target but there is no UI to show a list of browsable targets before attacking.

---

## 8. Environment & Configuration

### Backend `.env` Keys

```env
SECRET_KEY=<django secret>
JWT_SECRET_KEY=<jwt signing key>
DEBUG=True                              # MUST be False in production
ALLOWED_HOSTS=localhost,127.0.0.1      # MUST be restricted in production
CORS_ALLOWED_ORIGINS=http://localhost:5173
RONIN_RPC_URL=<ronin rpc endpoint>
RONIN_PUBLIC_RPC_URL=<public rpc>
TREASURY_SIGNER_PRIVATE_KEY=<secret>   # For withdrawal signing — keep secret!
FRONTEND_DOMAIN=<frontend url>
```

### Frontend Config

`src/config/game.json` — single source of truth for:
- `API_BASE_URL` — backend API root
- `CHAIN` — target blockchain (RONIN/WAX)
- `sections` — which game sections exist
- `currencies` — currency names and icons

### Database Routing

- `default` → `db.sqlite3` (all gameplay tables)
- `logs` → `logs.sqlite3` (audit/log tables)
- Router: `logs/utils/logs.py` — `LogsRouter`
- Production: Uncomment MySQL/Postgres config in `warforzland/settings.py`

### JWT Settings
- Access token: **20 minutes**
- Refresh token: **7 days**
- Rotation enabled, blacklist enabled

---

## 9. Key File Reference (Quick Lookup)

When making changes, start with the files in this table.

### Backend Key Files

| File | What it does |
|---|---|
| `warforzland/settings.py` | All Django settings |
| `warforzland/urls.py` | Root API v1 URL router |
| `permissions.py` | `IsPlayer`, `IsSuperUser` permission classes |
| `accounts/models.py` | User, PlayerProfile, UserActionNonce, UserNFTInventory |
| `accounts/views.py` | Wallet login, profile, leaderboard, gold exchange |
| `land/models.py` | LandConfig, StakedLand |
| `land/views.py` | ClaimLandCommission, UpgradeLand, DestroyLand |
| `miner/models.py` | MinerConfig, StakedMiner |
| `miner/views.py` | MineOnLand, ClaimMined, HealMiner |
| `miner/utils.py` | `get_random_available_land_plot()` |
| `raider/models.py` | RaiderConfig, StakedRaider |
| `raider/views.py` | HealRaider, RecoverBaseHealthRaider |
| `towers/models.py` | TowerConfig, StakedTower |
| `towers/views.py` | DeployTower, UnlockTowerSlot, RepairTower |
| `battle/models.py` | BattleHistory, Clans, TargetShown |
| `battle/views.py` | FindTargetLandAPIView, StartBattle |
| `battle/utils.py` | `calculate_raider_power`, `calculate_tower_power`, `simulate_battle` |
| `shop/models.py` | PackConfig, StakedPack, CraftedHistory, PackOpenedHistory |
| `shop/views.py` | CraftItemAPIView (NO URL), GetAvailableCraftableItemsAPI |
| `configurations/models.py` | NFTTemplateConfig, SystemConfig, FeatureFlag, NotificationMessage, NFTMetadata |
| `configurations/views.py` | NotificationListAPIView, NFTMetadataView, FeatureFlagsAPIView |
| `logs/models.py` | GameLog, BlockchainEventLog, RequestAuditLog |
| `logs/middleware.py` | AuditLogMiddleware (every HTTP request) |
| `onchain/models.py` | ChainConfig, GameNFTState, UserLinkedWallet, OnChainInventory, WithdrawalRequest |
| `onchain/views.py` | Wallet linking, inventory sync, stake/unstake, deposit, crafting |
| `onchain/adapters/` | BaseChainAdapter, RoninAdapter, WaxAdapter |
| `adminpanel/views.py` | Admin CRUD (ban, blacklist, balance, configs, logs, notifications) |
| `utils/crypto_utils.py` | `verify_signature()` — EIP-191 wallet signature verification |

### Frontend Key Files

| File | What it does |
|---|---|
| `src/config/game.json` | API_BASE_URL, chain, sections, currencies |
| `src/App.tsx` | Root providers (QueryClient, Router, Auth, Loading, Features) |
| `src/hooks/useAuth.ts` | Login (Ronin/WAX), register, JWT refresh, profile |
| `src/hooks/useWallet.ts` | Ronin/MetaMask connect, sign messages, chain switching |
| `src/hooks/useGameActions.ts` | ALL 40+ game actions — miners, raiders, lands, towers, crafting, exchange |
| `src/hooks/useOnchain.ts` | Wallet linking, inventory sync, stake/unstake, withdraw |
| `src/hooks/useFeatures.tsx` | Feature flags — polls every 8s, fail-open |
| `src/components/game/GameContext.tsx` | activeSection, vault modal, currencies |
| `src/components/game/GameLayout.tsx` | Outer game shell: header + sections + nav |
| `src/components/auth/AuthGate.tsx` | Login screen + auth guard |
| `src/components/sections/MinersSection.tsx` | Miners UI + actions |
| `src/components/sections/RaidersSection.tsx` | Raiders UI + actions + battle results |
| `src/components/sections/LandsSection.tsx` | Lands UI + actions + tower deployment |
| `src/components/sections/SmithySection.tsx` | Crafting UI |
| `src/components/sections/VaultSection.tsx` | Vault + exchange UI |
| `src/components/game/NFTCard.tsx` | Generic NFT card used across all sections |
| `src/lib/onchain/api.ts` | Typed wrappers for /onchain/* endpoints |
| `src/lib/onchain/client.ts` | Authenticated fetch + auto JWT refresh |
| `src/lib/onchain/wax.ts` | Wharfkit SessionKit (Anchor + Cloud Wallet) |
| `src/types/api.ts` | TypeScript interfaces for all API response types |
| `src/pages/AdminDashboard.tsx` | Admin console (features, players, logs, blacklist) |
| `src/index.css` | Custom Clash-of-Clans game theme CSS |

---

*Last updated: 2026-07-11. Re-verified against current code: added the `onchain/services/` + `management/commands/` layer, `ChainSyncCheckpoint` model, companion doc references, and the `VaultModal`/`UiSounds`/`PointerTorch` frontend components. **Corrected the bug status — 5 of the 6 previously-listed backend bugs are now fixed; only the missing crafting URL route in `shop/urls.py` remains open.** Original full read: 2026-06-27.*
