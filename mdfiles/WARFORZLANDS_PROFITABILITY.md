# WarForz Lands — Profitability Tables

**Every miner × equipment × land combination, with net profit per mine.**

| | |
|---|---|
| Generated | 2026-09-05 |
| Basis | `WARFORZLANDS_ECONOMY_CONFIG_V1.md` + live `warforzlands` config on WAX testnet |
| Combinations | 6 miners × 6 equipment × 4 lands = **144** |
| Applies to | WAX **and** Robinhood Chain — the two run identical economies |

---

## ⚠️ Read this before publishing any number here

Every figure below values **1 Gold = 1,000 FT**. That is Economy V1 §14's *internal balancing reference*, explicitly labelled temporary, **not a market price**.

Gold is a large share of low-tier income — a Common miner earns more value in Gold than in FT — so **low-tier profitability moves sharply with the real Gold price.** §6 shows the sensitivity. If you publish these tables to players, publish the assumption with them, or state figures in Gold and FT separately rather than as one FT-equivalent number.

---

## 1. How the numbers are calculated

```text
FT reward   = miner base FT × equipment multiplier × land boost
              (land boost applies ONLY if the miner is in that land's band)

Gold chance = miner chance + equipment bonus + land bonus     (additive)
              capped at 10%; the land bonus applies to EVERY miner

Costs per mine:
  land use  = (land FT cost + land Gold cost × rate) ÷ land uses
  gear use  = (gear FT cost + gear Gold cost × rate) ÷ 125 uses
  healing   = miner damage × 5 FT

NET = FT reward + expected Gold value − land − gear − healing
```

**FT/hour** additionally accounts for access: premium land allows one mine per hour; F2P land only when your tier is the active selector (Artifact 55% of hours, Common 25%, Uncommon 12%, Rare 6%, Epic 1.75%, Legendary 0.25%). Artifact miners also carry a 2-hour cooldown.

---

## 2. Highest profit

| Rank | Miner | Equipment | Land | FT/mine | FT/hour |
|---:|---|---|---|---:|---:|
| 1 | Legendary | Legendary | Diamond | 268.3 | 268.3 |
| 2 | Legendary | Legendary | Legendary | 247.1 | 247.1 |
| 3 | Legendary | Epic | Diamond | 234.0 | 234.0 |
| 4 | Legendary | Epic | Legendary | 214.9 | 214.9 |
| 5 | Legendary | Rare | Diamond | 199.0 | 199.0 |
| 6 | Legendary | Rare | Legendary | 182.0 | 182.0 |
| 7 | Legendary | Legendary | Epic | 180.2 | 180.2 |
| 8 | Epic | Legendary | Diamond | 178.7 | 178.7 |
| 9 | Legendary | Uncommon | Diamond | 168.7 | 168.7 |
| 10 | Epic | Epic | Diamond | 160.5 | 160.5 |

**The miner tier is the dominant lever.** A Legendary miner with *Uncommon* equipment out-earns most Epic-miner setups. Upgrade the miner before the equipment.

### Best setup at each miner tier

| If you own | Best equipment | Best land | FT/mine | FT/hour |
|---|---|---|---:|---:|
| Artifact | None | F2P | 7.0 | 1.9 |
| Common | Uncommon | Diamond | 46.1 | 46.1 |
| Uncommon | Uncommon | Diamond | 66.3 | 66.3 |
| Rare | Legendary | Diamond | 109.0 | 109.0 |
| Epic | Legendary | Diamond | 178.7 | 178.7 |
| Legendary | Legendary | Diamond | 268.3 | 268.3 |

---

## 3. ⚠️ Loss-making combinations — 29 of 144

These **cost more than they earn**. Both traps have the same shape: a *flat* per-use cost set against a *multiplicative* reward, so they punish low-output miners hardest.

### Trap 1 — Artifact miner on premium land

An Artifact miner grosses 27 FT. Premium land costs 43–53 FT per use before equipment or healing. **It can never pay.** Artifact miners belong on F2P land.

### Trap 2 — expensive equipment on a cheap miner

Legendary equipment costs **151.2 FT per use** no matter what it is attached to. A Common miner grossing 143 FT cannot cover it. Match equipment to miner.

