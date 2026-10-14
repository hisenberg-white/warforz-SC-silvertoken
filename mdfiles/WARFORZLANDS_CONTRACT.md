# WarForz Lands — Smart Contract Reference

**Single source of truth for the WAX/Antelope contract.** Supersedes `WARFORZLANDS_MASTER_SPEC.md`, `mining_game_contract_plan.md`, `SECURITY-AUDIT-CHECKLIST.md`, `code_review.md`, `final_game_overview.md`, and `Game Basics.txt`.

Last verified against source: **2026-08-13**, deployed WAX testnet code hash `aac0469b494b31635b71cf6dfb2cf3b7890eb9631bc09f20f7f6aafd0f39c4a4`.

| Field | Value |
|---|---|
| Contract account | `warforzlands` (WAX testnet) |
| Language / toolchain | C++17, Antelope CDT 4.1.1 |
| ABI | `eosio::abi/1.2` — 65 actions, 33 tables, 104 structs |
| NFT standard | AtomicAssets (collection `warforzlands`) |
| Randomness | `orng.wax` (async request → callback) |
| Source | `SC/mininggame/src/warforzlands.cpp`, `include/warforzlands.hpp` |
| Economy | `WARFORZLANDS_ECONOMY_CONFIG_V1.md` (kept — it is the balance sheet, not a design doc) |

---

## 1. Design principles

1. **Configuration over code.** If a number can change after launch, it is a config row, not a constant. Currencies, templates, rarities, rewards, mining types, recipes, durability, health, RNG chances, slot requirements and referral rates all have admin tables.
2. **Generic over specific.** Themeable via config/display data, not new code paths.
3. **Irreversibility requires friction.** Every NFT burn needs an explicit frontend confirmation.
4. **Async RNG is first-class.** Anything using `orng.wax` is a two-phase state machine (request → pending → resolve). Nothing resolves synchronously.
5. **Zero-sum economics.** Every reward split sums exactly to gross with deterministic integer rounding.
6. **Backward-compatible extension.** New systems arrive as new tables/actions, never by breaking existing layouts.

---

## 2. Build and deploy

```sh
# Reproducible container build — the CDT version is load-bearing, see below
docker build -f tests/Dockerfile.cdt -t warforz-cdt:4.1.1 .
docker run --rm -v "$PWD:/project" warforz-cdt:4.1.1 \
  -abigen -contract warforzlands -I include -I . -R . \
  -o build/warforzlands.wasm src/warforzlands.cpp

pwsh tests/static_contract_checks.ps1
```

**The build is bit-for-bit reproducible on CDT 4.1.1.** Unchanged source yields
the deployed code hash `c6f6541fef6f4c66af4b388db3a4de4bd9d79f736d3fa9e175cfe13cb12fbcf4`.
If your build does not match that for unchanged source, your toolchain is wrong —
CDT 3.1.0 produces a different binary *and* an ABI in which all seven singleton
tables are mis-named after their row structs (`config_s` instead of `config`),
which makes them unqueryable. See the header of `tests/Dockerfile.cdt`.

**`-I .` is required alongside `-I include`.** CDT's codegen pass runs from
`/tmp` and cannot otherwise resolve the rewritten include path.

**ABI normalization is no longer needed.** `tests/normalize_wax_abi.ps1` exists
to repair CDT 3.1.0 output — chiefly restoring the singleton table names that
version drops. CDT 4.1.1 emits them correctly, so its raw output is already
correct. The deployed ABI has in fact never been normalized: it carries the same
33 `_`-suffixed struct type labels (`account_s`, `config_s`, …) that CDT emits,
and both `setabi` and table queries accept them. Running the script now would
rename those 33 type labels and make the ABI diverge from what is live for no
benefit. Keep it for reference; do not put it in the build path.

`warforzlands.contracts.md` and `warforzlands.clauses.md` are **Ricardian build
inputs** consumed by `cdt-cpp -R`, not documentation. Do not delete them. They
must use the HTML heading form CDT parses — `<h1 class="contract">action</h1>`
and `<h1 class="clause">id</h1>`. Markdown `##` headings are silently ignored:
the build succeeds, every action logs "does not have a ricardian contract", and
the ABI ships with empty Ricardian content. **Treat those warnings as errors.**
Both files now use the correct form and the generated ABI carries Ricardian text
for all 64 actions plus 7 clauses.

### Deployment order

