# Mining Game — Smart Contract Build Plan & Agent Prompts

Same three-part shape as the frontend plan:

1. **Build plan** — phased execution order.
2. **Master brief** — always-on prompt with the full contract spec.
3. **Per-phase prompts** — what to paste when kicking off each phase.

Contract bugs after deployment can be permanent — funds locked, NFTs orphaned. Every phase MUST pass its test suite before the next begins. No exceptions.

---

## Part 1 — Build Plan

Ten phases. Strict order. Each phase deploys to **testnet** and runs an integration test script before the next begins.

| # | Phase | Deliverable | Depends on |
|---|---|---|---|
| 0 | **Project skeleton** | eosio.cdt project, CMake, folder structure, empty contract that compiles + deploys to testnet | — |
| 1 | **Types & tables** | All C++ structs + `multi_index` table declarations, no actions | 0 |
| 2 | **Config & TOS** | `configset/clear`, `maintset`, `tosset/del`, `tosaccept` + maintenance guard helper | 1 |
| 3 | **Templates (admin CRUD)** | `minerset/del`, `gearset/del`, `landset/del`, `landdset/ddel`, `plotset/del` | 2 |
| 4 | **Deposits (custody in)** | `on_notify` handlers for AtomicAssets NFT transfers and Silver token transfers; `deposits` + balance credit | 3 |
| 5 | **Setup actions** | `setreferrer`, `buylandslot`, `activateland`, `removeland` (with burn), `mineradd/rem`, `gearadd/rem`, `listland/unlistland` | 4 |
| 6 | **RNG plumbing** | `orng.wax` request wrapper + `receiverand` callback with type dispatcher (stubs only) | 5 |
| 7 | **Core mining** | `mine` (own-land only) + `receiverand` mine resolver + reward waterfall + `heal` + `logmine`/`logheal` + durability/gear burn | 6 |
| 8 | **Cross-player mining** | Extend `mine` for `land_owner != miner_owner`, occupancy record, deployed-lock, commission split | 7 |
| 9 | **Crafting + free-play + withdrawals** | Crafting admin CRUD, `craft`/`craftclaim`, free-play rotation, `wdrawsilver`/`wdrawminer` | 8 |

**Golden rules the agent must follow every phase:**

1. **Test first, always.** Every phase MUST include a `tests/` script (bash + cleos, or JS + eosjs) that exercises every new action's happy path AND every failure path listed in the phase prompt. Phase is not complete until tests pass on testnet.
2. **Never invent an action name, table name, or field.** Everything must match the master brief exactly. If something is needed but not in the brief, STOP and ask.
3. **Every player action starts with three guard calls:** `check_not_maintenance()`, `check_tos_accepted(owner)`, `require_auth(owner)` (except where auth differs — receiverand is `require_auth(orng.wax)`).
4. **All arithmetic uses `int128_t` or `checked_add/sub/mul`.** No raw `uint64_t` math on token amounts or reward calculations. Overflow is a critical bug.
5. **`asset` operations use eosio's built-in checked math** (`+`, `-`, `*` on asset already checks). Never bypass.
6. **RAM payer discipline:** the account whose scope the row lives in pays. Contract-scoped rows use `_self` as payer only for admin-authored data. Never make the contract pay RAM for user-scoped tables.
7. **No `eosio::print` in production paths** — only in debug builds.
8. **Every destructive action** (`removeland`, `gearrem` on used gear, `wdrawminer`, `wdrawsilver`) MUST verify the item is not currently in-use (deployed / cooling down / in a pending RNG association).
9. **Every phase produces `PHASE-N-REPORT.md`** listing: actions added, tables touched, tests written + passing, testnet contract account used, and any assumption made.
10. **No mainnet deploy** until every phase passes and a security review is completed. That's a separate step, not part of this plan.

---

## Part 2 — Master Brief

Paste this at the top of every phase prompt.