| Miner | Equipment | Land | FT/mine |
|---|---|---|---:|
| Artifact | Legendary | Epic | **-141.6** |
| Artifact | Legendary | Legendary | **-135.5** |
| Artifact | Legendary | Diamond | **-129.6** |
| Artifact | Epic | Epic | **-106.9** |
| Artifact | Epic | Legendary | **-100.8** |
| Artifact | Legendary | F2P | **-98.5** |
| Artifact | Epic | Diamond | **-94.8** |
| Artifact | Rare | Epic | **-72.8** |
| Artifact | Rare | Legendary | **-66.7** |
| Artifact | Epic | F2P | **-63.8** |
| Artifact | Rare | Diamond | **-60.8** |
| Common | Legendary | Epic | **-48.8** |
| Artifact | Uncommon | Epic | **-43.9** |
| Common | Legendary | Legendary | **-42.7** |
| Artifact | Common | Epic | **-40.1** |
| Artifact | Uncommon | Legendary | **-37.8** |
| Artifact | None | Epic | **-36.1** |
| Artifact | Common | Legendary | **-33.9** |
| Artifact | Uncommon | Diamond | **-31.9** |
| Artifact | None | Legendary | **-30.0** |
| Artifact | Rare | F2P | **-29.7** |
| Artifact | Common | Diamond | **-28.0** |
| Artifact | None | Diamond | **-24.1** |
| Common | Epic | Epic | **-23.9** |
| Common | Epic | Legendary | **-17.8** |
| Common | Legendary | Diamond | **-15.3** |
| Uncommon | Legendary | Epic | **-5.8** |
| Common | Legendary | F2P | **-5.7** |
| Artifact | Uncommon | F2P | **-0.8** |

Uncommon, Rare, Epic and Legendary miners **never lose** on any land with any equipment.

---

## 4. Full matrix — all 144 combinations

Land bands as currently live: Epic Land boosts Epic miners; Legendary Land boosts Legendary miners; Diamond Land boosts everything except Artifact. `boost?` shows whether the land's FT boost applied.

### Artifact miner — 27 FT base, 0.50% Gold, 5 damage, 7200s cooldown

