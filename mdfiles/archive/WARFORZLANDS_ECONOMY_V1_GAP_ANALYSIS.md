# WarForz Lands — Economy V1 Gap Analysis

Date: 2026-08-13
Baseline economy: `WARFORZLANDS_ECONOMY_CONFIG_V1.md`
Code reviewed: `SC/mininggame/src/warforzlands.cpp`, `SC/mininggame/include/warforzlands.hpp`, `scripts/seed-config.sh`

## Implementation status (updated 2026-08-13)

| Gap | Status |
|---|---|
| A1–A6 seeder values | **Done** — `scripts/seed-config.sh` rewritten to V1 |
| B2 additive Gold chance + land bonus + 10% cap | **Done** |
| B3 Gold craft costs (`recreqaddgld`) | **Done** |
| B4 per-miner health damage | **Done** |
| B5 equipment cooldown | Not changed (low severity, see below) |
| D4 land uses on failed mines | **Done** — now a per-mining-type `decay_on_failure` flag covering Land **and** Equipment |
| B1 free-play design | **Resolved** — free-play keeps requiring an owned Miner; RNG picks eligible types across all six configured `minerconf` tiers. Selectors are now validated against `minerconf`. |
| D1 random 5–9% withdrawal fee | **Kept** at product direction |
| D3 mining fee / referral rate | Mining fee stays 0; mining referral retained but seeded 0. **Done** — new withdrawal referral carved out of the platform fee, capped at 5% |
| C1 missing AtomicAssets templates | **Outstanding** — external prerequisite |
| C2 dedicated test FT token | **Outstanding** — external prerequisite |
| D2 slot-unlock pricing | **Outstanding** — placeholders seeded, need confirmation |

Verified: CDT 3.1.0 compiles clean (only the pre-existing Ricardian packaging warnings); static checks pass at 65 actions; ABI carries all four new fields; frontend `tsc -b` and Vite production build pass; all six V1 §10–11 worked examples reproduce exactly under the new formulas.

Not verified: nothing has been deployed or seeded on-chain. That needs C1 and C2 first.

---

## Verdict

Economy V1 **cannot be delivered by configuration alone.** Roughly 60% of it is a seed-script rewrite, but five rules require changes to the contract's data model or reward math, and one requires a mechanic that does not exist yet.

| Category | Items | Effort |
|---|---|---|
| **A. Config only** — rewrite `seed-config.sh` values | 6 | Low |
| **B. Contract code changes** — new fields, new action, changed math | 5 | Medium–High |
| **C. Content prerequisites** — AtomicAssets templates | 2 | Low (external) |
| **D. Open product decisions** — V1 doesn't say, or conflicts with built behavior | 4 | Needs your call |

Nothing here is a defect in the existing build. The contract was configured against an earlier balance pass; V1 changes both the numbers *and* several formulas.

---

## A. Config-only gaps (seed script rewrite)

These need no C++ change. All are in `scripts/seed-config.sh`.

### A1 — Miner stats are stale on every field

`seed-config.sh:75-78` versus V1 §5:

| Field | Current (Common→Epic) | V1 target | Note |
|---|---|---|---|
| `health_max` | 100 / 150 / 225 / 350 | **200 flat** | all rarities equal in V1 |
| `base_reward_rate` | 0.1 / 0.2 / 0.4 / 0.8 | **55 / 85 / 120 / 155** | whole tokens; the contract scales by symbol precision |
| `base_nft_drop_rate` | 0.005 / 0.01 / 0.02 / 0.04 | **0.05 / 0.04 / 0.03 / 0.02** | **direction is inverted** — see below |
| `cooldown_sec` | 3600 / 3000 / 2400 / 1800 | **3600 flat** (7200 for Artifact) | |
| `health_cost_per_point` | 0.001 → 0.005 | **5.00000000 flat** | V1 §4: 5 FT per HP |

The inversion is the substantive one. The deployed config rewards higher rarity with a **higher** Gold chance; V1 §16 states the opposite — *"Higher rarity = Lower Gold probability"* — because Legendary is meant to produce FT while Common is the Gold farm. This is a deliberate design reversal, not a typo, and it flips the whole progression incentive.

