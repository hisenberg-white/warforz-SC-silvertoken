# WAX economy audit — spec vs. live chain

**Every Economy V1 value checked against `warforzlands` on WAX testnet and against `scripts/seed-config.sh`.**

| | |
|---|---|
| Audited | 2026-09-05 |
| Method | Live `get_table_rows` on `https://test.wax.eosusa.io`, diffed against `WARFORZLANDS_ECONOMY_CONFIG_V1.md` and the C++ source |
| Purpose | Establish whether WAX gameplay is correct before porting it verbatim to Robinhood Chain |
| Result | **Core economy is exact. Three divergences found — two of them new, both affecting land.** |

---

## Summary

| Area | Verdict |
|---|---|
| Miner tiers — base FT, Gold chance, health, damage, cooldown | ✅ **Exact match** to V1 §5 |
| Equipment tiers — multiplier, Gold bonus, durability | ✅ **Exact match** to V1 §6 |
| Land durability — 75 / 300 / 600 / unlimited | ✅ **Exact match** to V1 §2 |
| Land **Gold** bonus — +1.00% / +1.00% / +1.25% | ✅ **Exact match**, applies universally |
| Healing — 5 FT per HP, flat | ✅ **Exact match** to V1 §4 |
| Gold chance cap — 10% | ✅ **Exact match** to V1 §8 |
| Normal Mining type | ✅ Correct — no failure, no death, `decay_on_failure` false |
| Reward formula, waterfall, reservation, snapshot-before-RNG | ✅ Correct |
| **Land FT boost** | ✅ **D1 RESOLVED 2026-09-05 — tier-matched kept (Option 2), bands rebalanced.** V1 §2/§17 rewritten; UI work in `WARFORZLANDS_LAND_BAND_UI.md` |
| **Land cooldown** | ✅ **D2 RESOLVED — 3600 s is intended.** Live config is correct; the *docs* and the contract fallback are wrong — see below |
| **Free-play mechanic** | ✅ **D3 RESOLVED 2026-09-05** — the V1 temporary-miner roll and signup NFT are unimplemented features, not defects. Live behaviour stands |
| Mining fee / referral rate | ⚠️ Both `0` — confirm intentional |

**Nothing here is a security defect.** The contract does what its config tells it to. These are configuration and specification problems, and all three are fixable without a redeploy.

---

## ✅ Verified exact

Read live from chain, 2026-09-05:

```
minerconf   common   ft=55  drop=0.05  hp=200 dmg=10 cd=3600   ✅ V1 §5
            uncommon ft=85  drop=0.04  hp=200 dmg=15 cd=3600   ✅
            rare     ft=120 drop=0.03  hp=200 dmg=20 cd=3600   ✅
            epic     ft=155 drop=0.02  hp=200 dmg=25 cd=3600   ✅
            (artifact and legendary not minted on testnet — seeder values match V1)

equipconf   rarity=1 boost=1.35 drop=0.025 dur=125             ✅ V1 §6
            rarity=2 boost=1.60 drop=0.020 dur=125             ✅
            rarity=3 boost=1.90 drop=0.015 dur=125             ✅
            (epic 2.25/0.0075 and legendary 2.60/0.0025 in seeder, not minted)

landconf    epic      dur=75   drop=0.0100                     ✅ V1 §2
            legendary dur=300  drop=0.0100                     ✅
            diamond   dur=600  drop=0.0125                     ✅
            freeplay  unlimited, is_freeplay                   ✅
```

The Gold side of the land economy is correct and universal. Only the FT side is broken.

---

## ✅ D1 — RESOLVED 2026-09-05: tier-matched kept, bands rebalanced

**Decision: Option 2.** The FT boost stays gated by miner type. Economy V1 §2 and §17 have been rewritten to describe that design, the bands widened so no land is dead weight, and the UI work specified in `WARFORZLANDS_LAND_BAND_UI.md`.