1. Set the contract account's active permission to include `eosio.code`.
2. Deploy WASM + normalized ABI **with maintenance enabled**.
3. Grant AtomicAssets collection author/minter permissions for all mint and burn paths.
4. Seed configuration via `scripts/seed-config.sh` (see §11).
5. Register the FT fee account and platform accounts with the current ToS.
6. Fund rewards — transfer the configured FT **from `ftconfig.fee_account`** with memo `rewardpool`.
7. `fpstart` once at least one enabled selector exists.
8. Run every scenario, reconcile custody and liabilities, then disable maintenance.

### Breaking-change deploys

Adding a field to any table struct makes existing rows undeserializable. `get_config()` runs in nearly every action, so deploying over live rows **bricks the contract's own recovery path**. Correct order: `maintset(true)` → `resetuser` each player → `wipeall` → **then** `set contract`. Always `cleos get code <acct> -c old.wasm -a old.abi` first for rollback.

---

## 3. Naming — physical vs conceptual

EOSIO names are capped at 13 characters; this project uses a conservative 12 and `static_contract_checks.ps1` enforces it. Conceptual names in older docs map to physical on-chain names:

| Conceptual | Physical |
|---|---|
| `miningtypeconf` | `miningtypes` |
| `landminermatch` | `landminmatch` |
| `fpselectorconf` | `fpselectors` |
| `freeplaystate` | `freeplaystat` |
| `matchbonusset` / `matchbonusdel` | `matchset` / `matchdel` |
| `fpselectorset` / `fpselectordel` | `fpselset` / `fpseldel` |
| `templateusage` | `templateuse` |
| recipe Gold price setter | `recreqaddgld` |
| `gearconf` (struct) | table `equipconf`, struct `gearconf` |
| `wdrawsilver` | `wdrawft` |

Removed and gone: `buylandslot`, `landslotcost`, `plotdef`/`plotset`/`plotdel`, `slotcfgset`, `fprwset`/`fprweights`, `loggold`, `accounts.gold`, `config.gold_template_id`, `config.silver_symbol`, `config.silver_token_contract`.

---

## 4. Tables (33)

### Contract-scoped (`scope = _self`)

| Table | Struct | Key | Fields |
|---|---|---|---|
| `config` | `config` | singleton | `maintenance_mode`, `collection_name`, `mining_fee_pct`, `referral_rate`, `next_assoc_id`, `max_freeplay_lands_per_account`, `referral_cycle_depth`, `max_nft_drop_rate` |
| `ftconfig` | `ftconfig` | singleton | `contract`, `token_symbol`, `display_name`, `fee_account`, `withdraw_fee_pct`, `referral_withdraw_pct` |
| `nftconfig` | `nftconfig` | singleton | `collection`, `schema`, `template_ids[]`, `display_name` |
| `signupnft` | `signupnft` | optional singleton | `schema_name`, `template_id`; collection is always `config.collection_name`; absent means registration mints nothing |
| `rewardpool` | `rewardpool` | singleton | `available` (asset) |
| `tosconfig` | `tosconfig` | `version` | `tos` text |
| `tosuser` | `tosuser` | `account` | `version` accepted |
| `blocked` | `blocked` | `account` | `reason`, `blocked_at` |
| `minerconf` | `minerconf` | `template_id` | `miner_type`, `rarity`, `health_max`, `base_reward_rate`, `base_nft_drop_rate`, `cooldown_sec`, `compatible_land_types[]`, `compatible_equipment_types[]`, `health_cost_per_point` (asset), `health_cost_per_mine` |
| `equipconf` | `gearconf` | `template_id` | `equipment_type`, `rarity`, `durability_max`, `reward_boost`, `nft_drop_boost`, `compatible_miner_types[]`, `compatible_mining_types[]` |
| `landconf` | `landconf` | `template_id` | `rarity`, `durability_max`, `unlimited_durability`, `is_freeplay`, `land_type`, `land_bonus`, `compatible_miner_types[]`, `compatible_mining_types[]`, `nft_drop_bonus` |
| `landdef` | `landdef` | `template_id` | `land_name`, `rarity`, `img` — display only, never read by reward logic |
| `landminmatch` | `landmatch` | `id`, idx `bypair` | `land_type`, `miner_type`, `bonus_multiplier` |
| `miningtypes` | `miningtype` | `mining_type_id` | `display_name`, `enabled`, `health_cost`, `reward_multiplier`, `nft_drop_bonus`, `cooldown_sec`, `failure_chance`, `death_chance`, `land_damage_multiplier`, `equipment_damage_multiplier`, `decay_on_failure`, `special_modifiers[]` |
| `slotconf` | `slotconf` | `slot_index` | `template_id`, `enabled`, `burn_rule` |
| `fpselectors` | `fpselector` | `selector_value` | `weight`, `rotation_period_sec` |
| `freeplaystat` | `fpstate` | singleton | `current_allowed_selector`, `window_ends_at`, `rotation_assoc_id` |
| `craftrecipes` | `craftrecipe` | `recipe_id`, **scope = category** | `category`, `name`, `ft_inputs[]`, `nft_inputs[]`, `rule_ids[]`, `start_ms`, `end_ms`, `gold_amount` |
| `craftrules` | `craftrule` | `rule_id` | `items[]` (RuleItem), `total_weight`, `recipe_ref_count` |
| `craftcounts` | `craftcount` | `template_id` | `count` minted |
| `rngassocs` | `rngassocs` | `assoc_id` | `assoc_type`, `owner`, `context_id`, `request_time` |
| `referrals` | `referrals` | `referee` | `referrer`, `set_at` — append-only |
| `templateuse` | `templateuse` | `template_id` | `custody_count` — blocks deletion of in-use config |

