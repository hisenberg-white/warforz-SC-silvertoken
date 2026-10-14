# WARFORZLANDS – ECONOMY CONFIGURATION V1

**Temporary balancing exchange rate:**  
**1 Gold = 1,000 FT**

> This rate is only for internal balancing. The live Gold ↔ FT market ratio can become dynamic later.

---

# 1. Craft Costs

## Miners

| Miner | Gold Cost | FT Cost |
|---|---:|---:|
| Common | **13 Gold** | **5,000 FT** |
| Uncommon | **22 Gold** | **18,250 FT** |
| Rare | **30 Gold** | **23,150 FT** |
| Epic | **35 Gold** | **32,500 FT** |
| Legendary | **—** | **—** |

**Legendary Miner:** Not directly craftable in V1 unless a separate acquisition method is later defined.

---

## Equipment

| Equipment | Gold Cost | FT Cost | Uses |
|---|---:|---:|---:|
| Common | **3 Gold** | **1,800 FT** | **125** |
| Uncommon | **3 Gold** | **2,500 FT** | **125** |
| Rare | **5 Gold** | **4,500 FT** | **125** |
| Epic | **7 Gold** | **7,000 FT** | **125** |
| Legendary | **10 Gold** | **8,900 FT** | **125** |

---

# 2. Land Configuration

| Land | Uses | Gold Cost | FT Cost | FT Boost | Additional Gold Chance | Land Cooldown | Boost applies to |
|---|---:|---:|---:|---:|---:|---:|---|
| **F2P / Artifact Land** | — | **Free** | **Free** | **0%** | **0%** | **1 hour** | — (RNG-selected miner only) |
| **Epic Land** | **75** | **3 Gold** | **986 FT** | **+10% FT** | **+1.00%** | **1 hour** | **Common, Uncommon, Rare** |
| **Legendary Land** | **300** | **11 Gold** | **3,100 FT** | **+12% FT** | **+1.00%** | **1 hour** | **Uncommon, Rare, Epic** |
| **Diamond Land** | **600** | **21 Gold** | **5,150 FT** | **+15% FT** | **+1.25%** | **1 hour** | **Rare, Epic, Legendary** |

---

## Premium Land Rules

- **Land is tier-matched.** Each premium land grants its FT boost only to the miner rarities listed in the "Boost applies to" column above. A miner outside that list may still be placed and mined — it simply receives **no FT boost** from that land.
- **The Gold chance bonus is universal.** Unlike the FT boost, a land's additional Gold chance applies to **every** miner placed on it, regardless of rarity.
- Bands deliberately **overlap**, so every *paid* miner rarity has at least one land that boosts it, and the mid tiers have both a budget and a premium option.
- ⚠️ **The Artifact miner is excluded from every band, on purpose.** It grosses 27 FT while the cheapest premium land costs 43.6 FT per use — so **even with a boost applied it loses 24–33 FT per mine**. Listing it in a band would advertise a bonus that leads players into a guaranteed loss. **Artifact miners belong on F2P land.** See `WARFORZLANDS_PROFITABILITY.md` §3.
- One land use is consumed per **successful** mining action.
- Changing the miner does not reset remaining land uses.
- Land FT boost is applied after the equipment multiplier.
- Land Gold chance is added to the miner and equipment Gold chance.
- Total Gold chance is subject to the global Gold chance cap.
- **Land cooldown is 1 hour**, equal to the standard miner cooldown. One land therefore serves one mine per hour, so a player mining continuously needs roughly one land per miner.

### Why tier-matched

A percentage boost is worth more in absolute FT to a high-output miner, while land costs the same per use whatever mines on it. Pairing better land with better miners keeps each land tier economically meaningful for the players who buy it, and keeps the cheapest land affordable for the entry tiers.

### Coverage matrix

| Miner | Epic Land | Legendary Land | Diamond Land |
|---|:---:|:---:|:---:|
| Artifact | — | — | — |
| Common | **+10%** | — | — |
| Uncommon | **+10%** | **+12%** | — |
| Rare | **+10%** | **+12%** | **+15%** |
| Epic | — | **+12%** | **+15%** |
| Legendary | — | — | **+15%** |

### FT Formula With Premium Land

```text
Final FT Reward =
Miner Base FT
× Equipment Multiplier
× (1 + Land FT Boost)      <- only if the miner's rarity is in the land's band;
                              otherwise this term is 1.00
```

### Gold Chance Formula With Premium Land