| Equipment | Land | boost? | FT reward | Gold % | Gold value | Land cost | Gear cost | Heal | **NET** | FT/hour |
|---|---|:---:|---:|---:|---:|---:|---:|---:|---:|---:|
| None | F2P | — | 27.0 | 0.50% | 5.0 | 0.0 | 0.0 | 25.0 | **7.0** | 1.9 |
| None | Epic | — | 27.0 | 1.50% | 15.0 | 53.1 | 0.0 | 25.0 | **⚠️ -36.1** | -18.1 |
| None | Legendary | — | 27.0 | 1.50% | 15.0 | 47.0 | 0.0 | 25.0 | **⚠️ -30.0** | -15.0 |
| None | Diamond | — | 27.0 | 1.75% | 17.5 | 43.6 | 0.0 | 25.0 | **⚠️ -24.1** | -12.0 |
| Common | F2P | — | 36.5 | 3.00% | 30.0 | 0.0 | 38.4 | 25.0 | **3.1** | 0.8 |
| Common | Epic | — | 36.5 | 4.00% | 40.0 | 53.1 | 38.4 | 25.0 | **⚠️ -40.1** | -20.0 |
| Common | Legendary | — | 36.5 | 4.00% | 40.0 | 47.0 | 38.4 | 25.0 | **⚠️ -33.9** | -17.0 |
| Common | Diamond | — | 36.5 | 4.25% | 42.5 | 43.6 | 38.4 | 25.0 | **⚠️ -28.0** | -14.0 |
| Uncommon | F2P | — | 43.2 | 2.50% | 25.0 | 0.0 | 44.0 | 25.0 | **⚠️ -0.8** | -0.2 |
| Uncommon | Epic | — | 43.2 | 3.50% | 35.0 | 53.1 | 44.0 | 25.0 | **⚠️ -43.9** | -22.0 |
| Uncommon | Legendary | — | 43.2 | 3.50% | 35.0 | 47.0 | 44.0 | 25.0 | **⚠️ -37.8** | -18.9 |
| Uncommon | Diamond | — | 43.2 | 3.75% | 37.5 | 43.6 | 44.0 | 25.0 | **⚠️ -31.9** | -15.9 |
| Rare | F2P | — | 51.3 | 2.00% | 20.0 | 0.0 | 76.0 | 25.0 | **⚠️ -29.7** | -8.2 |
| Rare | Epic | — | 51.3 | 3.00% | 30.0 | 53.1 | 76.0 | 25.0 | **⚠️ -72.8** | -36.4 |
| Rare | Legendary | — | 51.3 | 3.00% | 30.0 | 47.0 | 76.0 | 25.0 | **⚠️ -66.7** | -33.4 |
| Rare | Diamond | — | 51.3 | 3.25% | 32.5 | 43.6 | 76.0 | 25.0 | **⚠️ -60.8** | -30.4 |
| Epic | F2P | — | 60.8 | 1.25% | 12.5 | 0.0 | 112.0 | 25.0 | **⚠️ -63.8** | -17.5 |
| Epic | Epic | — | 60.8 | 2.25% | 22.5 | 53.1 | 112.0 | 25.0 | **⚠️ -106.9** | -53.4 |
| Epic | Legendary | — | 60.8 | 2.25% | 22.5 | 47.0 | 112.0 | 25.0 | **⚠️ -100.8** | -50.4 |
| Epic | Diamond | — | 60.8 | 2.50% | 25.0 | 43.6 | 112.0 | 25.0 | **⚠️ -94.8** | -47.4 |
| Legendary | F2P | — | 70.2 | 0.75% | 7.5 | 0.0 | 151.2 | 25.0 | **⚠️ -98.5** | -27.1 |
| Legendary | Epic | — | 70.2 | 1.75% | 17.5 | 53.1 | 151.2 | 25.0 | **⚠️ -141.6** | -70.8 |
| Legendary | Legendary | — | 70.2 | 1.75% | 17.5 | 47.0 | 151.2 | 25.0 | **⚠️ -135.5** | -67.8 |
| Legendary | Diamond | — | 70.2 | 2.00% | 20.0 | 43.6 | 151.2 | 25.0 | **⚠️ -129.6** | -64.8 |

### Common miner — 55 FT base, 5.00% Gold, 10 damage, 3600s cooldown