| Land | +FT | Old band | **New band** |
|---|---:|---|---|
| Epic | 10% | epic | **common, uncommon, rare** *(artifact excluded — guaranteed loss)* |
| Legendary | 12% | legendary | **uncommon, rare, epic** |
| Diamond | 15% | common, uncommon, rare, epic, legendary | **rare, epic, legendary** |

Rationale: a percentage boost is worth more in absolute FT to a high-output miner, while land costs the same per use whatever mines on it. Pairing better land with better miners keeps each tier meaningful, and the cheapest land stays affordable for entry tiers. Bands overlap so every rarity has at least one land, and Diamond no longer dominates every tier at the best cost-per-use.

Apply with `APPLY=YES FIX_D1=matched ./scripts/fix-economy.sh testnet` (17 actions: 7 deletes, 10 sets).

⚠️ **This is a nerf for Common/Uncommon miners on Diamond Land** (85.39 → 74.25 FT). Ship the UI and announce it before applying. The original analysis is kept below for the record.

---

### Original finding (for the record)

**Severity: High. Directly contradicted the spec's headline land rule.**

### What Economy V1 requires

> §2: "Epic, Legendary, and Diamond lands work with **every miner rarity**. The land boost applies to whichever miner is placed on that land. **Land rarity does not restrict miner rarity.**"
>
> §17: "**Premium land rarity does not determine which miner can be placed on it.**"

### What is live

```
landconf     epic       land_bonus = 1.00     ← no universal boost at all
             legendary  land_bonus = 1.00
             diamond    land_bonus = 1.00

landminmatch epic      → epic       ×1.10     ← Epic land boosts ONLY epic miners
             legendary → legendary  ×1.12     ← Legendary land boosts ONLY legendary miners
             diamond   → common     ×1.15
             diamond   → uncommon   ×1.15
             diamond   → rare       ×1.15
             diamond   → epic       ×1.15
             diamond   → legendary  ×1.15     ← artifact excluded
```

`land_bonus` is 1.00 on every land. The boost was moved into `landminmatch`, which is keyed on **(land_type, miner_type)** — and the pairings only reward matching tiers.

`seed-config.sh:196` states the intent plainly:

> *"`landconf.land_bonus` is deliberately left at 1: it is a UNIVERSAL multiplier that applied to every miner on the land regardless of type, **which is exactly what made premium land boost everything equally**."*

The comment treats universal boosting as a defect being fixed. **Economy V1 defines universal boosting as the requirement.** Someone changed the design and Economy V1 was never updated.

### What players actually get

| Setup | V1 says | Live gives | Shortfall |
|---|---:|---:|---:|
| Common miner + Common gear on **Epic Land** | `55 × 1.35 × 1.10` = **81.70** | `55 × 1.35 × 1.00` = **74.25** | **−10%** |
| Rare miner + Rare gear on **Legendary Land** | `120 × 1.90 × 1.12` = **255.36** | `120 × 1.90 × 1.00` = **228.00** | **−12%** |
| Artifact miner on **Diamond Land** | `27 × 1.15` = **31.05** | `27 × 1.00` = **27.00** | **−15%** |

**Epic Land (3 Gold + 986 FT) is worthless unless you own an Epic miner. Legendary Land (11 Gold + 3,100 FT) is worthless unless you own a Legendary miner.** A player who buys either expecting the advertised boost gets nothing.

### Why nobody caught it

Every worked example in Economy V1 §10 either uses **no premium land** or uses **Diamond Land** — and Diamond happens to be the one land whose match rows cover almost every tier. The spec's own examples all still compute correctly:

```
Epic miner + Legendary gear + Diamond Land
  V1:   155 × 2.60 × 1.15 = 463.45
  live: 155 × 2.60 × 1.00 × 1.15 = 463.45   ✅ identical
```

The divergence is invisible in every example the spec provides. It only appears for the Epic/Legendary land pairings that §10 never demonstrates.

### Also note the asymmetry