```text
Final Gold Chance =
Miner Gold Chance
+ Equipment Gold Bonus
+ Land Gold Bonus          <- always applies, regardless of miner rarity
```

---

# 3. F2P / Artifact Land

The F2P Land is the free-entry mining land.

It provides:

- **0% FT boost**
- **0% additional Gold chance**
- **No premium land multiplier**
- **No player-selected miner**
- **RNG-based temporary miner selection**

The F2P Land's advantage is access to temporary miner rarities through RNG, not boosted rewards.

---

## F2P Miner RNG Pool

| Temporary Miner | RNG Chance |
|---|---:|
| Artifact / F2P Miner | **55%** |
| Common Miner | **25%** |
| Uncommon Miner | **12%** |
| Rare Miner | **6%** |
| Epic Miner | **1.75%** |
| Legendary Miner | **0.25%** |

**Total = 100%**

---

## F2P Mining Flow

```text
Player starts mining
        ↓
System performs RNG roll
        ↓
Temporary miner rarity is selected
        ↓
Selected miner's reward configuration is used
        ↓
No land FT boost is applied
        ↓
No land Gold boost is applied
        ↓
Reward is generated
        ↓
Temporary miner disappears
        ↓
Next mining attempt performs a new RNG roll
```

The RNG-selected miner is temporary.

The player does **not** receive ownership of the selected miner NFT.

---

# 4. General Reward Configuration

## Healing

**1 HP = 5 FT**

| Damage | Healing Cost |
|---:|---:|
| 5 HP | **25 FT** |
| 10 HP | **50 FT** |
| 15 HP | **75 FT** |
| 20 HP | **100 FT** |
| 25 HP | **125 FT** |
| 30 HP | **150 FT** |

Health regeneration is not free.

Healing acts as a recurring FT sink.

---

# 5. Miner Rewards

| Rarity | Base FT | Gold Chance | Health | Damage | Cooldown |
|---|---:|---:|---:|---:|---:|
| Artifact / F2P | **27 FT** | **0.50%** | **200** | **-5 HP** | **7,200 sec / 2h** |
| Common | **55 FT** | **5.00%** | **200** | **-10 HP** | **3,600 sec / 1h** |
| Uncommon | **85 FT** | **4.00%** | **200** | **-15 HP** | **3,600 sec / 1h** |
| Rare | **120 FT** | **3.00%** | **200** | **-20 HP** | **3,600 sec / 1h** |
| Epic | **155 FT** | **2.00%** | **200** | **-25 HP** | **3,600 sec / 1h** |
| Legendary | **195 FT** | **1.50%** | **200** | **-30 HP** | **3,600 sec / 1h** |

---

# 6. Equipment Rewards

| Gear Rarity | FT Multiplier | Additional Gold Chance | Uses | Cooldown |
|---|---:|---:|---:|---:|
| None | **1.00×** | **+0%** | — | — |
| Common | **1.35×** | **+2.50%** | **125** | **3,600 sec** |
| Uncommon | **1.60×** | **+2.00%** | **125** | **3,600 sec** |
| Rare | **1.90×** | **+1.50%** | **125** | **3,600 sec** |
| Epic | **2.25×** | **+0.75%** | **125** | **3,600 sec** |
| Legendary | **2.60×** | **+0.25%** | **125** | **3,600 sec** |

---

# 7. Equipment Roles

| Equipment | Main Purpose |
|---|---|
| Common | **Gold Farming** |
| Uncommon | **Gold + FT Hybrid** |
| Rare | **Balanced** |
| Epic | **High FT Farming** |
| Legendary | **Maximum FT Farming** |

Common equipment favors Gold acquisition.

Legendary equipment favors FT production while providing very little additional Gold chance.

---

# 8. Gold Chance Rules

## Without Premium Land

```text
Final Gold Chance =
Miner Gold Chance
+ Equipment Gold Bonus
```

## With Premium Land

```text
Final Gold Chance =
Miner Gold Chance
+ Equipment Gold Bonus
+ Land Gold Bonus
```

## Global Gold Chance Cap

**Maximum Gold chance = 10%**

Future bonuses, events, equipment, land, or other systems cannot increase the final mining Gold probability above 10% unless the economy configuration is intentionally changed.

---

# 9. FT Reward Rules

## Without Equipment or Premium Land

```text
Final FT = Miner Base FT
```

## With Equipment

```text
Final FT =
Miner Base FT
× Equipment Multiplier
```