### Player-scoped (`scope = owner`)

| Table | Struct | Key | Fields |
|---|---|---|---|
| `accounts` | `account` | singleton | `account`, `balances[]` (asset), `unlocked_land_slots`, `created_at` |
| `goldbalance` | `goldbalance` | singleton | `amount` (uint64) — the NFT-currency counter |
| `landslots` | `landslot` | `slot_id` | `land_asset_id` (0 = empty) |
| `lands` | `land` | `asset_id` | `template_id`, `slot_id`, `durability_remaining`, `is_listed`, `commission_rate` |
| `landcool` | `landcool` | `asset_id` | `available` — added separately so existing `lands` rows never had to be re-serialized |
| `miners` | `miner` | `asset_id` | `template_id`, `health`, `available`, `plot_id` (0 = unplaced) |
| `equipment` | `gear` | `asset_id`, idx `byminer` | `template_id`, `durability_remaining`, `available`, `miner_asset_id` |
| `mines` | `minerow` | `assoc_id`, idx `byminer` | full economic snapshot — see §7.2 |
| `crafts` | `craftrow` | `assoc_id` | `category`, `recipe_id`, `status`, `items[]`, `locked_assets[]`, `reserved_ft` |
| `deposits` | `deposit` | `asset_id` | `template_id`, `schema_name`, `collection_name`, `locked` |

### Cross-account (`scope = land_owner`)

| Table | Key | Fields |
|---|---|---|
| `occupancy` | `miner_asset_id`, idx `byplot`, `byland` | `miner_owner`, `land_asset_id`, `land_slot`, `plot_id`, `active_assoc_id` |

---

## 5. Actions (66)

### Admin — `require_auth(_self)`

**Global** `configset` · `ftconfigset` · `nftconfigset` · `configclear` · `maintset` · `tosset` · `tosdel` · `blockset` · `blockdel` · `resetuser` · `wipeall`

**Content** `minerset`/`minerdel` · `equipset`/`equipdel` · `landset`/`landdel` · `landdset`/`landddel` · `matchset`/`matchdel` · `mtypeset`/`mtypedel` · `slotconfset`/`slotconfdel` · `fpselset`/`fpseldel` · `fpstart`

**Crafting** `ruleset`/`ruledel` · `ruleitemadd`/`ruleitemdel` · `recset`/`recdel` · `recreqaddft` · `recreqaddnft` · `recreqaddgld` · `recreqdel` · `recresadd`/`recresdel`

### Player — `require_auth(owner)`

`tosaccept` · `setreferrer` · `unlockslot` · `claimdeps` · `activateland` · `removeland` · `mineradd`/`minerrem` · `equipstake` · `equipadd`/`equiprem` · `listland`/`unlistland` · `mine` · `heal` · `craft` · `craftclaim` · `wdrawft` · `wdrawgold` · `wdrawminer`

`signupnftset` / `signupnftdel` are admin controls for an optional welcome NFT from the game's own `config.collection_name`. The setter exposes no collection argument. When configured, the contract validates the AtomicAssets template immediately and mints one NFT only when `tosaccept` creates a new account. Re-accepting later ToS versions does not mint again. With no `signupnft` row, signup follows the original no-mint path.

### Permissionless keeper

`fprotate(caller)` — requests the next due free-play rotation. Safe against concurrent calls: it only fires when `freeplaystat.window_ends_at` is due and no rotation is pending. Driver script: `testnet/fprotate-keeper.sh`.

### System