```
=========================
MASTER BRIEF — MINING GAME SMART CONTRACT
=========================

## 1. What you are building

An eosio.cdt v1.7+ smart contract for the WAX blockchain that runs a mining game. Players deposit NFTs (miners, gear, lands) and Silver tokens into the contract, place miners on plots on activated lands, and mine Silver rewards (with a rare chance of Gold NFT drops). Randomness comes from the WAX RNG oracle. Uses AtomicAssets as the NFT standard.

Contract architecture is a re-skin of the audited `bcbrawlers` contract with the same core mechanics — same custody model, same async-RNG pattern, same crafting engine — but re-themed as a mining game, plus these additions: multiple lands per player via land slots, land NFTs as consumable assets, cross-player mining with commission, and a single-level referral program.

Language: C++17. Toolchain: eosio.cdt. Target chain: WAX (EOSIO-compatible).

## 2. Core concept

Hierarchy: **player → land slots → activated land NFT → plots → miner NFT (+ optional gear NFT).**

- **Miner** — NFT worker. Reusable. Has health + cooldown. Freely deposited/withdrawn.
- **Gear** — NFT tool. Consumable. Account-bound on first use. Wears down; burns at zero uses.
- **Land NFT** — NFT arena. Consumable. Account-bound on activation. Durability decrements per mine; burns at zero. Can be listed publicly for cross-player mining (except free-play — see below).
- **Free-play land** — a specific land template. Max 1 per account. Never burns. Miner-rarity RNG-gated on a timer. CANNOT be publicly listed.
- **Land slot** — a per-player container that holds one activated land. 1 unlocked at registration. More bought with Silver/Gold.
- **Plot** — a mining position on a land, holds one miner.
- **Silver** — main fungible token (external `eosio.token`-style contract). Withdrawable, has fee.
- **Gold** — rare NFT drop. Kept as collectible.

## 3. Currencies & reward waterfall

Every `mine` produces gross Silver:
```
gross = miner.reward_rate × gear_mining_capacity_multiplier × land_bonus
```
Split OUT OF gross (zero-sum, no minting on top):
1. Platform fee → `config.fee_account` (using `config.fee` %)
2. If `land_owner != miner_owner`: landlord commission % → land_owner
3. Referral cut % of miner_owner's remaining share → their referrer (if any)
4. Remainder → miner_owner (credited to `accounts.balances`)
5. Rare Gold NFT drop (chance from `miner_conf.gold_rate`) → miner_owner (minted via AtomicAssets `mintasset` inline)
6. Decrement land durability (land_owner's land) — burn if zero
7. Decrement gear uses (miner_owner's gear if any) — burn if zero
8. Decrement miner health (refillable by heal)

Referral is SINGLE-LEVEL only. Self-referral and cycles rejected.

## 4. Randomness (async)

`mine` and `craft` request randomness from `orng.wax`. The contract:
1. Generates a unique `assoc_id`, stores it in `rngassocs` with `assoc_type` = "mine" | "craft", `owner`, `request_time`.
2. Sends an inline `orng.wax::requestrand(assoc_id, signing_value, _self)` action.
3. When `orng.wax` calls back into `receiverand(assoc_id, random_value)`, the contract dispatches by `assoc_type` and finalizes the pending mine/craft.
4. The `mine` or `craft` action itself does NOT credit rewards synchronously — only `receiverand` does.

Signing value: use `assoc_id ^ current_time_point().sec_since_epoch()` or similar salt. Never predictable.

## 5. Full table list

Field names, types, and scopes are exact. Do not rename or reorder.

### Contract-scoped (scope = `_self`)

- `config` (singleton, key=0)
  - `bool maintenance_mode`, `name collection_name` (AtomicAssets collection accepted), `int32_t gold_template_id`, `name silver_token_contract`, `symbol silver_symbol`, `name fee_account`, `double fee` (platform fee %), `double referral_rate` (%), `uint64_t next_assoc_id`, `uint64_t fee_updated`
- `tosconfig` (key=`version`): `uint64_t version`, `string tos`
- `tosuser` (key=`account`): `name account`, `uint64_t version`
- `minerconf` (key=`template_id`): `int32_t template_id`, `uint32_t rarity`, `uint32_t health_max`, `uint32_t health_consumed`, `asset health_cost`, `double reward_rate`, `double gold_rate`, `uint32_t cooldown`
- `gearconf` (key=`template_id`): `int32_t template_id`, `uint32_t uses`, `double capacity_boost`, `uint32_t cooldown`
- `landconf` (key=`template_id`): `int32_t template_id`, `uint32_t durability`, `double land_bonus`, `bool is_freeplay`
- `landdef` (key=`template_id`): `int32_t template_id`, `string land_name`, `string rarity`, `string img`
- `plotdef` (key=`plot_id`): `uint64_t plot_id` — plots are indexed per land at runtime; may or may not need this table depending on final design; CONFIRM before implementing
- `landslotcost` (key=`slot_index`): `uint32_t slot_index`, `asset cost_silver`, `asset cost_gold` (cost to unlock the Nth slot)
- Crafting: `craftrecipes` (key=recipe_id, sub-scoped by category), `craftrules` (key=rule_id), `craftcounts` (key=template_id)
- `rngassocs` (key=`assoc_id`): `uint64_t assoc_id`, `name assoc_type`, `name owner`, `uint64_t context_id` (mine_id / craft_id), `time_point_sec request_time`
- `referrals` (key=`referee`): `name referee`, `name referrer`, `time_point_sec set_at`
- `freeplaystate` (singleton, key=0): `uint32_t current_allowed_rarity`, `time_point_sec window_ends_at`, `uint64_t rotation_assoc_id`

### Player-scoped (scope = owner)

- `accounts` (singleton, key=0): `name account`, `vector<asset> balances`, `uint32_t unlocked_land_slots`, `time_point_sec created_at`
- `landslots` (key=`slot_id`): `uint32_t slot_id`, `uint64_t land_asset_id` (0 = empty)
- `lands` (key=`asset_id`): `uint64_t asset_id`, `int32_t template_id`, `uint32_t slot_id`, `uint32_t durability_remaining`, `bool is_listed`, `double commission_rate`
- `miners` (key=`asset_id`): `uint64_t asset_id`, `int32_t template_id`, `int32_t health`, `time_point_sec available`, `uint64_t plot_id` (0 = not placed)
- `gear` (key=`asset_id`): `uint64_t asset_id`, `int32_t template_id`, `uint32_t uses_remaining`, `time_point_sec available`, `uint64_t miner_asset_id` (0 = unattached)
- `mines` (key=`assoc_id`): `uint64_t assoc_id`, `name land_owner`, `uint32_t land_slot`, `uint64_t plot_id`, `uint64_t miner_asset_id`, `vector<uint64_t> gear_asset_ids`
- `crafts` (key=`assoc_id`): `uint64_t assoc_id`, `name category`, `uint64_t recipe_id`, `uint64_t rng_seed`, `uint8_t status`, `vector<Res> items`
- `deposits` (key=`asset_id`): `uint64_t asset_id`, `int32_t template_id`, `name schema_name`, `name collection_name`

### Cross-account occupancy (scope = land_owner)

- `occupancy` (key=`miner_asset_id`): `uint64_t miner_asset_id`, `name miner_owner`, `uint64_t land_asset_id`, `uint32_t land_slot`, `uint64_t plot_id`, `uint64_t active_assoc_id`

## 6. Complete action list

### Admin (require_auth = _self)
- `configset(...)`, `configclear()`, `maintset(bool)`
- Templates: `minerset(...)`, `minerdel(template_id)`, `gearset(...)`, `geardel(...)`, `landset(...)`, `landdel(...)`, `landdset(...)`, `landddel(...)`, `plotset(...)`, `plotdel(...)`
- Slot cost curve: `slotcostset(slot_index, cost_silver, cost_gold)`, `slotcostdel(slot_index)`
- Crafting: `ruleset`, `ruledel`, `ruleitemadd`, `ruleitemdel`, `recset`, `recdel`, `recreqaddft`, `recreqaddnft`, `recreqdel`, `recresadd`, `recresdel`
- ToS: `tosset(version, tos)`, `tosdel(version)`
- Free-play control: `fpstart()` — one-shot to bootstrap the first rarity-rotation RNG request

### Player (require_auth = owner unless noted)
- `tosaccept(account)`
- `setreferrer(account, referrer)` — one-time immutable, rejects self and cycles
- `buylandslot(owner)` — charges Silver/Gold using `landslotcost` for the next slot index, increments `accounts.unlocked_land_slots`, creates a new empty `landslots` row
- `activateland(owner, land_slot, land_asset_id)` — requires the land is in `deposits`; moves to `lands`; if template `is_freeplay`, requires the account has no other free-play land active
- `removeland(owner, land_slot)` — burns the land NFT (inline `atomicassets::burnasset`) and clears the slot; requires no active mine on the land
- `mineradd(owner, plot_id, miner_id)`, `minerrem(owner, plot_id, miner_id)`
- `gearadd(owner, miner_id, gear_id)`, `gearrem(owner, miner_id, gear_id)` — gearrem burns the gear
- `listland(owner, land_slot, commission_rate)` — rejects if the land's template `is_freeplay`; `commission_rate` in [0.0, 100.0]
- `unlistland(owner, land_slot)`
- `mine(miner_owner, land_owner, land_slot, plot_id, miner_id)` — `require_auth(miner_owner)`; validates the land is either miner_owner's OR listed; creates `mines` row + `rngassocs` + `occupancy`; fires RNG request
- `heal(owner, miner_id, amount)` — charges Silver from `accounts.balances`
- `craft(owner, category, recipe_id, asset_ids)` — creates `crafts` row + `rngassocs` + RNG request
- `craftclaim(owner, assoc_id)` — requires status=claimable; mints/transfers resolved items; deletes row
- `wdrawminer(owner, asset_ids)` — verifies each miner is not placed and not in any `mines`/`occupancy`; inline AtomicAssets transfer back to owner
- `wdrawsilver(owner, quantity, fee)` — debits balance, applies `config.fee`, inline token transfer with fee split to `fee_account`

### System (never called externally)
- `receiverand(assoc_id, random_value)` — `require_auth(name("orng.wax"))`; dispatches by `rngassocs.assoc_type` to mine resolver, craft resolver, or free-play rotation resolver
- `logmine(...)`, `logcraft(...)`, `logheal(...)` — `require_auth(_self)`; inline logs only, no state change

### Notification-based (no direct call)
- `on_notify("atomicassets::transfer")` — if `to == _self`, verifies collection is `config.collection_name`, reads each asset's template + schema, appends to `deposits` (scoped to sender)
- `on_notify("<silver_token_contract>::transfer")` — if `to == _self`, credits `accounts.balances` (scoped to sender)

## 7. Invariants that MUST hold after every action

Enforce with `check(...)` in code. These are the correctness contract.

1. Sum of all Silver in `accounts[*].balances` + `config.silver_pending_out` == Silver held by the contract account (accounting identity — no lost/created tokens).
2. Every `miners.plot_id != 0` has a matching `occupancy` row somewhere OR the miner is placed on the miner_owner's own land (recorded via a shared placement structure — CONFIRM design before implementing).
3. Every `lands.is_listed == true` refers to a land whose template `is_freeplay == false`.
4. `accounts[*].unlocked_land_slots >= 1` for any account that has ever accepted ToS.
5. At most one `lands` row per account has a template with `is_freeplay == true`.
6. Every `rngassocs` row has a matching `mines` or `crafts` or is the free-play rotation request.
7. No miner referenced by an active `mines` row can be in `wdrawminer`.
8. `referrals` is append-only; `referrer` field can never change once set.
9. `gear.miner_asset_id != 0` iff the gear is currently equipped; equipped gear can never be burned by `gearrem` from a different miner.
10. `land.durability_remaining == 0` implies the land row was deleted in the same transaction (no stale burned lands).

## 8. Security requirements (non-negotiable)

- Every action starts with `require_auth(the_correct_account)`. Never trust the parameter alone.
- Every arithmetic operation on rewards uses `int128_t` intermediate or `asset`'s checked ops. No `uint64_t` multiplication of two large values.
- Every inline transfer uses `require_recipient` semantics correctly and matches the exact memo format expected by counterparties.
- `receiverand` MUST verify `require_auth(name("orng.wax"))` and MUST verify the assoc_id exists in `rngassocs` before doing anything.
- On any early-return failure inside `receiverand`, DO NOT leave the associated `mines`/`crafts` row in a stuck state — either resolve it (even if unfavorably) or clear it. Stuck async state is an outage.
- Every RAM allocation uses the correct payer (the beneficiary of the row). Never pay RAM for player rows from `_self`.
- Every destructive path (`removeland`, `gearrem`, land/gear burn on depletion) MUST inline-call `atomicassets::burnasset` on the actual NFT. The row-only-deletion path is a critical bug.
- `tosaccept` gates every subsequent player action.
- Maintenance mode gates every player action.

## 9. Testing bar

Every phase must ship with tests covering:
- Happy path for every new action.
- Every documented failure mode (auth, maintenance, ToS, cooldown, durability=0, gear=0, health=0, already-active free-play land, listing a free-play land, self-referral, referral cycle, withdrawing a deployed miner, etc.).
- Table state assertions after each action (not just "no exception").
- For phases 6–9: a full RNG round-trip with a mocked `orng.wax` account on testnet.

## 10. What to do when unclear

If any table field, action parameter, memo format, invariant, or business rule needed for the phase is not in this brief, STOP and ask the human. Do not invent, do not guess, do not "implement it the way bcbrawlers probably did." The whole point of this document is that guessing is forbidden.
=========================
END OF MASTER BRIEF
=========================
```