### A2 — Artifact/F2P and Legendary miner rows are missing

`minerconf` has 4 rows. V1 §5 defines 6 tiers. Artifact (27 FT, 0.50%, 7200s) and Legendary (195 FT, 1.50%, 3600s) have no configuration. Both are required: Legendary is in the F2P RNG pool even though V1 §1 makes it non-craftable.

### A3 — Equipment stats stale, and two tiers missing

`seed-config.sh:80-82` versus V1 §6:

| Field | Current (Common/Uncommon/Rare) | V1 target |
|---|---|---|
| `durability_max` | 100 / 200 / 350 | **125 for all five tiers** |
| `reward_boost` | 1.05 / 1.1 / 1.2 | **1.35 / 1.60 / 1.90 / 2.25 / 2.60** |
| `nft_drop_boost` | 0.05 / 0.1 / 0.2 | **0.025 / 0.020 / 0.015 / 0.0075 / 0.0025** |

Epic and Legendary equipment do not exist in config. Note the same inversion as miners: V1 makes Common equipment the Gold-focused tier and Legendary nearly Gold-free.

*The `nft_drop_boost` values above assume the additive semantics of gap B2. Under the current multiplicative formula these numbers produce different results — see B2.*

### A4 — Land durability and boost stale

`seed-config.sh:84-87` versus V1 §2:

| Land | `durability_max` now | V1 | `land_bonus` now | V1 |
|---|---:|---:|---:|---:|
| Epic | 500 | **75** | 1.25 | **1.10** |
| Legendary | 750 | **300** | 1.5 | **1.12** |
| Diamond | 1000 | **600** | 2.0 | **1.15** |

Land uses are cut sharply and the FT boost drops from 25–100% to 10–15%. `land_bonus` is stored as a multiplier, so V1's "+10% FT" is `1.10`; the contract already applies it multiplicatively at `warforzlands.cpp:1795`, matching V1's formula.

### A5 — Free-play selector weights don't match the V1 pool

`fpselectors` holds common 50 / uncommon 30 / rare 15 / epic 5. V1 §3 defines six entries including fractional percentages. Weights are relative `uint32_t`, so fractions are expressible by scaling — no contract change needed for the *weights*:

| Selector | V1 chance | Weight (÷10,000) |
|---|---:|---:|
| artifact | 55% | 5500 |
| common | 25% | 2500 |
| uncommon | 12% | 1200 |
| rare | 6% | 600 |
| epic | 1.75% | 175 |
| legendary | 0.25% | 25 |

The weights are config-only. The *mechanic* those weights drive is not — see **B1**.

### A6 — Craft costs are placeholders

All 13 recipes in `seed-config.sh:120-132` use round WAX amounts (5, 10, 20, 40…) unrelated to V1 §1. The FT halves of V1 pricing (5,000 / 18,250 / 23,150 / 32,500 FT for miners, etc.) are expressible today. The Gold halves are not — see **B3**.

---

## B. Contract code changes required

### B1 — F2P is a different mechanic, not a different number ⚠ largest item

**V1 §3** specifies: the player starts a mine on F2P land with **no miner of their own**; an RNG roll picks a temporary miner tier; that tier's reward config is used; the temporary miner disappears afterward. The player never owns it.

**What exists** (`warforzlands.cpp:1725-1730`) is an *hourly global window*: `fprotate` rotates `freeplaystat.current_allowed_selector` once per hour via ORNG, and mining on free-play land asserts the player's **own** miner matches that selector. The frontend filters the expedition inventory to matching owned miners and blocks mining otherwise.

These differ on every axis that matters:

| | V1 | Built |
|---|---|---|
| Roll frequency | per mine | per hour, global |
| Miner ownership | not required | **required** |
| Player experience | always minable | locked out unless you own the current tier |
| Purpose | free on-ramp for new players | rarity rotation for existing owners |

The built version defeats V1's stated purpose — *"Free entry into the ecosystem"* — because a brand-new player with zero miners cannot mine at all.