Land **Gold** bonus sits on `landconf.nft_drop_bonus` and applies to **every** miner (correct per V1). Land **FT** boost is gated. One half of the land's value is universal and the other half is not — almost certainly unintended.

### Fix — no redeploy needed

**Option 1 — restore the spec (recommended).** Put the boost back where V1 says it belongs:

```sh
# land_bonus carries the universal boost again
landset  epic       land_bonus=1.10
landset  legendary  land_bonus=1.12
landset  diamond    land_bonus=1.15
# remove every landminmatch row, or the boost double-applies
matchdel epic epic; matchdel legendary legendary
matchdel diamond common; matchdel diamond uncommon; matchdel diamond rare
matchdel diamond epic;   matchdel diamond legendary
```

⚠️ **Do both halves together.** Setting `land_bonus` while the match rows remain multiplies them: `1.10 × 1.10 = 1.21`.

**Option 2 — keep the pairing design, update the spec.** If tier-matched bonuses are wanted, rewrite V1 §2 and §17 to say so, and add pairings so no land is dead weight for the tiers likely to use it. Note this makes land purchases tier-locked, which is a real change to the buying decision players make.

---

## ✅ D2 — Land cooldown: 3600 s is the intended design *(resolved 2026-09-05)*

**Not a bug. The live config is correct.** Land rests for **one hour** between mines, matching the miner cooldown.

### What this design means

Land cooldown (3600 s) equals miner cooldown (3600 s), so **one land serves one mine per hour**. The consequences are deliberate:

- **Land scales with miners.** A player running *N* miners continuously needs roughly *N* lands. Land is a per-miner companion, not a shared venue.
- **Listed land earns commission at most once per hour**, which makes listed land scarce and supports a higher commission rate.
- **Artifact miners are miner-bound, not land-bound** — their 7200 s cooldown exceeds the land's 3600 s, so the miner is the binding constraint for that tier.

Cooldown is tracked per **activated land instance** (`landcool`, keyed by asset id) with the duration read from the template, so each player's own land has its own timer. The one-land-per-miner relationship holds per player.

### ⚠️ But three things now disagree with that intent

**1. The contract's fallback default is 300 s — this is a live trap.**

```cpp
static constexpr uint32_t DEFAULT_LAND_COOLDOWN_SEC = 300;   // warforzlands.hpp:85
```

A land template with **no `landcdconf` row falls back to 300 s**, not 3600 s. Today all four templates have explicit rows, so nothing is broken — but **any land template added in future without a matching `landcdset` silently gets 5 minutes instead of an hour**, and nothing will flag it. That is a twelve-fold economy error from one forgotten call.

Options:
- **Always set it explicitly** in the seeder (current behaviour — works, but relies on discipline), **and** add a post-seed assertion that every `landconf` row has a `landcdconf` row.
- **Change the constant to 3600** so the fallback matches intent. Needs a redeploy — fold it into the next one rather than doing it alone.

**2. `WARFORZ_DEPLOYMENT.md` §182 states the wrong default.**

> *"Seeded by `scripts/seed-config.sh` via `LAND_COOLDOWN_SEC` (default 300)."*

The seeder actually defaults to **3600**, which is correct. The doc is wrong and should be amended.

**3. The §182 rework rationale now reads as contradicting the design.**

That section frames the old behaviour — *"one mine per land per hour, no matter how many miners you owned"* — as the problem being fixed. Under the confirmed design that behaviour is the **intent**. What the rework actually delivered and should be credited with is making land cooldown **independently configurable per template** rather than inherited from the miner. Reword it so a future reader does not "fix" 3600 back down to 300.

**4. Economy V1 does not mention land cooldown at all.**

It is currently defined only inside a shell script. Add it to §2 alongside uses, boost and Gold chance so the seeder has a spec to be checked against.

## ✅ D3 — Free-play mechanic *(resolved 2026-09-05)*

**Decision: the live behaviour stands.** Economy V1 §3's per-attempt temporary-miner roll, and the signup NFT that would give a new player their first miner, are **features that were never built** — not regressions. The contract's model (own a miner, global hourly tier gate) is the shipped game, and both chains implement it.