---

## Part 3 — Per-phase Prompts

Paste master brief + phase prompt into a fresh session each time.

---

### Phase 0 — Project skeleton

```
Execute Phase 0 of the mining-game smart contract build plan.

Goal: a minimal eosio.cdt project that compiles and deploys an empty contract to WAX testnet.

Tasks:
1. Initialize project structure:
   contracts/mininggame/
     include/mininggame/mininggame.hpp
     src/mininggame.cpp
     CMakeLists.txt
   tests/
     README.md
     helpers/setup.sh          # deploy + init testnet account
     helpers/cleanup.sh
   scripts/
     build.sh
     deploy_testnet.sh
   docs/
     PHASE-0-REPORT.md
2. `mininggame.hpp` defines a `[[eosio::contract("mininggame")]] class mininggame : public contract` with just a constructor. No actions yet.
3. CMake builds against eosio.cdt >= 1.7. `build.sh` produces `mininggame.wasm` + `mininggame.abi`.
4. `deploy_testnet.sh` accepts a testnet account name + wallet, deploys, and echoes the deployment URL on a WAX testnet explorer.
5. `PHASE-0-REPORT.md` records the eosio.cdt version, the testnet account used, and the deployment tx id.

Deliverables:
- `mininggame.wasm` + `mininggame.abi` produced by `build.sh`.
- Deployed to testnet; explorer link in the report.
- ABI shows zero actions (empty contract is intended).

Do NOT: declare any tables, actions, or types yet. This is bootstrap only.
```

