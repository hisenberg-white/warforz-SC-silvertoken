# Free-play: the economy spec and the contract describe different games

**A cross-document inconsistency, live on testnet. Not a code defect — a specification and balancing problem.**

| | |
|---|---|
| Found | 2026-09-05, during the Robinhood Chain port's business-logic verification |
| Severity | **High** — it determines whether free-to-play is genuine free entry |
| Code defect? | **No.** `warforzlands.cpp` does exactly what it says |
| Affects | `WARFORZLANDS_ECONOMY_CONFIG_V1.md` §3, §11, §16 · `scripts/seed-config.sh:248-253` · the `fpselectors` table on testnet |
| Blocks | Nothing on Robinhood Chain — that port matches the contract verbatim per its parity rule. This is a **WAX-side** decision |

---

## 1. The inconsistency

`WARFORZLANDS_ECONOMY_CONFIG_V1.md` §3 and the shipped contract describe two different mechanics with the same name.

| | Economy V1 §3, §11 | `warforzlands.cpp:2262` |
|---|---|---|
| Must the player own a miner? | **No** | **Yes** |
| What does RNG decide? | Which **temporary miner** you receive | Which miner **type is permitted** |
| Scope of the roll | **Per mining attempt, per player** | **Global, one per hour, everyone shares it** |
| Player keeps the rolled miner? | No — temporary, vanishes after the mine | N/A — they mine with their own |
| You own Common, window is "rare" | Irrelevant — you get a fresh roll | **You cannot mine at all this hour** |
| Free-play uptime for any given player | **100%** | **= that tier's share of hours** |

### What Economy V1 says

> "It provides: … **No player-selected miner**, **RNG-based temporary miner selection**"
> "The RNG-selected miner is temporary. The player does **not** receive ownership of the selected miner NFT."

### What the contract does

```cpp
// warforzlands.cpp:2262 — inside mine(), after compatibility checks
if (lc->is_freeplay) {
    freeplaystate_sgt fp(get_self(), get_self().value);
    check(fp.exists(), "free-play not initialized");
    check(mc->miner_type == fp.get().current_allowed_selector,
          "wrong miner type for the current free-play window");
}
```

`mc` is the config of a miner **the player already owns and has placed**. There is no temporary-miner path anywhere in the source. `fprotate` rolls one selector per hour for the entire playerbase.

Both are coherent designs. Only one is running.

---

## 2. The consequence: the weights were transplanted, not derived

`scripts/seed-config.sh:248-253` feeds Economy V1's **temporary-miner pool** percentages directly into `fpselectors`:

```sh
push fpselset '{"selector_value":"artifact","weight":5500,"rotation_period_sec":3600}'
push fpselset '{"selector_value":"common","weight":2500,...}'
push fpselset '{"selector_value":"uncommon","weight":1200,...}'
push fpselset '{"selector_value":"rare","weight":600,...}'
push fpselset '{"selector_value":"epic","weight":175,...}'
push fpselset '{"selector_value":"legendary","weight":25,...}'
```

Those six numbers were chosen to answer:

> *"When a free-play player rolls, what are the odds of getting an Artifact miner?"*

They are now answering:

> *"What fraction of all hours is free-play land restricted to Artifact owners only?"*

**Nobody decided the second question.** The numbers are inherited.

### What they actually produce

Rotation is hourly and the standard miner cooldown is 1 hour, so a player gets roughly one mining opportunity per window. "Share of hours your tier is selected" is therefore approximately **"share of your possible free-play mines you can actually make."**

| Tier | Weight | Share of hours | Access per 24 h | Verdict |
|---|---:|---:|---|---|
| Artifact | 5500 | 55.00% | ~13.2 h | Fine |
| Common | 2500 | 25.00% | ~6.0 h | Fine |
| Uncommon | 1200 | 12.00% | ~2.9 h | Workable |
| Rare | 600 | 6.00% | ~1.4 h | Thin |
| **Epic** | 175 | **1.75%** | **~25 min** | ❌ Effectively locked out |
| **Legendary** | 25 | **0.25%** | **~3.6 min** | ❌ Effectively locked out |

An Epic owner gets roughly 25 minutes of free-play access per day, arriving at random times. With a one-hour cooldown, actually catching that window is luck. Legendary is ~3.6 minutes — statistically, never.

Under Economy V1's design those same numbers were harmless: everyone mined every time, and the roll only decided *which reward profile* you got. Under the shipped mechanic they are a **lockout schedule**.

---

## 3. Does the tail even matter?

Arguably not, and this is the key balancing question.

Free-play land gives **0% FT boost and 0% Gold bonus** (Economy V1 §2). An Epic or Legendary owner has no reason to use it — they own premium land, which is strictly better. The players who *depend* on free-play land are new or low-capital, and they hold Artifact and Common miners.