`receiverand(assoc_id, random_value)` — `require_auth("orng.wax")`, the **only** path that credits RNG-dependent outcomes.
`notify(owner, info[])` — `require_auth(_self)`, bounded, stateless human-readable receipt for the parent transaction trace.
`logmine` · `logheal` · `logcraft` — `require_auth(_self)`, typed inline settlement receipts for contract-history indexers.

All four receipt actions deliberately avoid `require_recipient`. The `owner` field identifies the player in trace data, but the contract never dispatches the receipt into that player's account. This prevents contract accounts with rejecting notification handlers from reverting a successful player action or an ORNG callback. The frontend reads synchronous `notify.info` from the submitted transaction trace; asynchronous mining/crafting clients read the contract's typed receipt traces by owner/association.

### Notification handlers

`atomicassets::transfer` — NFT custody in.
`*::transfer` — FT custody in; the handler verifies `get_first_receiver() == ftconfig.contract` and the symbol.

Successful player custody deposits emit a bounded `notify` trace receipt after the credit/custody mutation. Reward-pool funding is operational rather than player-facing and does not emit one.

---

## 6. Guards

Every player action runs three guards: `require_auth(owner)`, `check_not_maintenance()`, `check_tos_accepted(owner)`. `check_not_blocked(owner)` additionally rejects administratively blocked accounts.

Maintenance mode blocks: registration, referrals, NFT/FT deposits, slot unlock, land/miner/equipment management, listing, the keeper, mining, healing, crafting, claims and withdrawals. It deliberately **does not** block admin configuration, `maintset`, reward-pool funding, authenticated ORNG callbacks for already-pending operations, or contract-authenticated receipt logs — these are the recovery paths.

---

## 7. Mining engine

### 7.1 Reward formulas

```
gross FT = miner.base_reward_rate
         × equipment.reward_boost            (1.0 with no equipment)
         × land.land_bonus                   (V1: 1.10 / 1.12 / 1.15, 1.0 for F2P)
         × landminmatch.bonus_multiplier     (1.0 if no row for the pair)
         × miningtype.reward_multiplier
```

```
Gold chance = miner.base_nft_drop_rate
            + equipment.nft_drop_boost       ← ADDITIVE percentage points
            + land.nft_drop_bonus
            + miningtype.nft_drop_bonus
  then floor at 0, cap at config.max_nft_drop_rate (0 disables), clamp to 1
```

The Gold formula is **additive, not multiplicative**. Economy V1 §10 requires Common miner 5.00% + Common equipment 2.50% = **7.50%**; the earlier multiplicative form produced 5.125%. `nft_drop_boost` and `nft_drop_bonus` are percentage points expressed as fractions (0.025 = +2.50%), all bounded `[-1, 1]`.

```
health spent = miner.health_cost_per_mine × miningtype.health_cost
heal cost    = amount × miner.health_cost_per_point   (V1: 5 FT per HP, flat)
```

The mining type's `health_cost` is a **multiplier** on the miner's own damage, not an absolute cost. Normal Mining sets it to 1, so each miner spends exactly its configured damage.

### 7.2 Two-phase resolution

**`mine(miner_owner, land_owner, land_slot, plot_id, miner_id, mining_type_id)`** validates and reserves, then requests randomness. It creates only a temporary ORNG replay/busy lock — it does **not** start miner or land cooldown, because no reward exists yet.

Validation order: mining type enabled → land resolved, listed if cross-player, durability > 0, not cooling → miner resolved, off cooldown, enough health → compatibility (land↔miner, miner↔land, land↔mining-type, equipment↔miner, miner↔equipment, equipment↔mining-type) → free-play selector gate → placement → busy lock → plot exclusivity → at most one equipment → `reserve_reward(maximum)`.

Every economic and destructive term is **snapshotted into the `mines` row** before RNG: `commission_rate`, `health_cost`, `cooldown_sec`, `reward_rate`, `nft_drop_rate`, `land_bonus`, `match_bonus`, `equipment_reward_boost`, `mining_reward_multiplier`, `failure_chance`, `death_chance`, `land_damage`, `equipment_damage`, `decay_on_failure`, `reserved_reward`. Resolution never re-reads config, so an admin edit mid-flight cannot change a pending mine's terms.

**`receiverand` → `resolve_mine`** splits the 32-byte checksum into non-overlapping 64-bit lanes so independent outcomes never share entropy:

| Lane (byte offset) | Roll |
|---|---|
| 0 | failure chance |
| 8 | death chance |
| 16 | Gold drop |

Then, atomically: re-verify health floor (bail cleanly if config changed) → roll failure → roll death → gross = reserved (or 0, releasing the reservation) → waterfall → Gold drop → land durability → equipment durability → miner health, cooldown, detach → `logmine` → delete the pending mine.