| Equipment | Land | boost? | FT reward | Gold % | Gold value | Land cost | Gear cost | Heal | **NET** | FT/hour |
|---|---|:---:|---:|---:|---:|---:|---:|---:|---:|---:|
| None | F2P | — | 55.0 | 5.00% | 50.0 | 0.0 | 0.0 | 50.0 | **55.0** | 13.8 |
| None | Epic | — | 55.0 | 6.00% | 60.0 | 53.1 | 0.0 | 50.0 | **11.9** | 11.9 |
| None | Legendary | — | 55.0 | 6.00% | 60.0 | 47.0 | 0.0 | 50.0 | **18.0** | 18.0 |
| None | Diamond | ✅ | 63.2 | 6.25% | 62.5 | 43.6 | 0.0 | 50.0 | **32.2** | 32.2 |
| Common | F2P | — | 74.2 | 7.50% | 75.0 | 0.0 | 38.4 | 50.0 | **60.8** | 15.2 |
| Common | Epic | — | 74.2 | 8.50% | 85.0 | 53.1 | 38.4 | 50.0 | **17.7** | 17.7 |
| Common | Legendary | — | 74.2 | 8.50% | 85.0 | 47.0 | 38.4 | 50.0 | **23.8** | 23.8 |
| Common | Diamond | ✅ | 85.4 | 8.75% | 87.5 | 43.6 | 38.4 | 50.0 | **40.9** | 40.9 |
| Uncommon | F2P | — | 88.0 | 7.00% | 70.0 | 0.0 | 44.0 | 50.0 | **64.0** | 16.0 |
| Uncommon | Epic | — | 88.0 | 8.00% | 80.0 | 53.1 | 44.0 | 50.0 | **20.9** | 20.9 |
| Uncommon | Legendary | — | 88.0 | 8.00% | 80.0 | 47.0 | 44.0 | 50.0 | **27.0** | 27.0 |
| Uncommon | Diamond | ✅ | 101.2 | 8.25% | 82.5 | 43.6 | 44.0 | 50.0 | **46.1** | 46.1 |
| Rare | F2P | — | 104.5 | 6.50% | 65.0 | 0.0 | 76.0 | 50.0 | **43.5** | 10.9 |
| Rare | Epic | — | 104.5 | 7.50% | 75.0 | 53.1 | 76.0 | 50.0 | **0.4** | 0.4 |
| Rare | Legendary | — | 104.5 | 7.50% | 75.0 | 47.0 | 76.0 | 50.0 | **6.5** | 6.5 |
| Rare | Diamond | ✅ | 120.2 | 7.75% | 77.5 | 43.6 | 76.0 | 50.0 | **28.1** | 28.1 |
| Epic | F2P | — | 123.8 | 5.75% | 57.5 | 0.0 | 112.0 | 50.0 | **19.2** | 4.8 |
| Epic | Epic | — | 123.8 | 6.75% | 67.5 | 53.1 | 112.0 | 50.0 | **⚠️ -23.9** | -23.9 |
| Epic | Legendary | — | 123.8 | 6.75% | 67.5 | 47.0 | 112.0 | 50.0 | **⚠️ -17.8** | -17.8 |
| Epic | Diamond | ✅ | 142.3 | 7.00% | 70.0 | 43.6 | 112.0 | 50.0 | **6.7** | 6.7 |
| Legendary | F2P | — | 143.0 | 5.25% | 52.5 | 0.0 | 151.2 | 50.0 | **⚠️ -5.7** | -1.4 |
| Legendary | Epic | — | 143.0 | 6.25% | 62.5 | 53.1 | 151.2 | 50.0 | **⚠️ -48.8** | -48.8 |
| Legendary | Legendary | — | 143.0 | 6.25% | 62.5 | 47.0 | 151.2 | 50.0 | **⚠️ -42.7** | -42.7 |
| Legendary | Diamond | ✅ | 164.4 | 6.50% | 65.0 | 43.6 | 151.2 | 50.0 | **⚠️ -15.3** | -15.3 |

### Uncommon miner — 85 FT base, 4.00% Gold, 15 damage, 3600s cooldown

| Equipment | Land | boost? | FT reward | Gold % | Gold value | Land cost | Gear cost | Heal | **NET** | FT/hour |
|---|---|:---:|---:|---:|---:|---:|---:|---:|---:|---:|
| None | F2P | — | 85.0 | 4.00% | 40.0 | 0.0 | 0.0 | 75.0 | **50.0** | 6.0 |
| None | Epic | — | 85.0 | 5.00% | 50.0 | 53.1 | 0.0 | 75.0 | **6.9** | 6.9 |
| None | Legendary | — | 85.0 | 5.00% | 50.0 | 47.0 | 0.0 | 75.0 | **13.0** | 13.0 |
| None | Diamond | ✅ | 97.7 | 5.25% | 52.5 | 43.6 | 0.0 | 75.0 | **31.7** | 31.7 |
| Common | F2P | — | 114.8 | 6.50% | 65.0 | 0.0 | 38.4 | 75.0 | **66.3** | 8.0 |
| Common | Epic | — | 114.8 | 7.50% | 75.0 | 53.1 | 38.4 | 75.0 | **23.2** | 23.2 |
| Common | Legendary | — | 114.8 | 7.50% | 75.0 | 47.0 | 38.4 | 75.0 | **29.3** | 29.3 |
| Common | Diamond | ✅ | 132.0 | 7.75% | 77.5 | 43.6 | 38.4 | 75.0 | **52.5** | 52.5 |
| Uncommon | F2P | — | 136.0 | 6.00% | 60.0 | 0.0 | 44.0 | 75.0 | **77.0** | 9.2 |
| Uncommon | Epic | — | 136.0 | 7.00% | 70.0 | 53.1 | 44.0 | 75.0 | **33.9** | 33.9 |
| Uncommon | Legendary | — | 136.0 | 7.00% | 70.0 | 47.0 | 44.0 | 75.0 | **40.0** | 40.0 |
| Uncommon | Diamond | ✅ | 156.4 | 7.25% | 72.5 | 43.6 | 44.0 | 75.0 | **66.3** | 66.3 |
| Rare | F2P | — | 161.5 | 5.50% | 55.0 | 0.0 | 76.0 | 75.0 | **65.5** | 7.9 |
| Rare | Epic | — | 161.5 | 6.50% | 65.0 | 53.1 | 76.0 | 75.0 | **22.4** | 22.4 |
| Rare | Legendary | — | 161.5 | 6.50% | 65.0 | 47.0 | 76.0 | 75.0 | **28.5** | 28.5 |
| Rare | Diamond | ✅ | 185.7 | 6.75% | 67.5 | 43.6 | 76.0 | 75.0 | **58.6** | 58.6 |
| Epic | F2P | — | 191.2 | 4.75% | 47.5 | 0.0 | 112.0 | 75.0 | **51.8** | 6.2 |
| Epic | Epic | — | 191.2 | 5.75% | 57.5 | 53.1 | 112.0 | 75.0 | **8.6** | 8.6 |
| Epic | Legendary | — | 191.2 | 5.75% | 57.5 | 47.0 | 112.0 | 75.0 | **14.8** | 14.8 |
| Epic | Diamond | ✅ | 219.9 | 6.00% | 60.0 | 43.6 | 112.0 | 75.0 | **49.4** | 49.4 |
| Legendary | F2P | — | 221.0 | 4.25% | 42.5 | 0.0 | 151.2 | 75.0 | **37.3** | 4.5 |
| Legendary | Epic | — | 221.0 | 5.25% | 52.5 | 53.1 | 151.2 | 75.0 | **⚠️ -5.8** | -5.8 |
| Legendary | Legendary | — | 221.0 | 5.25% | 52.5 | 47.0 | 151.2 | 75.0 | **0.3** | 0.3 |
| Legendary | Diamond | ✅ | 254.1 | 5.50% | 55.0 | 43.6 | 151.2 | 75.0 | **39.4** | 39.4 |

