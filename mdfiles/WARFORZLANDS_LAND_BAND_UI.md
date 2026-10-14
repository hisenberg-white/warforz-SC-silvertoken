# Land boost bands — required UI work

**Follow-up to `WARFORZLANDS_ECONOMY_AUDIT.md` D1. Decision: keep tier-matched boosts (Option 2), rebalanced bands.**

| | |
|---|---|
| Decided | 2026-09-05 |
| Applies to | WAX frontend (`Frontend/`) **and** the Robinhood Chain port (plan.md F4.6 / F4.5f) |
| Why | A player cannot discover from a land's stats that it will not boost their miner. Nothing in the UI says so today |

---

## The rule the UI must express

A premium land grants its **FT boost** only to the miner rarities in its band. It still grants its **Gold chance bonus to every miner**. Both halves must be visible, because they behave differently.

| Land | FT boost | Boosts these miners | Gold bonus |
|---|---:|---|---:|
| Epic | +10% | Artifact, Common, Uncommon, Rare | +1.00% *(all miners)* |
| Legendary | +12% | Uncommon, Rare, Epic | +1.00% *(all miners)* |
| Diamond | +15% | Rare, Epic, Legendary | +1.25% *(all miners)* |

Bands overlap, so every miner rarity has at least one land that boosts it. Full matrix in `WARFORZLANDS_ECONOMY_CONFIG_V1.md` §2.

> ⛓️ **Read the bands from `landminmatch` at runtime.** Do **not** hardcode them. An operator can retune pairings with `matchset` without a redeploy, and a hardcoded UI would then lie.

---

## 1. Smithy — before they spend Gold and FT

**The highest-value fix.** This is where a player commits 3–21 Gold and 986–5,150 FT to a land.

- [ ] On a land recipe result, show **"Boosts: Artifact · Common · Uncommon · Rare"** alongside the existing FT-boost and Gold-chance stats.
- [ ] Show the Gold bonus separately, labelled as applying to **all miners**, so the asymmetry is explicit.
- [ ] 🔴 **Warn when the player owns no miner in the band:** *"None of your miners are boosted by this land. It will still work, but adds no FT bonus."* Do **not** block the craft — a player may be buying ahead of a miner upgrade.
- [ ] If the player owns some but not all, list which: *"Boosts 2 of your 5 miners."*

`WARFORZLANDS_FRONTEND.md` §7 already says Smithy shows "decision-critical craft summary" and joins the result template to the live config row. The band is decision-critical; it belongs there.

## 2. Land activation — the last reversible moment

Activation **burns the NFT**. After it, the choice cannot be undone.

- [ ] Show the band in the activation selector next to the land's name and image.
- [ ] Include it in the existing burn-confirmation modal (`ConfirmBurnModal`), which already warns the NFT is destroyed permanently.

## 3. Mining expedition — explain the number

`rewards.ts` already reads `landminmatch` and computes the match bonus correctly, so the projected reward is **right**. The problem is the player cannot tell *why* it is lower than the land's advertised boost.

- [ ] In the live mission summary, when the selected miner is **outside** the land's band, show **"Land boost: not applied — miner out of band"** rather than a silent `1.00×`.
- [ ] When it **is** applied, label it *"Land boost +12% (Legendary Land)"*.
- [ ] Keep the Gold bonus row showing the land's contribution regardless — it always applies.

## 4. Land cards — inventory and Home

- [ ] Add the band to the land card HUD, which already carries Durability, Land Boost and Allowed Miner.
- [ ] The existing **"Land Boost"** figure is misleading on its own. Render it as **"+12% (Uncommon · Rare · Epic)"**, not a bare `+12%`.

---

## Acceptance

- [ ] A player with only a Common miner sees a warning before crafting Diamond Land
- [ ] The same player, having bought it anyway, sees "not applied — miner out of band" in the expedition panel
- [ ] The Gold bonus still shows as applying, in every one of those screens
- [ ] Every band string is derived from `landminmatch`, never hardcoded — verified by changing a `matchset` row and reloading

---

## ⚠️ Announce the rebalance before applying it

The new bands remove Common and Uncommon from Diamond Land, which they are boosted by **today**:

```
Common + Common gear on Diamond Land:   85.39 FT  ->  74.25 FT   (-13%)
```

Anyone currently pairing a low-tier miner with Diamond Land takes a real cut. Ship the UI first, announce the change, then apply `FIX_D1=matched`. Applying it silently would look like a stealth nerf, and players who paid 21 Gold for Diamond Land would be right to complain.