## With Equipment and Premium Land

```text
Final FT =
Miner Base FT
× Equipment Multiplier
× (1 + Land FT Boost)
```

Healing is paid separately.

---

# 10. Example Configurations

## Common Miner + Common Equipment

Common Miner:

- Base FT: **55 FT**
- Gold Chance: **5.00%**
- Damage: **10 HP**

Common Equipment:

- FT Multiplier: **1.35×**
- Gold Bonus: **+2.50%**

FT:

```text
55 × 1.35 = 74.25 FT
```

Gold Chance:

```text
5.00% + 2.50% = 7.50%
```

Healing:

```text
10 × 5 = 50 FT
```

Result:

- FT Reward: **74.25 FT**
- Gold Chance: **7.50%**
- Healing Cost: **50 FT**
- Equipment Use: **1 / 125**

---

## Rare Miner + Rare Equipment

Rare Miner:

- Base FT: **120 FT**
- Gold Chance: **3.00%**
- Damage: **20 HP**

Rare Equipment:

- FT Multiplier: **1.90×**
- Gold Bonus: **+1.50%**

FT:

```text
120 × 1.90 = 228 FT
```

Gold Chance:

```text
3.00% + 1.50% = 4.50%
```

Healing:

```text
20 × 5 = 100 FT
```

Result:

- FT Reward: **228 FT**
- Gold Chance: **4.50%**
- Healing Cost: **100 FT**
- Equipment Use: **1 / 125**

---

## Epic Miner + Legendary Equipment

Epic Miner:

- Base FT: **155 FT**
- Gold Chance: **2.00%**
- Damage: **25 HP**

Legendary Equipment:

- FT Multiplier: **2.60×**
- Gold Bonus: **+0.25%**

FT:

```text
155 × 2.60 = 403 FT
```

Gold Chance:

```text
2.00% + 0.25% = 2.25%
```

Healing:

```text
25 × 5 = 125 FT
```

Result:

- FT Reward: **403 FT**
- Gold Chance: **2.25%**
- Healing Cost: **125 FT**
- Equipment Use: **1 / 125**

---

## Epic Miner + Legendary Equipment + Diamond Land

Epic Miner:

**155 FT**

Legendary Equipment:

**2.60×**

Diamond Land:

**+15% FT**

FT before land:

```text
155 × 2.60 = 403 FT
```

Final FT:

```text
403 × 1.15 = 463.45 FT
```

Gold Chance:

```text
2.00% + 0.25% + 1.25% = 3.50%
```

Result:

- FT Reward: **463.45 FT**
- Gold Chance: **3.50%**
- Healing Cost: **125 FT**
- Equipment Use: **1**
- Diamond Land Use: **1**

---

## Legendary Miner + Legendary Equipment + Diamond Land

Legendary Miner:

**195 FT**

Legendary Equipment:

**2.60×**

Diamond Land:

**+15% FT**

FT:

```text
195 × 2.60 = 507 FT
507 × 1.15 = 583.05 FT
```

Gold Chance:

```text
1.50% + 0.25% + 1.25% = 3.00%
```

Healing:

```text
30 × 5 = 150 FT
```

Result:

- FT Reward: **583.05 FT**
- Gold Chance: **3.00%**
- Healing Cost: **150 FT**
- Equipment Use: **1**
- Diamond Land Use: **1**

---

# 11. F2P Example

Player starts mining on F2P Land.

RNG selects:

**Rare Miner**

Rare Miner configuration:

- Base FT: **120 FT**
- Gold Chance: **3.00%**
- Damage: **20 HP**
- Cooldown: **1 hour**

Because the player is mining on F2P Land:

- Land FT Boost = **0%**
- Land Gold Boost = **0%**

Therefore:

```text
FT Reward = 120 FT
Gold Chance = 3.00%
```

No premium land bonus is applied.

The temporary Rare Miner disappears after the mining attempt.

---

# 12. Economy Roles

## F2P / Artifact

Purpose:

**Free entry into the ecosystem**

Characteristics:

- RNG-selected miner
- No land booster
- No permanent miner ownership from RNG
- Small chance to experience higher rarity miners

---

## Common Miner

Purpose:

**Gold-focused mining**

Characteristics:

- Lower guaranteed FT
- Highest base Gold chance among crafted miners

---

## Uncommon Miner

Purpose:

**Gold / FT hybrid**

Characteristics:

- Better FT output than Common
- Still strong Gold probability

---

## Rare Miner