### 7.3 Reward waterfall

Integer basis-point math (`int128_t` intermediates) so no rounding drift. Sequential:

1. **Platform fee** — `config.mining_fee_pct` → `ftconfig.fee_account`
2. **Landlord commission** — only when `land_owner != miner_owner`, using the rate snapshotted at `mine` time
3. **Referral cut** — `config.referral_rate` of the miner-owner's remaining share
4. **Remainder** → miner owner

All credits go through `credit_safe()`: an uncreditable recipient rolls into the miner's net and is reported as 0 in `logmine`, so a missing account can never strand the oracle callback.

### 7.4 Consumable decay

`decay_on_failure` (per mining type) governs whether a failed or fatal mine still spends **land durability and equipment uses**. Normal Mining sets it false, satisfying Economy V1 §2 ("one land use per *successful* mining action") and extending the same treatment to equipment. Cooldown and equipment detachment run regardless, so a failure never strands equipment on its miner.

Land with `unlimited_durability` never has durability read or written, in any mining type.

### 7.5 Free-play land

Free-play land requires the player to **own** a miner; RNG decides which miner *types* are eligible. `fprotate` rolls a weighted selector from `fpselectors` once per `rotation_period_sec`, and `mine` rejects a miner whose `miner_type` doesn't match `freeplaystat.current_allowed_selector`.

`fpselset` rejects any selector value that doesn't match a configured `minerconf.miner_type`, and `minerdel` refuses to remove the last template of a type a selector still references. Without both guards an admin could weight a tier nobody can own, and the window it won would lock every player out until the next rotation.

Weights are relative, so fractional percentages are expressed out of a scale (V1 uses 10,000). **Omitting a tier re-normalizes the rest** — a partial pool does not preserve the intended distribution.

The same hourly ORNG callback also writes `ftconfig.withdraw_fee_pct`, selecting a uniform whole number in **5–9%** from a separate 64-bit lane.

---

## 8. Custody and asset lifecycles

Nothing in a player's wallet is game-usable until deposited. The contract holds all deposited NFTs and FT.

| Asset | Lifecycle | Exit path |
|---|---|---|
| **Miner** | Reusable. Deposit → optional initialize → place → mine. | `wdrawminer` — handles both initialized idle rows and uninitialized deposits; removes a placed miner first. Blocked during an active mine. |
| **Land** | **Consumable.** Wallet transfer + `activateland` submitted atomically in one signed transaction; the physical NFT is **burned immediately at activation**, leaving a logical row. | None. Destruction deletes the row without a second burn. Depletion at zero durability erases it. |
| **Equipment** | **Consumable.** Wallet transfer + `equipstake` atomically; validates the deposit, **burns the NFT**, creates the durable logical row. `equipadd` rejects equipment that hasn't passed through `equipstake`. | None. Destroy removes only the logical row. Depletion erases it. |
| **Slot-unlock NFT** | Burn-to-unlock. Found in wallet or deposits; wallet-held NFTs run transfer + `unlockslot` atomically. | None — burned. |
| **Gold (NFT currency)** | Intercepted at transfer, **burned on the spot**, credited 1:1 to the `goldbalance` counter. Writes **no** `deposits` row, so it costs zero RAM. | `wdrawgold` debits first, then mints configured Gold NFTs back. Capped at 20 per transaction. |
| **FT** | Credited to `accounts.balances`. | `wdrawft` — see §9. |

Deposits are bounded by `MAX_PENDING_DEPOSITS` (50). The `deposits` row written from a notification handler is the only user-scoped row the contract pays RAM for — the chain forbids billing an unauthorized sender during notify. `claimdeps` lets a player take that RAM over.

`templateuse` tracks live custody per template so configuration still backing real NFTs cannot be deleted or silently changed.

---

## 9. FT economics

### Where the money is

**All FT sits in the contract account.** It arrives one way — a transfer from `ftconfig.fee_account` with memo `rewardpool`. Any other sender with that memo **fails the transaction**; the fee account transferring *without* the memo is credited as its ordinary in-game balance.

`rewardpool.available` is a counter of unreserved liquidity, not a separate wallet.

### Reservation model

`mine` and `craft` reserve the **maximum possible** payout from `rewardpool.available` before requesting RNG, so contract FT liabilities can never exceed funded reserves and concurrent pending requests cannot reserve the same funds. Unused reserve is released at resolution (`release_reward`). An underfunded request fails **before** consuming gameplay state.

Under Economy V1 the peak reservation is `195 × 2.60 × 1.15 = 583.05 FT` per concurrent mine.