Economy V1 §3 and §11 should still be reworded so they describe the shipped mechanic rather than an unbuilt one.

⚠️ **Two live operational issues remain, independent of the design decision:**

1. 🔴 **The rotation is stuck.** `freeplaystat.window_ends_at` = **2026-08-17**, `rotation_assoc_id` = 0. `fprotate` has not run in 19 days, and `mine()` never checks whether the window expired — so free-play has been **Rare-only since 17 August**. Start `testnet/fprotate-keeper.sh`, and add an alarm: a keeper that can silently stop for three weeks is the real defect. Consider having `mine()` reject a stale window rather than honouring it forever.
2. 🟠 **Weights re-normalise.** Only 4 of 6 selectors are seeded (artifact and legendary were never minted), so the live total is **4,475 not 10,000** and every present tier runs at ~2.2× its intended share — Common at 55.9% instead of 25%. Either mint the missing tiers or restate the weights for a four-tier pool.

### Original finding (for the record)

## ❌ D3 — Free-play mechanic

Fully documented in **`WARFORZLANDS_FREEPLAY_GAP.md`**. In short: Economy V1 §3 describes a per-attempt temporary-miner roll requiring no ownership; the contract implements a global hourly miner-type gate requiring ownership. The `fpselectors` weights were transplanted from the first mechanic into the second, where they act as a lockout schedule.

---

## ⚠️ Mining fee and referral rate are both zero

```
config  mining_fee_pct   = 0.0
        referral_rate    = 0.0
        max_nft_drop_rate = 0.10          ✅ matches V1 §8
```

Two of the reward waterfall's four steps are inert; the miner receives 100% minus landlord commission. Economy V1 does not specify these values, so this is not strictly a divergence — but `WARFORZLANDS_CONTRACT.md` §7.3 documents a four-step waterfall and Economy V1 §13 lists protocol fees among the FT sinks. **Confirm 0/0 is the intended launch economy rather than a testnet placeholder.**

---

## Impact on the Robinhood Chain port

The port's ground rule is **exact gameplay parity with WAX**. So:

- **The ✅ items are locked in** — miners, equipment, land durability, land Gold bonus, healing, the Gold cap, Normal Mining, the reward formula and waterfall are copied verbatim. That is the large majority of the economy.
- **D1, D2 and D3 must be settled on WAX first.** The port implements whatever WAX ends up with. Porting them as-is would faithfully reproduce three bugs on a second chain.
- `economy.v1.json` — the shared source of truth for both seeders — cannot be finalised until D1 and D2 are decided.

---

## Recommended order

1. **D2 — no chain change needed.** Live config is already correct. Do the four documentation fixes above, and add the post-seed assertion that every `landconf` row has a `landcdconf` row so the 300 s fallback can never be hit silently.
2. **D1 — needs your decision.** Universal vs. tier-matched, then either three `landset` calls plus seven `matchdel`s, or a spec rewrite. **Do not half-apply it** — the two multipliers compound to 1.21 and would exceed the reserved maximum.
3. **D3 last.** It needs a design decision, and if you choose Economy V1's model it needs contract work on `mine()`.
4. **Confirm the fee/referral zeros.**
5. **Re-run this audit** after the changes and record the result.

Only D1 touches the chain, and only D3 Option B needs a redeploy.

---

## Verification commands

```sh
cleos -u https://test.wax.eosusa.io get table warforzlands warforzlands landconf
cleos -u https://test.wax.eosusa.io get table warforzlands warforzlands landminmatch
cleos -u https://test.wax.eosusa.io get table warforzlands warforzlands landcdconf
cleos -u https://test.wax.eosusa.io get table warforzlands warforzlands minerconf
cleos -u https://test.wax.eosusa.io get table warforzlands warforzlands equipconf
cleos -u https://test.wax.eosusa.io get table warforzlands warforzlands config
```