### Rare miner — 120 FT base, 3.00% Gold, 20 damage, 3600s cooldown

| Equipment | Land | boost? | FT reward | Gold % | Gold value | Land cost | Gear cost | Heal | **NET** | FT/hour |
|---|---|:---:|---:|---:|---:|---:|---:|---:|---:|---:|
| None | F2P | — | 120.0 | 3.00% | 30.0 | 0.0 | 0.0 | 100.0 | **50.0** | 3.0 |
| None | Epic | — | 120.0 | 4.00% | 40.0 | 53.1 | 0.0 | 100.0 | **6.9** | 6.9 |
| None | Legendary | — | 120.0 | 4.00% | 40.0 | 47.0 | 0.0 | 100.0 | **13.0** | 13.0 |
| None | Diamond | ✅ | 138.0 | 4.25% | 42.5 | 43.6 | 0.0 | 100.0 | **36.9** | 36.9 |
| Common | F2P | — | 162.0 | 5.50% | 55.0 | 0.0 | 38.4 | 100.0 | **78.6** | 4.7 |
| Common | Epic | — | 162.0 | 6.50% | 65.0 | 53.1 | 38.4 | 100.0 | **35.5** | 35.5 |
| Common | Legendary | — | 162.0 | 6.50% | 65.0 | 47.0 | 38.4 | 100.0 | **41.6** | 41.6 |
| Common | Diamond | ✅ | 186.3 | 6.75% | 67.5 | 43.6 | 38.4 | 100.0 | **71.8** | 71.8 |
| Uncommon | F2P | — | 192.0 | 5.00% | 50.0 | 0.0 | 44.0 | 100.0 | **98.0** | 5.9 |
| Uncommon | Epic | — | 192.0 | 6.00% | 60.0 | 53.1 | 44.0 | 100.0 | **54.9** | 54.9 |
| Uncommon | Legendary | — | 192.0 | 6.00% | 60.0 | 47.0 | 44.0 | 100.0 | **61.0** | 61.0 |
| Uncommon | Diamond | ✅ | 220.8 | 6.25% | 62.5 | 43.6 | 44.0 | 100.0 | **95.7** | 95.7 |
| Rare | F2P | — | 228.0 | 4.50% | 45.0 | 0.0 | 76.0 | 100.0 | **97.0** | 5.8 |
| Rare | Epic | — | 228.0 | 5.50% | 55.0 | 53.1 | 76.0 | 100.0 | **53.9** | 53.9 |
| Rare | Legendary | — | 228.0 | 5.50% | 55.0 | 47.0 | 76.0 | 100.0 | **60.0** | 60.0 |
| Rare | Diamond | ✅ | 262.2 | 5.75% | 57.5 | 43.6 | 76.0 | 100.0 | **100.1** | 100.1 |
| Epic | F2P | — | 270.0 | 3.75% | 37.5 | 0.0 | 112.0 | 100.0 | **95.5** | 5.7 |
| Epic | Epic | — | 270.0 | 4.75% | 47.5 | 53.1 | 112.0 | 100.0 | **52.4** | 52.4 |
| Epic | Legendary | — | 270.0 | 4.75% | 47.5 | 47.0 | 112.0 | 100.0 | **58.5** | 58.5 |
| Epic | Diamond | ✅ | 310.5 | 5.00% | 50.0 | 43.6 | 112.0 | 100.0 | **104.9** | 104.9 |
| Legendary | F2P | — | 312.0 | 3.25% | 32.5 | 0.0 | 151.2 | 100.0 | **93.3** | 5.6 |
| Legendary | Epic | — | 312.0 | 4.25% | 42.5 | 53.1 | 151.2 | 100.0 | **50.2** | 50.2 |
| Legendary | Legendary | — | 312.0 | 4.25% | 42.5 | 47.0 | 151.2 | 100.0 | **56.3** | 56.3 |
| Legendary | Diamond | ✅ | 358.8 | 4.50% | 45.0 | 43.6 | 151.2 | 100.0 | **109.0** | 109.0 |