### Withdrawal

`wdrawft(owner, quantity, fee)` recomputes the fee from current config and **strictly rejects a mismatch**, defending against stale frontends. Then:

```
net       = quantity − fee                       → player wallet
referral  = min(bps_of(quantity, referral_withdraw_pct), fee)   → referrer
platform  = fee − referral                       → ftconfig.fee_account
```

The referral share is **carved out of the collected fee, never added on top** — a referred player receives exactly the same net as an unreferred one, and the withdrawal creates no unfunded liability. `ftconfigset` bounds `referral_withdraw_pct` to **5%**, the floor of the hourly 5–9% fee roll, so the carve stays solvent whatever the roll produces. A runtime clamp and an `is_account` check fold the share back into the platform fee when a referrer is unusable.

### ⚠ Sinks do not refill the pool

`add_reward_pool` is called only from the `rewardpool` memo path and from `release_reward`. The two FT sinks — **healing** and **crafting** — debit the player's ledger but never call it. Consequence: those tokens stay physically in the contract while `rewardpool.available` doesn't move, so the pool only ever drains and needs manual top-ups, while sink revenue accumulates unaccounted. There is no admin FT sweep, and `wipeall` returns only the *accounted* pool — anything above it is stuck.

Not a security hole; nobody can take it. Options: route sinks back via `add_reward_pool()` in heal and craft; add an admin sweep; or accept sink FT as effectively burned and budget for permanent top-ups. **Undecided.**

---

## 10. Crafting (Smithy)

Recipes are scoped by `category` (`miners`, `equipment`, `land`, `essentials`).

**Inputs:** `ReqFT { quantity }`, `ReqNFT { template_id, amount, burn }`, and `gold_amount` (scalar). Gold is charged from the `goldbalance` counter — it **cannot** be expressed as a `ReqNFT` because deposited Gold is burned into a counter and never creates a `deposits` row. `recreqaddgld` **sets** the price rather than accumulating; 0 clears it.

**Outputs:** weighted `RuleItem`s inside `craftrules`, referenced by `recipe.rule_ids`. `total_weight` is recomputed inside the same `modify` that changes the items so the cache cannot drift. `recipe_ref_count` blocks deleting a rule still attached to a recipe.

**Two resolution paths:**

- **Deterministic** — when every positive-weight outcome across all referenced rules resolves to the same FT/NFT result (including duplicate identical rows), `craft` validates, deducts and mints in the same transaction with **no ORNG**. Any mint failure rolls the whole transaction back.
- **Random** — recipes with genuinely different outcomes reserve the maximum FT result, request ORNG, resolve to `claimable`, and are collected with `craftclaim`.

Input validation happens entirely before anything is consumed: recipe exists and is in its `[start_ms, end_ms]` window; rules exist and carry weight; every supplied asset is a non-duplicate, unlocked deposit in the caller's scope; supplied assets cover `nft_inputs` exactly, by template, with no unrequested extras.

---

## 11. Configuration seeding

`scripts/seed-config.sh testnet|mainnet` is the complete fresh-deployment seeder. It contains **no keys** and requires an already-unlocked cleos wallet.

Guards: exact chain-ID validation; required accounts must exist; refuses a non-empty deployment unless `SEED_RESUME=YES`; mainnet requires `CONFIRM_MAINNET=YES` and refuses the disposable test treasury default; `CLEOS_TIMEOUT` (45s) turns a stalled endpoint into an explicit error; every submitted action prints its payload.

It seeds: global/FT/NFT/ToS config, miner tiers, equipment tiers, paid and free-play lands with display metadata, Normal Mining, slot rows, free-play weights, and all deterministic Smithy recipes. FT amounts render at the configured symbol precision.

**Ordering constraint:** `fpselset` calls must follow `minerset` — the contract rejects a selector that doesn't match a configured miner type.

**Missing-template guard:** the four Economy V1 tiers with no minted template (Artifact Miner, Legendary Miner, Epic Equipment, Legendary Equipment) have no safe default — a guessed ID silently configures a nonexistent template and the contract cannot detect it. The seeder refuses to run without them; `ALLOW_MISSING_TIERS=YES` seeds the rest with a warning; mainnet refuses it outright.

Reward funding, `fpstart`, permissions and maintenance-off remain deliberate post-verification operations.

### Admin recovery actions