---

### Phase 1 — Types & tables

```
Execute Phase 1 of the mining-game smart contract build plan.

Goal: all types + all `multi_index` table declarations. No actions.

Tasks:
1. In `mininggame.hpp`, declare every struct listed in master brief §5, with the exact field names/types/order.
2. For each struct, declare its `multi_index` typedef with the exact table name from the brief.
3. Include `primary_key()` methods for each. If secondary indexes are needed for later phases (e.g. `lands` by `is_listed`, `mines` by `land_owner`), declare them now.
4. Shared value objects (`ReqFT`, `ReqNFT`, `Res`, `RuleItem`) from the bcbrawlers reference must be declared as reusable structs.
5. Rebuild and confirm the ABI now lists all tables with correct field names and types.

Deliverables:
- Contract compiles.
- ABI dump (from `cleos get abi`) attached to `PHASE-1-REPORT.md` showing every expected table.
- No actions in the ABI yet.

Do NOT: implement any action logic. Do not initialize any rows. Types + table declarations only.
```

---

### Phase 2 — Config & TOS

```
Execute Phase 2 of the mining-game smart contract build plan.

Goal: admin can configure the contract; players can accept ToS; a maintenance/TOS guard helper exists for later phases.

Tasks:
1. Implement admin actions: `configset` (upsert single `config` row), `configclear` (erase config), `maintset(bool)` (toggle maintenance_mode), `tosset(version, tos)`, `tosdel(version)`. All `require_auth(_self)`.
2. Implement player action: `tosaccept(account)` — `require_auth(account)`; upsert `tosuser[account].version = latest_tosconfig.version`.
3. Implement internal helpers (not actions):
   - `void check_not_maintenance()` — reads config, asserts `!maintenance_mode`.
   - `void check_tos_accepted(name owner)` — asserts `tosuser[owner].version == latest_tosconfig.version`.
4. Enforce sane bounds in `configset`: `fee` in [0.0, 20.0], `referral_rate` in [0.0, 20.0].

Tests (must pass):
- Non-`_self` caller of every admin action → rejected.
- `configset` with `fee = 25.0` → rejected.
- Player calls `tosaccept` before any `tosconfig` exists → rejected with clear message.
- Player calls `tosaccept` → `tosuser` row created with correct version.
- Toggle `maintset(true)` → subsequent player action (any) that calls `check_not_maintenance()` in future phases will be blocked.

Deliverables:
- Actions live on testnet.
- Test script + passing output.
- `PHASE-2-REPORT.md`.

Do NOT: implement templates, deposits, or gameplay actions.
```