### Epic miner — 155 FT base, 2.00% Gold, 25 damage, 3600s cooldown

| Equipment | Land | boost? | FT reward | Gold % | Gold value | Land cost | Gear cost | Heal | **NET** | FT/hour |
|---|---|:---:|---:|---:|---:|---:|---:|---:|---:|---:|
| None | F2P | — | 155.0 | 2.00% | 20.0 | 0.0 | 0.0 | 125.0 | **50.0** | 0.9 |
| None | Epic | ✅ | 170.5 | 3.00% | 30.0 | 53.1 | 0.0 | 125.0 | **22.4** | 22.4 |
| None | Legendary | — | 155.0 | 3.00% | 30.0 | 47.0 | 0.0 | 125.0 | **13.0** | 13.0 |
| None | Diamond | ✅ | 178.2 | 3.25% | 32.5 | 43.6 | 0.0 | 125.0 | **42.2** | 42.2 |
| Common | F2P | — | 209.2 | 4.50% | 45.0 | 0.0 | 38.4 | 125.0 | **90.8** | 1.6 |
| Common | Epic | ✅ | 230.2 | 5.50% | 55.0 | 53.1 | 38.4 | 125.0 | **68.6** | 68.6 |
| Common | Legendary | — | 209.2 | 5.50% | 55.0 | 47.0 | 38.4 | 125.0 | **53.8** | 53.8 |
| Common | Diamond | ✅ | 240.6 | 5.75% | 57.5 | 43.6 | 38.4 | 125.0 | **91.2** | 91.2 |
| Uncommon | F2P | — | 248.0 | 4.00% | 40.0 | 0.0 | 44.0 | 125.0 | **119.0** | 2.1 |
| Uncommon | Epic | ✅ | 272.8 | 5.00% | 50.0 | 53.1 | 44.0 | 125.0 | **100.7** | 100.7 |
| Uncommon | Legendary | — | 248.0 | 5.00% | 50.0 | 47.0 | 44.0 | 125.0 | **82.0** | 82.0 |
| Uncommon | Diamond | ✅ | 285.2 | 5.25% | 52.5 | 43.6 | 44.0 | 125.0 | **125.1** | 125.1 |
| Rare | F2P | — | 294.5 | 3.50% | 35.0 | 0.0 | 76.0 | 125.0 | **128.5** | 2.2 |
| Rare | Epic | ✅ | 324.0 | 4.50% | 45.0 | 53.1 | 76.0 | 125.0 | **114.8** | 114.8 |
| Rare | Legendary | — | 294.5 | 4.50% | 45.0 | 47.0 | 76.0 | 125.0 | **91.5** | 91.5 |
| Rare | Diamond | ✅ | 338.7 | 4.75% | 47.5 | 43.6 | 76.0 | 125.0 | **141.6** | 141.6 |
| Epic | F2P | — | 348.8 | 2.75% | 27.5 | 0.0 | 112.0 | 125.0 | **139.2** | 2.4 |
| Epic | Epic | ✅ | 383.6 | 3.75% | 37.5 | 53.1 | 112.0 | 125.0 | **131.0** | 131.0 |
| Epic | Legendary | — | 348.8 | 3.75% | 37.5 | 47.0 | 112.0 | 125.0 | **102.2** | 102.2 |
| Epic | Diamond | ✅ | 401.1 | 4.00% | 40.0 | 43.6 | 112.0 | 125.0 | **160.5** | 160.5 |
| Legendary | F2P | — | 403.0 | 2.25% | 22.5 | 0.0 | 151.2 | 125.0 | **149.3** | 2.6 |
| Legendary | Epic | ✅ | 443.3 | 3.25% | 32.5 | 53.1 | 151.2 | 125.0 | **146.5** | 146.5 |
| Legendary | Legendary | — | 403.0 | 3.25% | 32.5 | 47.0 | 151.2 | 125.0 | **112.3** | 112.3 |
| Legendary | Diamond | ✅ | 463.4 | 3.50% | 35.0 | 43.6 | 151.2 | 125.0 | **178.7** | 178.7 |