Purpose:

**Balanced miner**

Characteristics:

- Stronger FT
- Moderate Gold chance

---

## Epic Miner

Purpose:

**FT-focused miner**

Characteristics:

- High guaranteed FT
- Lower Gold probability

---

## Legendary Miner

Purpose:

**Maximum FT production**

Characteristics:

- Highest base FT
- Lowest or near-lowest Gold probability
- Designed to consume scarce Gold through high-tier equipment and progression

---

# 13. Currency Economy

## FT

FT is the high-supply utility currency.

FT enters primarily through:

- Mining

FT leaves through:

- Healing
- Miner crafting
- Equipment crafting
- Land crafting
- NFT upgrades
- Slot unlocks
- Equipment repairs
- Marketplace fees
- Rerolls
- Events
- Future upgrades

---

## Gold

Gold is the scarce crafting/resource currency.

Gold enters primarily through:

- Mining RNG
- Events
- Special rewards

Gold leaves through:

- Miner crafting
- Equipment crafting
- Land crafting
- Miner upgrades
- Equipment upgrades
- NFT merging
- Special crafting
- Premium game systems

---

# 14. Gold / FT Exchange

Temporary V1 balancing reference:

```text
1 Gold = 1,000 FT
```

This is an internal balancing benchmark only.

The live market ratio can later become dynamic and player-driven.

A future player marketplace can allow:

```text
Gold Seller → receives FT
Gold Buyer → spends FT
```

Possible marketplace fee:

**2%–5%**

This creates an additional currency sink.

---

# 15. Core Economy Principle

```text
F2P
 ↓
RNG-based temporary mining
 ↓
Common Miner
 ↓
Higher Gold production
 ↓
Uncommon / Rare
 ↓
Balanced Gold + FT
 ↓
Epic / Legendary
 ↓
Higher FT production
 ↓
Gold and FT consumed through
healing, crafting, equipment,
lands, upgrades, slots and fees
```

---

# 16. Final V1 Summary

## Miner Progression

**Higher rarity = More guaranteed FT**

**Higher rarity = Lower Gold probability**

---

## Equipment Progression

**Common Equipment = Gold focused**

**Uncommon Equipment = Gold / FT hybrid**

**Rare Equipment = Balanced**

**Epic Equipment = FT focused**

**Legendary Equipment = Maximum FT focused**

---

## Land Progression

### F2P / Artifact Land

- Free
- No FT boost
- No Gold boost
- RNG-selected temporary miner
- Only land with miner-selection restriction

### Epic Land

- **75 uses**
- **3 Gold**
- **986 FT**
- **+10% FT**
- **+1.00% Gold**
- Works with every miner

### Legendary Land

- **300 uses**
- **11 Gold**
- **3,100 FT**
- **+12% FT**
- **+1.00% Gold**
- Works with every miner

### Diamond Land

- **600 uses**
- **21 Gold**
- **5,150 FT**
- **+15% FT**
- **+1.25% Gold**
- Works with every miner

---

## Important Limits

- **Maximum Gold Chance: 10%**
- **Equipment Uses: 125**
- **Miner Health: 200 HP**
- **Healing: 5 FT / HP**
- **Standard Mining Cooldown: 1 Hour**
- **F2P / Artifact Base Cooldown: 2 Hours**
- **Temporary Economy Reference: 1 Gold = 1,000 FT**

---

# 17. Core Land Rule

**Premium land does not restrict which miner may be *placed* on it — but it does restrict which miners receive its FT boost.**

Any miner may be placed on any premium land and mined normally. What the land's rarity determines is whether that miner gets the land's **FT boost**:

```text
Miner          = Base mining power
Equipment      = Mining strategy + reward multiplier
Premium Land   = FT boost for the miner rarities in its band (§2)
                 + Gold chance bonus for EVERY miner
F2P Land       = RNG miner-type access, no boost of any kind
```

Two rules follow, and they are easy to get the wrong way round:

1. **The FT boost is tier-matched.** A Common miner on Legendary Land receives **no FT boost** — the land still works, it just adds nothing to the reward. See the §2 coverage matrix.
2. **The Gold chance bonus is universal.** The same Common miner on the same Legendary Land **does** receive the land's +1.00% Gold chance.

> ⚠️ **This must be surfaced in the UI before purchase.** A player buying land that will not boost their miner has no way to discover it from the land's stats alone. The Smithy and land-activation screens must show the land's boost band and warn when the player's miners fall outside it.