---

### Phase 3 — Templates (admin CRUD)

```
Execute Phase 3 of the mining-game smart contract build plan.

Goal: admin can define miner, gear, land, plot, slot-cost templates.

Tasks:
1. Implement admin CRUD actions for all templates: `minerset/minerdel`, `gearset/geardel`, `landset/landdel`, `landdset/landddel`, `plotset/plotdel`, `slotcostset/slotcostdel`.
2. All `require_auth(_self)`.
3. Validation:
   - `minerset`: `health_max > 0`, `health_consumed <= health_max`, `reward_rate >= 0`, `cooldown > 0`, `rarity in [1, MAX_RARITY]`.
   - `gearset`: `uses > 0`, `capacity_boost >= 0`.
   - `landset`: if `is_freeplay == true`, `durability` is ignored (store 0), else `durability > 0`.
   - `slotcostset`: `slot_index >= 1` (slot 0 is default-unlocked at registration and cannot be set).
4. `del` variants require the row exists.

Tests:
- All happy paths.
- Non-`_self` caller → rejected for each action.
- `minerset` with `health_consumed > health_max` → rejected.
- `landset` with `is_freeplay=true`, `durability=0` → succeeds. With `is_freeplay=false`, `durability=0` → rejected.
- `slotcostset(slot_index=0, ...)` → rejected.

Deliverables:
- Testnet ABI shows all template actions.
- Test script + passing output.
- `PHASE-3-REPORT.md`.

Do NOT: implement anything player-facing beyond ToS from Phase 2.
```

---

### Phase 4 — Deposits (custody in)

```
Execute Phase 4 of the mining-game smart contract build plan.

Goal: NFTs and Silver sent to the contract are correctly recorded.

Tasks:
1. Implement `on_notify("atomicassets::transfer")` handler:
   - Ignore if `to != _self`.
   - Ignore if `from == _self`.
   - For each `asset_id`, look up the asset via `atomicassets::assets` table (scope = _self after transfer completes).
   - Assert `collection_name == config.collection_name`.
   - Insert into `deposits` scoped to `from`, with RAM paid by `_self` (contract accepts deposits from anyone) OR by `from` (preferred if possible — CONFIRM design choice with human before shipping).
2. Implement `on_notify("<silver_token_contract>::transfer")` handler:
   - Ignore if `to != _self`, or `from == _self`, or `quantity.symbol != config.silver_symbol`.
   - Verify sender is via `config.silver_token_contract` (contract of the notify).
   - Upsert `accounts[from]`, add `quantity` to the Silver-symbol entry in `balances`. RAM paid by `_self`.
   - Ensure a first-time account auto-creates its `accounts` row and its default `landslots[slot_id=0]` row (unlocked, empty). This is the "registration on first deposit" moment.
3. On the AtomicAssets notify, if the deposited NFT's template belongs to a `landconf`/`minerconf`/`gearconf`, still just record it in `deposits` — activation is a Phase 5 action, not automatic.

Tests:
- Send an NFT from a non-accepted collection → deposits row NOT created.
- Send an NFT from the accepted collection → deposits row created with correct fields.
- Send Silver with wrong symbol → rejected.
- Send Silver correctly → `accounts[sender].balances` credited; `landslots[0]` created if first time.
- Send Silver from `_self` (edge) → ignored.

Deliverables:
- Round-trip verified on testnet with real AtomicAssets test collection.
- Test script + passing output.
- `PHASE-4-REPORT.md` documenting the exact memo formats accepted (if any) for both handlers.

Do NOT: implement withdrawals or any activation logic yet.
```

---

### Phase 5 — Setup actions