### Legendary miner — 195 FT base, 1.50% Gold, 30 damage, 3600s cooldown

| Equipment | Land | boost? | FT reward | Gold % | Gold value | Land cost | Gear cost | Heal | **NET** | FT/hour |
|---|---|:---:|---:|---:|---:|---:|---:|---:|---:|---:|
| None | F2P | — | 195.0 | 1.50% | 15.0 | 0.0 | 0.0 | 150.0 | **60.0** | 0.1 |
| None | Epic | — | 195.0 | 2.50% | 25.0 | 53.1 | 0.0 | 150.0 | **16.9** | 16.9 |
| None | Legendary | ✅ | 218.4 | 2.50% | 25.0 | 47.0 | 0.0 | 150.0 | **46.4** | 46.4 |
| None | Diamond | ✅ | 224.2 | 2.75% | 27.5 | 43.6 | 0.0 | 150.0 | **58.2** | 58.2 |
| Common | F2P | — | 263.2 | 4.00% | 40.0 | 0.0 | 38.4 | 150.0 | **114.9** | 0.3 |
| Common | Epic | — | 263.2 | 5.00% | 50.0 | 53.1 | 38.4 | 150.0 | **71.7** | 71.7 |
| Common | Legendary | ✅ | 294.8 | 5.00% | 50.0 | 47.0 | 38.4 | 150.0 | **109.4** | 109.4 |
| Common | Diamond | ✅ | 302.7 | 5.25% | 52.5 | 43.6 | 38.4 | 150.0 | **123.3** | 123.3 |
| Uncommon | F2P | — | 312.0 | 3.50% | 35.0 | 0.0 | 44.0 | 150.0 | **153.0** | 0.4 |
| Uncommon | Epic | — | 312.0 | 4.50% | 45.0 | 53.1 | 44.0 | 150.0 | **109.9** | 109.9 |
| Uncommon | Legendary | ✅ | 349.4 | 4.50% | 45.0 | 47.0 | 44.0 | 150.0 | **153.4** | 153.4 |
| Uncommon | Diamond | ✅ | 358.8 | 4.75% | 47.5 | 43.6 | 44.0 | 150.0 | **168.7** | 168.7 |
| Rare | F2P | — | 370.5 | 3.00% | 30.0 | 0.0 | 76.0 | 150.0 | **174.5** | 0.4 |
| Rare | Epic | — | 370.5 | 4.00% | 40.0 | 53.1 | 76.0 | 150.0 | **131.4** | 131.4 |
| Rare | Legendary | ✅ | 415.0 | 4.00% | 40.0 | 47.0 | 76.0 | 150.0 | **182.0** | 182.0 |
| Rare | Diamond | ✅ | 426.1 | 4.25% | 42.5 | 43.6 | 76.0 | 150.0 | **199.0** | 199.0 |
| Epic | F2P | — | 438.8 | 2.25% | 22.5 | 0.0 | 112.0 | 150.0 | **199.2** | 0.5 |
| Epic | Epic | — | 438.8 | 3.25% | 32.5 | 53.1 | 112.0 | 150.0 | **156.1** | 156.1 |
| Epic | Legendary | ✅ | 491.4 | 3.25% | 32.5 | 47.0 | 112.0 | 150.0 | **214.9** | 214.9 |
| Epic | Diamond | ✅ | 504.6 | 3.50% | 35.0 | 43.6 | 112.0 | 150.0 | **234.0** | 234.0 |
| Legendary | F2P | — | 507.0 | 1.75% | 17.5 | 0.0 | 151.2 | 150.0 | **223.3** | 0.6 |
| Legendary | Epic | — | 507.0 | 2.75% | 27.5 | 53.1 | 151.2 | 150.0 | **180.2** | 180.2 |
| Legendary | Legendary | ✅ | 567.8 | 2.75% | 27.5 | 47.0 | 151.2 | 150.0 | **247.1** | 247.1 |
| Legendary | Diamond | ✅ | 583.0 | 3.00% | 30.0 | 43.6 | 151.2 | 150.0 | **268.3** | 268.3 |