So the 80% weighting toward Artifact + Common is **defensible for the population that actually uses free land**. The problem is confined to the tail: it reserves ~2% of all hours for players who do not need it, and during those hours **everyone who does need it is locked out**.

That is the real cost. Roughly **1 hour in 50, free-play land serves nobody.**

---

## 4. Options

### Option A — Correct the docs, keep the mechanic *(smallest change)*

1. Rewrite Economy V1 §3, §11 and §16 to describe the hourly type gate.
2. **Re-derive the weights** for the question they now answer.
3. Note in §2 that free-play access is time-shared, not continuous.

Suggested starting weights — remove tiers that do not need free land, and give the ones that do continuous coverage:

| Tier | Current | Proposed | Rationale |
|---|---:|---:|---|
| Artifact | 5500 | **5000** | The F2P default miner |
| Common | 2500 | **3000** | First crafted tier; the main progression cohort |
| Uncommon | 1200 | **1500** | |
| Rare | 600 | **500** | |
| Epic | 175 | **0** *(remove)* | Owns premium land; does not need free land |
| Legendary | 25 | **0** *(remove)* | Same |

Removing a tier is safe: `fpseldel` refuses to delete the **currently active** selector, so do it during a window that tier does not hold.

⚠️ **Omitting a tier re-normalises the rest** (`WARFORZLANDS_CONTRACT.md` §7.5) — a partial pool does not preserve the intended distribution. The proposed column already sums to 10,000, so state it explicitly rather than relying on re-normalisation.

### Option B — Implement Economy V1's design *(largest change, best funnel)*

Add a temporary-miner path to `mine()` for free-play land: roll a tier from `fpselectors`, use that tier's `minerconf` for the reward calculation, grant no ownership, require no miner.

- **Pro:** free-play becomes genuine free entry, which is what Economy V1 §12 and §15 describe — *"free entry into the ecosystem."* Uptime goes from tier-dependent to 100%.
- **Pro:** the existing weights become correct again, because they would once more be answering the question they were written for.
- **Con:** real contract work on the most security-sensitive function, plus a redeploy. `fprotate`, `freeplaystat` and the rotation become unnecessary for this path.
- **Con:** needs a health/cooldown model for a miner nobody owns — probably a per-account free-play cooldown instead of a per-miner one.

### Option C — Allow multiple tiers per window

Change `current_allowed_selector` from one `name` to a set or bitmask, e.g. "this hour, Artifact + Common + Uncommon may mine." Keeps the rotation flavour, removes the lockout. Middle-sized change; needs a table migration.

---

## 5. Recommendation

**Option A now, Option B considered for V2.**

Option A is a documentation fix plus six `fpselset` calls — no redeploy, no risk, and it removes the lockout immediately. It is also the honest fix: the docs should describe the game that exists.

Option B is the better game, and it matters more once Robinhood Chain is live, where a new player already needs ETH before their first action. But it touches `mine()`, and `mine()` is where a bug costs real money. It should go through the same audit and soak as any other change to that function — not a quick patch.

Whichever you choose, **the Robinhood Chain port follows automatically** — it implements whatever the WAX contract implements, and the cross-chain differential test is what proves it stayed that way.

---

## 6. Checklist

- [ ] Decide A, B or C
- [ ] If A — rewrite Economy V1 §3, §11, §16 to match the contract
- [ ] If A — re-derive and re-seed the six `fpselectors` weights; make them sum to 10,000 explicitly
- [ ] If A — confirm the removed tiers are not the active selector at the time of deletion
- [ ] Update `scripts/seed-config.sh:248-253` so fresh deployments carry the corrected weights
- [ ] Update `WARFORZLANDS_CONTRACT.md` §7.5 to note the uptime consequence of the weighting
- [ ] Mirror the decision into `robinhood chain/SmartContract/config/economy.v1.json`
- [ ] Add a scenario test: player owns tier X, window is tier Y ≠ X → `mine()` rejects with *"wrong miner type for the current free-play window"*

---

## Appendix — related items found in the same sweep

Verified present and correct in the WAX contract; listed only so they are not re-flagged later:

| Item | Where | Status |
|---|---|---|
| Referral cycle detection, walks `referral_cycle_depth` ancestors | `:1764` | ✅ correct |
| Free-play land must have `unlimited_durability` | `:1010` | ✅ enforced |
| Cannot delete the active free-play selector | `:1201` | ✅ enforced |
| `max_freeplay_lands_per_account` enforced at activation | `:1873` | ✅ enforced |
| Dead miner's NFT is burned, template usage decremented | `:2702` | ✅ correct |
| Death risk warned in the UI before signing, to 2 d.p. | `MineControls.tsx:234` | ✅ correct |

The only documentation nit alongside this one: `WARFORZLANDS_CONTRACT.md` §7.2's resolution sequence ends *"→ miner health, cooldown, detach →"* and does not name the NFT burn on death at that line, though §12 states the general rule. Worth one clause for completeness.