**Work required:** a per-mine selection path for free-play land that rolls a tier from `fpselectors`, resolves that tier's `minerconf` row for reward/drop/health values, and runs the mine without a `miners` row. Touches `mine()` (which currently requires a placed miner asset), the `mine_s` snapshot, the ORNG resolution path (health/cooldown/durability decay all assume a real miner row), plus the frontend expedition modal. Also needs a decision on whether the hourly rotation and its coupled withdrawal-fee roll survive — see **D1**.

### B2 — Gold-chance formula is multiplicative; V1 is additive, with no cap

`warforzlands.cpp:1786`:

```cpp
double effective_nft_rate = mc->base_nft_drop_rate * (1.0 + equipment_nft_boost) + mt->nft_drop_bonus;
```

V1 §8 requires:

```text
Final Gold Chance = Miner + Equipment + Land   (capped at 10%)
```

Three separate defects against V1:

1. **Equipment is multiplicative, not additive.** V1 §10's own worked example — Common miner 5.00% + Common equipment 2.50% = **7.50%** — evaluates to `0.05 × 1.025 = 5.125%` under the current code. Every V1 example is wrong on the deployed math.
2. **Land contributes nothing.** `landconf_s` (`warforzlands.hpp:256-267`) has no Gold-chance field at all. V1 gives Epic/Legendary +1.00% and Diamond +1.25%. This needs a **new field on the table and on `landset`** — an ABI change.
3. **No 10% cap.** The code clamps to `[0.0, 1.0]`, i.e. 0–100%. V1's global cap is 10%. Recommend a `max_nft_drop_rate` field on `config_s` rather than a hardcoded constant, consistent with the project's config-driven design.

### B3 — Crafting cannot charge Gold

Every craft price in V1 §1 is Gold + FT. The contract supports only two input kinds — `ReqFT` (fungible) and `ReqNFT` (deposited NFT by template), `warforzlands.hpp:101-112` — and `craft()` consumes exactly those (`warforzlands.cpp:2263`, `2265`). `warforzlands.cpp:1278` records the intent as unfinished: *"Gold cost is reserved."*

The `ReqNFT` route is **structurally unavailable** as a workaround. Incoming Gold NFTs are intercepted at transfer, burned on the spot, and credited to the `goldbalance` singleton without ever writing a `deposits` row (`warforzlands.cpp:1171-1176`). A recipe requiring Gold-as-NFT-input could never be satisfied.

**Work required:** a `gold_amount` field on `craftrecipe_s`, a `recreqaddgold` admin action, a `goldbalance` debit inside `craft()` ordered with the existing FT deduction and reward reservation, plus ABI, seeder, and Smithy UI updates. The debit helper already exists (`warforzlands.cpp:232`).

### B4 — Health damage is per mining-type, not per miner

V1 §5 sets damage by rarity: −5 / −10 / −15 / −20 / −25 / −30 HP. The contract reads a single `health_cost` from the **mining type** (`warforzlands.hpp:228`), snapshots it at `warforzlands.cpp:1820`, and applies it at `2089`. One value for every miner.