```
Execute Phase 5 of the mining-game smart contract build plan.

Goal: every non-gameplay player action.

Tasks (each action begins with `require_auth`, `check_not_maintenance`, `check_tos_accepted` unless noted):
1. `setreferrer(account, referrer)`:
   - `require_auth(account)`. `referrer != account`. Referrer's `accounts` row must exist. Walk the chain: `referrer`'s referrer chain must not include `account` (cycle check, up to a safe depth like 10).
   - `referrals` is append-only; if a row for `account` exists, reject.
2. `buylandslot(owner)`:
   - Reads `accounts[owner].unlocked_land_slots`, computes `next_slot_index = unlocked + 1` (indexing so slot 0 is the default free one and slot 1 is the first paid).
   - Look up `landslotcost[next_slot_index]`. Reject if missing (admin hasn't set a price for that tier).
   - Debit `accounts[owner].balances` by `cost_silver` (and Gold if the cost curve includes it — but Gold is an NFT, so if a Gold cost is defined it must be paid by burning a specific gold-currency-NFT held in deposits; CONFIRM design before implementing this branch).
   - Increment `unlocked_land_slots`, create new `landslots[next_slot_index]` empty row.
3. `activateland(owner, land_slot, land_asset_id)`:
   - `landslots[land_slot]` exists AND `land_asset_id == 0` (empty).
   - `deposits[land_asset_id]` exists AND its template is a `landconf`.
   - If the land template `is_freeplay == true`, iterate `lands` scope owner and reject if any existing land has an `is_freeplay` template.
   - Move the row: erase from `deposits`, insert into `lands` with full durability (or 0 if freeplay), `is_listed=false`, `commission_rate=0`. Update `landslots[land_slot].land_asset_id`.
4. `removeland(owner, land_slot)`:
   - `lands` row exists for that slot; no active `mines` on this land (check `mines` scope owner and cross-account `occupancy` scope owner for this land).
   - Inline `atomicassets::burnasset` on the land NFT.
   - Erase `lands` row; clear `landslots[land_slot].land_asset_id`.
5. `mineradd(owner, plot_id, miner_id)`:
   - `deposits[miner_id]` OR `miners[miner_id]` exists (miner may already be in `miners` from prior placement); it must currently have `plot_id == 0`.
   - `plot_id` valid for one of the owner's activated lands. (Design decision needed: is `plot_id` global or per-land? CONFIRM.)
   - Move `deposits` → `miners` if not already there. Set `miners[miner_id].plot_id`.
6. `minerrem(owner, plot_id, miner_id)`:
   - Miner not currently in any `mines` row. Clear `plot_id = 0`. Also detach any attached gear (`gear.miner_asset_id = 0` for gear pointing to this miner — but do NOT burn the gear; it just becomes unattached).
7. `gearadd(owner, miner_id, gear_id)`:
   - Miner exists and is placed. Gear exists in `deposits` or `gear` with `miner_asset_id == 0`.
   - Move deposits → gear if not already. Set `gear[gear_id].miner_asset_id = miner_id`.
8. `gearrem(owner, miner_id, gear_id)`:
   - Gear exists, is attached to `miner_id`, no active mine using this gear.
   - Inline `atomicassets::burnasset` on the gear NFT.
   - Erase `gear` row.
9. `listland(owner, land_slot, commission_rate)`:
   - `lands` row exists; land's template `is_freeplay == false`; `commission_rate` in [0.0, 100.0].
   - Set `is_listed=true`, `commission_rate`.
10. `unlistland(owner, land_slot)`:
    - No active `occupancy` rows for this land (can't unlist while someone is mining).
    - Set `is_listed=false`.

Tests (representative subset — real suite is exhaustive):
- Self-referral rejected. Cycle (A→B, B→A) rejected. Second `setreferrer` for same account rejected.
- `buylandslot` without enough Silver rejected. With enough Silver, slot created and cost debited.
- Activate two free-play lands on same account → second rejected.
- Remove land with an active `mines` row → rejected.
- `listland` on a free-play land → rejected.
- `unlistland` while `occupancy` has entries → rejected.
- `gearrem` while the miner is in an active `mines` row using this gear → rejected.

Deliverables:
- All actions on testnet, full test suite passing.
- `PHASE-5-REPORT.md`.

Do NOT: implement `mine`, `heal`, `craft`, RNG, or withdrawals.
```

---

### Phase 6 — RNG plumbing

```
Execute Phase 6 of the mining-game smart contract build plan.

Goal: a working `orng.wax` request/callback loop, with stub resolvers.

Tasks:
1. Internal helper `uint64_t request_random(name owner, name assoc_type, uint64_t context_id)`:
   - Reads `config.next_assoc_id`, increments and persists.
   - Inserts `rngassocs` row.
   - Inline-sends `orng.wax::requestrand(assoc_id, signing_value, _self)` where `signing_value = assoc_id ^ current_time_point().sec_since_epoch() ^ owner.value`.
   - Returns the `assoc_id`.
2. Action `receiverand(uint64_t assoc_id, checksum256 random_value)`:
   - `require_auth(name("orng.wax"))`.
   - Look up `rngassocs[assoc_id]`; assert exists.
   - Dispatch on `assoc_type`:
     * "mine" → call `resolve_mine(assoc_id, random_value)` — STUB in this phase: just erase the mines row + rngassocs row, log "stub".
     * "craft" → call `resolve_craft(...)` — STUB.
     * "freeplayrot" → call `resolve_freeplay_rotation(...)` — STUB.
     * unknown → assert failure.
3. Admin action `fpstart()` — `require_auth(_self)`; one-shot: reject if `freeplaystate` singleton already exists with `rotation_assoc_id != 0`; request a first freeplayrot RNG; on callback, set `current_allowed_rarity` (random from allowed set) and `window_ends_at = now + rotation_period`, and immediately request the next rotation. So `resolve_freeplay_rotation` is the ONE resolver that MUST be implemented for real in this phase (not a stub) — the stubs above are for mine/craft only.

Tests:
- Only `orng.wax` can call `receiverand`; any other caller → rejected.
- Unknown `assoc_id` → rejected cleanly.
- `fpstart` bootstraps free-play rotation on testnet with a real `orng.wax` interaction (using WAX testnet's oracle).
- Confirm the free-play rotation loop is self-perpetuating: after one rotation resolves, the next one is queued.

Deliverables:
- End-to-end RNG round trip on testnet.
- Free-play rotation running and self-perpetuating.
- Mine and craft resolvers exist as clearly-marked stubs.
- `PHASE-6-REPORT.md`.

Do NOT: implement the mine/craft resolvers for real yet — that's Phase 7 and 9.
```

---

### Phase 7 — Core mining (own-land only)