**`resetuser(account)`** — admin-only, maintenance-only. Preserves all configuration and reward funding while removing one player's registration, ToS acceptance, balances, Gold, slots, activated lands, miners, equipment, cooldowns, deposits, craft state, occupancy, referrals and block record. Physical deposited/miner NFTs are returned, in-game FT is refunded without a fee, already-burned land/equipment records are deleted. Pending reservations return to the pool and their ORNG associations are cancelled; a delayed callback is then rejected as an obsolete unknown ID. Batch-bounded for CPU safety.

**`wipeall(recipe_scopes)`** — requires contract authority, maintenance mode, zero registered users, zero pending ORNG associations, and zero NFT custody. Erases all global configuration, templates, display metadata, mining types, matches, slots, selectors, recipes/rules, craft counters, ToS, referrals, block records and free-play state. The accounted reward pool is returned to the fee account first. Code and ABI stay deployed.

**`blockset`/`blockdel`** — blocked accounts cannot accept ToS, register, deposit, withdraw, unlock slots, manage assets, use the keeper, mine, heal, craft, claim, or invoke any player action.

---

## 12. Security model

- Player writes require player authority, current ToS, non-maintenance state, and a non-blocked account.
- Admin configuration requires contract authority. No config table introduced by generalization has a weaker auth model than the one it replaced.
- `receiverand` accepts only `orng.wax` and only known association IDs.
- Mining economics/destruction terms and crafting result rules are snapshotted before asynchronous RNG.
- Independent RNG outcomes consume non-overlapping checksum lanes.
- Contract FT liabilities cannot exceed the funded reward pool; maximum liabilities are reserved up front.
- NFT deposits are bounded and collection/template validated; `templateuse` prevents deleting or silently changing live configuration.
- Every destructive path burns the real AtomicAssets NFT, never a row-only deletion.
- Withdrawal fees are recomputed and strictly matched on-chain.
- Recipe/rule references and pending mining-type requests block unsafe deletion.
- All token arithmetic uses `int128_t` intermediates or checked `asset` ops.
- RAM discipline: the beneficiary of a row pays for it; contract-scoped rows are `_self`-paid only for admin-authored data.
- On any early-return inside `receiverand`, no `mines`/`crafts` row is left stuck — it is resolved or cleared.

### Invariants

1. FT in `accounts[*].balances` + reserved ≤ FT held by the contract account.
2. Every `miners.plot_id != 0` has a matching placement record.
3. Every listed land has `is_freeplay == false`.
4. `unlocked_land_slots >= 1` for any account that accepted ToS.
5. At most `config.max_freeplay_lands_per_account` free-play lands per account.
6. Every `rngassocs` row corresponds to an active mine, craft, or the free-play rotation.
7. No miner in an active mine/occupancy row can be withdrawn.
8. `referrals` is append-only.
9. `equipment.miner_asset_id != 0` iff equipped.
10. `durability_remaining == 0` implies the row was deleted in the same transaction.
11. Every `mines` row carries a `mining_type_id` enabled at `mine` time.
12. `unlimited_durability` implies no durability decrement ever occurs.
13. Free-play selectors always reference a configured `minerconf.miner_type`.

---

## 13. Known open issues

Verified against the current source on 2026-08-13. Findings from the old `code_review.md` that have since been fixed or designed away are **not** repeated here.

| # | Severity | Issue |
|---|---|---|
| **K1** | **High** | **`tosdel` can brick the contract.** `latest_tos_version()` asserts when no version exists, and it is called by `check_tos_accepted`, which every player action **and both notification handlers** run. Deleting the last ToS version stops all gameplay and makes every inbound NFT/FT transfer abort. Deleting a *newer* version silently re-validates everyone who accepted only an older one. **Fix:** refuse `tosdel` when it would remove the highest or only version. |
| **K2** | **High** | **An unresolved craft locks its inputs forever.** `craft` sets `deposits.locked = true` on non-burn inputs; only `craftclaim` clears it, and that requires the oracle callback. If `receiverand` never arrives, the craft stays `CRAFT_PENDING` and the NFTs are permanently unusable and un-withdrawable — the FT inputs are already gone. `resetuser` is an admin escape, not a player one. **Fix:** a `craftcancel(owner, assoc_id)` with a timeout measured from `rngassocs.request_time`. The same escape is worth having for a stuck `mines` row. |
| **K3** | **Medium** | **`nftconfigset` does not validate template collisions.** It accepts any `template_ids` without checking them against `minerconf`/`equipconf`/`landconf`. `on_nft_transfer` classifies currency **first** and burns on sight, so pointing the Gold config at a Miner template means every deposit of that miner is burned and credited as Gold — irreversible, from one admin typo, with no confirmation. **Fix:** reject overlap in both directions, and freeze the template set once players hold Gold. |
| **K4** | **Medium** | **`listland` has no occupancy check** while `unlistland` and `removeland` both do. A landlord whose own miner sits on the plot can list it; every cross-player `mine` then fails with "another miner is already on that land". Not fund-loss, just an unusable listing. |
| **K5** | **Medium** | **`ruleitemadd` does not validate NFT result templates.** It checks only `template_id >= 0 && schema_name != 0`, never that the template exists in the collection or that the schema matches. A wrong template makes the inline `mintasset` in `craftclaim` fail — and the inputs were already consumed at `craft` time, leaving a permanently unclaimable craft. **Fix:** validate against `atomicassets::templates`, as `wdrawgold` already does. |
| **K6** | **Medium** | **Reward-pool sinks are one-way** — see §9. Economic decision, not a code defect. |
| K7 | Low | `wdrawminer` and `claimdeps` loop over caller-supplied vectors with no batch cap, inconsistent with `MAX_DEPOSIT_BATCH` elsewhere. Self-limiting because the caller pays CPU. |
| K8 | Low | `landdef` is write-only by design — frontend display metadata the contract never reads. |
| K9 | Low | Equipment cooldown is not independently configurable; surviving equipment inherits the miner's resolved cooldown. Diverges only for a miner whose cooldown isn't 3,600s (e.g. a 7,200s Artifact). |