---

## 5. Gold price sensitivity

Net FT per mine for the best setup at each tier, at three Gold prices. **The 1,000 FT column is the V1 reference; the others show what happens if the market disagrees.**

| Miner | Gold @ 500 FT | Gold @ 1,000 FT | Gold @ 2,000 FT |
|---|---:|---:|---:|
| Artifact | 4.5 | 7.0 | 12.0 |
| Common | 34.4 | 46.1 | 69.6 |
| Uncommon | 69.4 | 66.3 | 79.8 |
| Rare | 144.0 | 109.0 | 99.2 |
| Epic | 218.7 | 178.7 | 118.6 |
| Legendary | 310.8 | 268.3 | 183.3 |

**Low tiers are Gold-dependent, high tiers are FT-dependent.** A Common miner earns most of its value in Gold, so a falling Gold price hits it hardest. A Legendary miner earns most of its value in FT and barely notices. Any change to the Gold market therefore hits new players first.

---

## 6. Effect of the proposed band rebalance

Under consideration (`FIX_D1=matched`, see `WARFORZLANDS_ECONOMY_AUDIT.md`): Epic Land → Common/Uncommon/Rare · Legendary Land → Uncommon/Rare/Epic · Diamond Land → Rare/Epic/Legendary.

Combinations whose net changes, best equipment only:

| Miner | Equipment | Land | Now | Proposed | Change |
|---|---|---|---:|---:|---:|
| Common | Common | Epic | 17.7 | 25.1 | +7.4 |
| Common | Common | Diamond | 40.9 | 29.8 | -11.1 |
| Uncommon | Common | Epic | 23.2 | 34.7 | +11.5 |
| Uncommon | Common | Legendary | 29.3 | 43.1 | +13.8 |
| Uncommon | Common | Diamond | 52.5 | 35.3 | -17.2 |
| Rare | Rare | Epic | 53.9 | 76.7 | +22.8 |
| Rare | Rare | Legendary | 60.0 | 87.4 | +27.4 |
| Epic | Legendary | Epic | 146.5 | 106.2 | -40.3 |
| Epic | Legendary | Legendary | 112.3 | 160.7 | +48.4 |
| Legendary | Legendary | Legendary | 247.1 | 186.3 | -60.8 |

⚠️ **Common and Uncommon miners lose the Diamond Land boost they receive today.** Announce before applying.

---

## 7. Reproduce these tables

```bash
python scripts/profitability.py > WARFORZLANDS_PROFITABILITY.md
```

Regenerate after **any** economy change — a balance edit that looks small can flip a combination from profit to loss. The two traps in §3 exist because per-use costs are flat while rewards are multiplicative; that relationship is easy to break by accident.