```
Execute Phase 7 of the mining-game smart contract build plan.

Goal: `mine` action + real `resolve_mine` + `heal`, restricted to `miner_owner == land_owner`.

Tasks:
1. `mine(miner_owner, land_owner, land_slot, plot_id, miner_id)`:
   - `require_auth(miner_owner)`, guards.
   - PHASE 7 restriction: assert `miner_owner == land_owner`. (Phase 8 removes this.)
   - Look up land in `lands` (scope land_owner) by `land_slot`; assert exists, `durability_remaining > 0`.
   - If land template is free-play: read `freeplaystate.current_allowed_rarity`, verify miner's template rarity matches. Reject if not.
   - Look up miner: `miners[miner_id]`; assert placed at `plot_id`, `available <= now`, `health >= miner_conf.health_consumed`.
   - Look up any attached gear (iterate `gear` by `miner_asset_id`); assert each has `uses_remaining > 0` and `available <= now`.
   - Insert `mines` row with all context.
   - Call `request_random(miner_owner, "mine"_n, mine_row_pk)`.
2. `resolve_mine(assoc_id, random_value)` (called from `receiverand`):
   - Load `mines[assoc_id]`, `rngassocs[assoc_id]`.
   - Load miner_conf, gear list, land_conf.
   - Compute gross reward using the master brief §3 formula, deterministically from `random_value` for the Gold-drop roll.
   - Apply reward waterfall:
     * platform fee → `fee_account` (credit to accounts.balances of fee_account? OR inline transfer? CONFIRM design)
     * referral cut (if `referrals[miner_owner]` exists) → referrer's balance
     * remainder → miner_owner's balance
     * Gold roll: if hits, inline `atomicassets::mintasset` from `config.gold_template_id` to miner_owner
   - Decrement land durability; if zero, inline burnasset the land + erase lands row + clear landslots pointer.
   - Decrement each gear's uses_remaining; if zero, inline burnasset + erase gear row.
   - Decrement miner health, set `available = now + miner_conf.cooldown`. Same for gear cooldowns.
   - Inline `logmine(...)`.
   - Erase `mines[assoc_id]`, `rngassocs[assoc_id]`.
3. `heal(owner, miner_id, amount)`:
   - Cost = `amount * miner_conf.health_cost`. Debit balance. Increase health, capped at `health_max`. Inline `logheal`.
4. `logmine(...)`, `logheal(...)`: `require_auth(_self)`, no-op state.

Tests (representative):
- Mining while in maintenance → rejected.
- Mining without ToS → rejected.
- Mining with a cooling-down miner → rejected.
- Mining with 0-health miner → rejected.
- Free-play land with wrong-rarity miner → rejected.
- Happy-path own-land mine → correct amounts credited (validate against a hand-calculated expected number).
- Gold-drop roll: run with a known random_value where Gold should hit → mint action fired.
- Land durability decrement to zero → land burned + slot cleared.
- Gear uses decrement to zero → gear burned.
- Heal with insufficient balance → rejected.
- Heal beyond health_max → clamps, not over-charges.

Deliverables:
- End-to-end mining works on testnet.
- Test suite with hand-verified reward math.
- `PHASE-7-REPORT.md`.

Do NOT: implement cross-player mining (Phase 8) or crafting (Phase 9).
```

---

### Phase 8 — Cross-player mining

```
Execute Phase 8 of the mining-game smart contract build plan.

Goal: `mine` supports `miner_owner != land_owner`.

Tasks:
1. Remove the Phase-7 restriction. In `mine`:
   - If `miner_owner == land_owner`: same as Phase 7.
   - If `miner_owner != land_owner`:
     * Land template `is_freeplay` MUST be false (free-play is private-only).
     * `lands[land_asset_id]` scope=land_owner must have `is_listed == true`.
     * Miner + gear must be owned by miner_owner (in their own `miners`/`gear` tables).
     * Insert `occupancy` row scoped to `land_owner` with all context; insert `mines` row scoped to `miner_owner`.
2. Extend `resolve_mine` to handle the cross-player case:
   - After computing gross:
     * platform fee → fee_account
     * landlord commission (`land.commission_rate` %) → land_owner's balance
     * referral cut → miner_owner's referrer
     * remainder → miner_owner
   - Erase both `mines` (miner_owner scope) and `occupancy` (land_owner scope) rows at the end.
3. Update `wdrawminer` (implemented in Phase 9, but design the check now): a miner is "in use" if it appears in ANY `mines` row (own scope) OR any `occupancy` row anywhere referencing it. This requires either a secondary index on occupancy by `miner_asset_id`, or an additional per-miner "deployed" flag. CONFIRM the design choice with the human before implementing.
4. Update `removeland` and `unlistland`: block if any `occupancy` rows exist under this land_owner for this land.

Tests:
- Cross-player mine happy path: commission split matches hand-calculation.
- Cross-player mine on unlisted land → rejected.
- Cross-player mine on free-play land → rejected (defense-in-depth; free-play can never be listed, so this is a belt-and-suspenders check).
- Owner tries to unlist while another player has an active occupancy → rejected.
- Owner tries to remove land with active occupancy → rejected.
- Miner owner tries to trigger `mine` with a miner they don't own → rejected.
- Gold drop still lands on miner_owner (not land_owner).

Deliverables:
- Testnet round-trip with two accounts.
- Test suite covering commission math edge cases (0%, 100%, decimal edge cases).
- `PHASE-8-REPORT.md`.

Do NOT: implement crafting or withdrawals yet.
```

---

### Phase 9 — Crafting + withdrawals + free-play polish