### Not yet done

- **No test suite.** `tests/` holds only the CDT Dockerfile, the ABI normalizer, and static checks. Highest-value cases: double `mine` during the RNG window; resolution with insufficient health; landlord raising commission mid-flight; two miners on one plot; `unlistland` while occupied; over-healing; craft with wrong/extra/missing NFTs; deposit before ToS; the Gold round-trip; concurrent reward reservations.
- **No independent security audit or economic review.** Both are prerequisites for mainnet.
- **Live integration tests** for deposits, burns, withdrawal, mine failure/death/drop, crafting, expired content, public-land commission, referral cycles, free-play rotation and oracle callbacks.
- **Custody reconciliation** of contract-held FT/NFT against player balances, deposits, active items and reserved liabilities.

Compilation and static checks do not replace adversarial review or live integration testing. **Mainnet is out of scope until both are complete.**

---

## 14. Extension points

The architecture accommodates these without redesign:

| Feature | Where it hangs |
|---|---|
| Guilds | New `guilds` + `guildmembers` tables; an optional guild-tax step in the waterfall |
| Bosses / Dungeons | A `miningtypes` row with `special_modifiers` keys; loot via existing `craftrules` |
| Dangerous mining | Already supported — set `failure_chance`, `death_chance`, `decay_on_failure`, damage multipliers |
| Seasonal events | Time-windowed `miningtypes` rows plus the crafting `start_ms`/`end_ms` pattern |
| PvP | New tables and actions; touches nothing in mining/crafting |
| Rentals | Optional `rented_to` on `lands`/`miners` + a `rentals` table; the occupancy pattern is directly reusable |
| Marketplace | Off-contract or a new `listings` table; custody already models the NFT movement |
| Land / equipment upgrades | A recipe-shaped table reusing the crafting Req/Res pattern |
| Pets / vehicles | A `*conf` table shaped like `equipconf`, plugged in as another multiplicative term — the reward formula is already an extensible product |
| Achievements / battle pass | Observers of existing `logmine`/`logcraft`/`logheal` traces |
| Leaderboards | Off-chain indexer aggregation over `logmine` |
| Additional currencies | Another `ftconfig`/`nftconfig`-shaped singleton; the waterfall already reads currency identity from config |
| Cross-chain | Isolated to the deposit/withdrawal boundary |

---

## 15. Rules for anyone (human or AI) working on this contract

1. **Never hardcode a gameplay value.** If it affects rewards, chances, costs, durability, health or cooldowns, it belongs in a config table.
2. **Prefer configuration over new code paths** for content variety.
3. **Every new mechanic ships with its admin CRUD** in the same change.
4. **Every irreversible action needs frontend confirmation** before signing.
5. **Prefer additive table/field changes.** A field added to a live struct requires the wipe-first deploy order in §2.
6. **Check the physical-name table (§3)** before adding an action or table — 12 characters is the cap.
7. **Snapshot before RNG.** Anything economic or destructive must be captured into the pending row, never re-read at resolution.
8. **Use non-overlapping RNG lanes** for independent outcomes.
9. **Add tests for every feature**, including documented failure paths.
10. **If a field, parameter, memo format, invariant or business rule you need is not in this document — stop and ask.** Do not guess.