Two routes: add `health_cost_per_mine` to `minerconf_s` (correct, ABI change), or define six mining types (config-only, but it forces the player to pick a "mining type" that is really their miner's rarity, and multiplies every compatibility list). **Recommend the field.**

### B5 — Equipment cooldown is not independently configurable

V1 §6 lists equipment cooldown at 3,600s. `gearconf_s` (`warforzlands.hpp:242-252`) has no cooldown field; surviving equipment inherits the miner's resolved cooldown (`warforzlands.cpp:2076`). Harmless for the five paid tiers, where 3,600s already matches the miner cooldown — but it diverges for a 7,200s Artifact miner. Low severity; flagging for completeness rather than recommending a change.

---

## C. Content prerequisites

### C1 — Three AtomicAssets templates do not exist

V1 needs Legendary Miner, Epic Equipment, and Legendary Equipment. `seed-config.sh:29-35` maps templates 664504–664521 and includes none of them. These must be created in the `warforzlands` collection before any config referencing them will validate — the contract checks template existence on config write.

### C2 — The FT token is a disposable stand-in, and V1's numbers make that expensive

The testnet FT is `eosio.token` `8,WAX` (`seed-config.sh:21-22`), explicitly disposable per the implementation report. V1's numbers are sized for the real Silver token, and the contract **reserves the maximum possible reward from the funded pool before every mine** (`warforzlands.cpp:1795-1802`).

Worked worst case under V1: `195 FT × 2.60 equipment × 1.15 land ≈ 583 FT` reserved per pending mine. Against `8,WAX` that is **583 WAX locked per concurrent mine**, plus craft reservations. Testing V1 economics on the current configuration is not practical.

**Recommendation:** deploy a dedicated test token with V1's intended symbol/precision before seeding V1 numbers. This is a prerequisite for A1/A6, not a follow-up.

---

## D. Open decisions — V1 is silent or conflicts

### D1 — The randomized 5–9% withdrawal fee is not in V1

`warforzlands.cpp:2126` rolls the withdrawal fee to a uniform whole number in 5–9% every hour, atomically with the free-play rotation. V1 never mentions it; V1 §14 discusses only a possible **2–5% marketplace fee** on a Gold↔FT market that doesn't exist yet.

Three questions: is the random fee still wanted; if so should the range change; and if B1 removes the hourly rotation, where does the fee roll live? A randomized withdrawal fee is also a UX cost — players cannot predict what withdrawing costs.

### D2 — Slot unlock pricing is undefined

V1 §13 lists slot unlocks as an FT sink but sets no price. The seeder invents 25/50/100 (`seed-config.sh:130-132`). Needs Gold+FT figures consistent with the V1 curve.

### D3 — `mining_fee_pct` and `referral_rate` are both 0

`seed-config.sh:25-26` sets both to zero, and V1 doesn't mention either. The waterfall exists and works (`warforzlands.cpp:1989-1998`). Are these intentionally off for V1?

### D4 — Land uses are consumed on failed mines

V1 §2 says *"One land use is consumed per successful mining action."* At `warforzlands.cpp:2031-2047` land durability and equipment durability decay **unconditionally**, outside the `failed || died` guard.

This is currently latent — the only mining type has `failure_chance: 0` and `death_chance: 0`, so every mine succeeds. It becomes a live discrepancy the moment a dangerous mining type is configured. Decide now whether "successful" is binding; if so, the decay needs to move inside the guard.

---

## Recommended sequencing

Ordered so each step is testable and nothing gets seeded twice.

**Phase 1 — decisions and content** (blocks everything else)
1. Resolve D1–D4.
2. Create the three missing AtomicAssets templates (C1).
3. Deploy a dedicated test FT token (C2).

**Phase 2 — contract changes**, one deploy
4. Land Gold-chance field + additive drop formula + configurable cap (B2).
5. Per-miner health damage field (B4).
6. Gold craft costs: recipe field, `recreqaddgold`, craft debit (B3).
7. F2P per-mine temporary-miner selection (B1) — largest item; viable to split into its own deploy.

**Phase 3 — configuration**
8. Rewrite `seed-config.sh` to V1 values (A1–A6) against the new ABI.
9. Re-seed on a wiped testnet deployment via `wipeall` + `seed-config.sh`.

**Phase 4 — frontend**
10. Reward/Gold-chance previews to the additive+capped formula.
11. Smithy Gold costs and balance validation.
12. F2P expedition flow — remove the owned-miner filter, present the temporary-miner roll.

**Phase 5 — verification**
13. Replay every V1 §10–11 worked example on testnet and confirm on-chain output matches to the token unit.

That last step is the real acceptance test: V1 ships five fully worked examples, and each one exercises the miner, equipment, land, Gold-chance, and healing math together.

---

## Separate finding — credential exposure

Not economy work, but it surfaced while reading the project and it controls the deployed contract.

`testnet/testnet.txt` holds cleartext **owner and active private keys** for `warforzlands` and `testingwarfo`, plus the cleos wallet password. The repo root is not under git, so nothing is committed — but these keys have full control of the deployed testnet contract, including `wipeall` and `resetuser`.

Testnet-only, so this is not an emergency. Before anything approaching mainnet: move keys out of the working tree, and never let a mainnet key exist in this format.