```
Execute Phase 9 of the mining-game smart contract build plan.

Goal: everything remaining.

Tasks:
1. Crafting admin CRUD: `ruleset/del`, `ruleitemadd/del`, `recset/del`, `recreqaddft/aftnft/del`, `recresadd/del`. Same shape as bcbrawlers.
2. `craft(owner, category, recipe_id, asset_ids)`:
   - Guards.
   - Load recipe (scope by category). Assert current time in `[start_ms, end_ms]`.
   - Validate `req_ft` (debit Silver from balance) and `req_nft` (match `asset_ids` against required templates; burn if `req.burn == true` else move to a locked state).
   - Create `crafts` row with `status = pending`.
   - `request_random(owner, "craft"_n, crafts_row_pk)`.
3. `resolve_craft(assoc_id, random_value)`:
   - Walk `recipe.results` (rule_ids). For each rule, roll in `[0, total_weight)` using bytes of `random_value` (advance byte offset per roll). Pick the matching `RuleItem`, append to `crafts.items`.
   - Set `status = claimable`. Erase `rngassocs` row.
4. `craftclaim(owner, assoc_id)`:
   - Load `crafts[assoc_id]`; assert `status == claimable`.
   - Mint/transfer each resolved `Res` (fungible → credit balance; NFT → inline `atomicassets::mintasset`).
   - Increment `craftcounts` per template.
   - Inline `logcraft`. Erase `crafts` row.
5. `wdrawsilver(owner, quantity, fee)`:
   - Guards. Debit `accounts[owner].balances` by `quantity`. Compute fee from `config.fee` (do NOT trust the passed `fee` parameter — validate it matches; if not, reject to catch out-of-date frontends).
   - Inline transfer: `fee_amount` to `config.fee_account`, `quantity - fee_amount` to `owner`, via `config.silver_token_contract`.
6. `wdrawminer(owner, asset_ids)`:
   - For each: assert miner exists in `miners` scope owner, `plot_id == 0`, and no `mines` row (scope owner) references it, and no `occupancy` anywhere references it.
   - Inline `atomicassets::transfer(_self, owner, asset_ids, "withdraw miner")`.
   - Erase `miners` rows.
7. Free-play polish: ensure `resolve_freeplay_rotation` uses the weighted list from an admin-settable table (e.g. `fprarityweights`), not hardcoded rarities. Add admin action `fprwset(rarity, weight)`.

Tests:
- Crafting: happy path with a single-rule single-item recipe; assert output matches expected under a known `random_value`.
- Weighted resolution: run 1000 iterations against a mocked RNG feeder; assert observed distribution within tolerance of expected weights.
- Craft during a closed window (before start_ms or after end_ms) → rejected.
- Craft with insufficient FT input → rejected. With wrong NFT input → rejected.
- Withdraw Silver with wrong fee param → rejected.
- Withdraw Silver → balance decreases exactly by quantity; fee_account credited; user token balance increased by (quantity - fee).
- Withdraw miner while placed → rejected. While in `mines` → rejected. While in `occupancy` → rejected. When idle → succeeds.
- Free-play rarity rotation weighted correctly (statistical test).

Deliverables:
- Full contract feature-complete on testnet.
- Full test suite passing.
- `PHASE-9-REPORT.md`.
- A separate `SECURITY-AUDIT-CHECKLIST.md` listing every check from master brief §8 and its status.

Do NOT: deploy to mainnet. That's a separate, human-gated step after external audit.
```

---

## Appendix — Pre-flight decisions the human must make before Phase 5

The build plan flags these as CONFIRM points; better to answer them once upfront:

| # | Decision | Options |
|---|---|---|
| 1 | Is `plot_id` global (a plot exists once, shared across lands) or per-land (each land has its own plots)? | Per-land is more flexible; global is simpler. |
| 2 | RAM payer for `deposits` rows on first NFT transfer in | `_self` (contract eats it — smoother onboarding) vs `from` (needs a pre-existing sponsored RAM or CPU/NET). |
| 3 | Can `buylandslot` cost include Gold NFTs, or only Silver? | Master brief allows both; simplify to Silver-only if Gold-as-payment is complex. |
| 4 | Platform fee routing: credit to `fee_account.balances` (kept in the contract) or inline-transfer to fee_account's wallet? | Balance is cheaper; wallet is more transparent. |
| 5 | Free-play rarity set + weights + rotation period | E.g. rotate every 6h; rarities {common:70, rare:25, epic:5}. |
| 6 | Referral cycle-check depth | 10 is a safe default. |
| 7 | Max referral chain earnings per referee (anti-abuse cap) | E.g. cap referrer earnings at N% of gross lifetime. Or no cap. |
| 8 | Silver withdrawal fee validation strategy | Reject on mismatch (strict) vs snap to config value (lenient). Strict recommended. |
| 9 | Slot 0 (the default) — is it a "free-play only" slot, a general slot, or does it not restrict what goes in it? | Recap of earlier conversation: default slot is unlocked at registration, empty; the free-play land is a template that can go into any slot (max 1 per account). Confirming there's no separate "free-play slot" concept — the restriction is per-land-template, not per-slot. |
| 10 | Testnet target: WAX testnet or Jungle? | WAX testnet is closer to mainnet parity for AtomicAssets. |

Get answers to these, add them as a note at the top of the Phase 0 prompt, and the agent won't need to stop and ask.
