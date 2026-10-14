#!/usr/bin/env bash
set -euo pipefail

# Repairs the three economy divergences found by WARFORZLANDS_ECONOMY_AUDIT.md.
# Config only — no redeploy, no code change.
#
#   ./scripts/fix-economy.sh testnet                       # DRY RUN, prints only
#   APPLY=YES FIX_D1=matched   ./scripts/fix-economy.sh testnet   # CHOSEN: rebalanced tier bands
#   APPLY=YES FIX_D1=universal ./scripts/fix-economy.sh testnet   # alternative: V1 universal boost
#   APPLY=YES FIX_D1=none      ./scripts/fix-economy.sh testnet   # leave the chain untouched
#
# Never stores or imports keys; cleos must use an already unlocked local wallet.
#
# D1  Premium land FT boost is gated by miner type.  Economy V1 §2/§17 require
#     it to apply to EVERY miner rarity. Live: land_bonus=1.00 on every land and
#     the boost sits in landminmatch keyed on (land_type, miner_type), so Epic
#     Land gives a Common miner nothing.                      NEEDS A DECISION.
# D2  RESOLVED 2026-09-05: 3600s IS the intended design. Live config is already
#     correct, so this script leaves it alone by default. The remaining D2 work
#     is documentation plus a guard against the contract's 300s fallback --
#     see WARFORZLANDS_ECONOMY_AUDIT.md. Set FIX_D2=YES only to re-assert it.
# D3  Free-play mechanic — see WARFORZLANDS_FREEPLAY_GAP.md.   NOT SCRIPTED:
#     needs a design decision, and Option B needs contract work.

PROFILE="${1:-}"
case "$PROFILE" in
  testnet) DEFAULT_NODE="https://test.wax.eosusa.io"; EXPECTED_CHAIN="f16b1833c747c43682f4386fca9cbb327929334a762755ebec17f6f23c9b8a12" ;;
  mainnet)
    DEFAULT_NODE="https://wax.greymass.com"; EXPECTED_CHAIN="1064487b3cd1a897ce03ae5b6a865651747e2e152090f99c1d19d44e01aea5a4"
    [[ "${CONFIRM_MAINNET:-}" == YES ]] || { echo "Set CONFIRM_MAINNET=YES after reviewing all values." >&2; exit 2; }
    ;;
  *) echo "Usage: $0 testnet|mainnet" >&2; exit 2 ;;
esac

NODE="${NODE:-$DEFAULT_NODE}" CONTRACT="${CONTRACT:-warforzlands}"
AUTH="${AUTH:-${CONTRACT}@active}"
CLEOS=(cleos -u "$NODE")
APPLY="${APPLY:-}"
FIX_D1="${FIX_D1:-none}"        # matched | universal | none
FIX_D2="${FIX_D2:-}"            # YES to re-assert cooldowns (normally unnecessary)
LAND_COOLDOWN_SEC="${LAND_COOLDOWN_SEC:-3600}"   # 1 hour -- confirmed intended

LAND_EPIC="${LAND_EPIC:-664513}"
LAND_LEGENDARY="${LAND_LEGENDARY:-664514}"
LAND_DIAMOND="${LAND_DIAMOND:-664515}"
FREEPLAY_LAND="${FREEPLAY_LAND:-664521}"

# ---- guards -----------------------------------------------------------------
chain="$("${CLEOS[@]}" get info | sed -n 's/.*"chain_id": *"\([^"]*\)".*/\1/p')"
[[ "$chain" == "$EXPECTED_CHAIN" ]] || { echo "Chain mismatch: $chain != $EXPECTED_CHAIN" >&2; exit 3; }
case "$FIX_D1" in matched|universal|none) ;; *) echo "FIX_D1 must be 'matched', 'universal' or 'none'" >&2; exit 2 ;; esac

echo "node=$NODE contract=$CONTRACT auth=$AUTH"
echo "D2 land cooldown -> ${LAND_COOLDOWN_SEC}s (apply: ${FIX_D2:-no})"
echo "D1 mode          -> $FIX_D1"
[[ "$APPLY" == YES ]] || echo "*** DRY RUN — set APPLY=YES to execute ***"
echo

push() { # action json
  echo "  push action $CONTRACT $1 '$2'"
  [[ "$APPLY" == YES ]] || return 0
  "${CLEOS[@]}" push action "$CONTRACT" "$1" "$2" -p "$AUTH" >/dev/null
}

echo "=== BEFORE ==="
"${CLEOS[@]}" get table "$CONTRACT" "$CONTRACT" landconf     | sed 's/^/  /'
"${CLEOS[@]}" get table "$CONTRACT" "$CONTRACT" landminmatch | sed 's/^/  /'
"${CLEOS[@]}" get table "$CONTRACT" "$CONTRACT" landcdconf   | sed 's/^/  /'
echo

# ---- D2: land cooldown ------------------------------------------------------
# 3600s is the INTENDED design (confirmed 2026-09-05) and is already live, so
# this block is a no-op by default. Land cooldown == miner cooldown means one
# land serves one mine per hour, so land scales 1:1 with miners. That is the
# design, not a defect. Only the docs and the contract's 300s fallback need
# attention -- see WARFORZLANDS_ECONOMY_AUDIT.md.
if [[ "$FIX_D2" == YES ]]; then
  echo "=== D2: re-assert land cooldown -> ${LAND_COOLDOWN_SEC}s ==="
  for t in "$LAND_EPIC" "$LAND_LEGENDARY" "$LAND_DIAMOND" "$FREEPLAY_LAND"; do
    push landcdset "{\"template_id\":$t,\"cooldown_sec\":$LAND_COOLDOWN_SEC}"
  done
else
  echo "=== D2: SKIPPED -- 3600s is intended and already live ==="
  echo "    Remaining D2 work is documentation only; see the audit doc."
fi
echo

# ---- D1: land FT boost ------------------------------------------------------
if [[ "$FIX_D1" == universal ]]; then
  echo "=== D1: restore the Economy V1 universal land boost ==="
  echo "    landset is a FULL-ROW setter — every field is restated at its"
  echo "    audited-correct value; only land_bonus changes (1.00 -> V1)."
  echo
  # V1 §2: Epic +10%, Legendary +12%, Diamond +15%, applied to EVERY miner.
  # durability / nft_drop_bonus below are the live values, already verified
  # correct against V1 by WARFORZLANDS_ECONOMY_AUDIT.md — do not change them.
  push landset "{\"template_id\":$LAND_EPIC,\"rarity\":4,\"durability_max\":75,\"unlimited_durability\":false,\"is_freeplay\":false,\"land_type\":\"epic\",\"land_bonus\":1.10,\"compatible_miner_types\":[],\"compatible_mining_types\":[],\"nft_drop_bonus\":0.01}"
  push landset "{\"template_id\":$LAND_LEGENDARY,\"rarity\":5,\"durability_max\":300,\"unlimited_durability\":false,\"is_freeplay\":false,\"land_type\":\"legendary\",\"land_bonus\":1.12,\"compatible_miner_types\":[],\"compatible_mining_types\":[],\"nft_drop_bonus\":0.01}"
  push landset "{\"template_id\":$LAND_DIAMOND,\"rarity\":6,\"durability_max\":600,\"unlimited_durability\":false,\"is_freeplay\":false,\"land_type\":\"diamond\",\"land_bonus\":1.15,\"compatible_miner_types\":[],\"compatible_mining_types\":[],\"nft_drop_bonus\":0.0125}"
  echo
  # CRITICAL: the two multipliers COMPOUND in the reward formula
  #   gross = base x gear x land_bonus x match_bonus x mining_multiplier
  # Leaving a match row while land_bonus is set gives 1.10 x 1.10 = 1.21.
  # Every pairing row must go.
  echo "  --- remove every landminmatch row (they would compound) ---"
  push matchdel '{"land_type":"epic","miner_type":"epic"}'
  push matchdel '{"land_type":"legendary","miner_type":"legendary"}'
  for m in common uncommon rare epic legendary; do
    push matchdel "{\"land_type\":\"diamond\",\"miner_type\":\"$m\"}"
  done
  echo
elif [[ "$FIX_D1" == matched ]]; then
  echo "=== D1: rebalance the tier-matched bands (CHOSEN 2026-09-05) ==="
  echo "    Keeps land_bonus at 1.00 and the boost in landminmatch, but widens"
  echo "    the bands so no land is dead weight and Diamond stops dominating."
  echo "    Bands OVERLAP so every miner rarity has at least one land."
  echo
  # Rationale: a % boost is worth more in absolute FT to a high-output miner,
  # while land costs the same per use whatever mines on it. So better land
  # pairs with better miners -- and the cheapest land stays affordable for the
  # entry tiers. Bands overlap so mid tiers get a budget AND a premium option.
  #
  #   Epic Land      +10%  -> common, uncommon, rare   (NOT artifact -- see below)
  #   Legendary Land +12%  -> uncommon, rare, epic
  #   Diamond Land   +15%  -> rare, epic, legendary
  #
  # Old rows go first: matchset MODIFIES an existing pair, so a stale pairing
  # would otherwise survive silently.
  echo "  --- clear the old pairings ---"
  push matchdel '{"land_type":"epic","miner_type":"epic"}'
  push matchdel '{"land_type":"legendary","miner_type":"legendary"}'
  for m in common uncommon rare epic legendary; do
    push matchdel "{\"land_type\":\"diamond\",\"miner_type\":\"$m\"}"
  done
  echo
  # ARTIFACT IS DELIBERATELY EXCLUDED from every band. An Artifact miner
  # grosses 27 FT; the cheapest premium land costs 43.6 FT per use. Even WITH
  # the boost applied it loses 24-33 FT per mine (see WARFORZLANDS_PROFITABILITY.md
  # SS3, Trap 1). Putting it in a band would advertise a boost that leads players
  # into a guaranteed loss. Artifact miners belong on F2P land.
  echo "  --- Epic Land +10% -> common, uncommon, rare ---"
  for m in common uncommon rare; do
    push matchset "{\"land_type\":\"epic\",\"miner_type\":\"$m\",\"bonus_multiplier\":1.10}"
  done
  echo "  --- Legendary Land +12% -> uncommon, rare, epic ---"
  for m in uncommon rare epic; do
    push matchset "{\"land_type\":\"legendary\",\"miner_type\":\"$m\",\"bonus_multiplier\":1.12}"
  done
  echo "  --- Diamond Land +15% -> rare, epic, legendary ---"
  for m in rare epic legendary; do
    push matchset "{\"land_type\":\"diamond\",\"miner_type\":\"$m\",\"bonus_multiplier\":1.15}"
  done
  echo
  echo "  NOTE: artifact/legendary miner templates are not minted on testnet."
  echo "        matchset does NOT validate miner_type against minerconf, so"
  echo "        these rows are accepted and simply lie dormant until minted."
  echo
else
  echo "=== D1: SKIPPED (FIX_D1=none) ==="
  echo "    Chain left untouched."
  echo
fi

if [[ "$APPLY" == YES ]]; then
  echo "=== AFTER ==="
  "${CLEOS[@]}" get table "$CONTRACT" "$CONTRACT" landconf     | sed 's/^/  /'
  "${CLEOS[@]}" get table "$CONTRACT" "$CONTRACT" landminmatch | sed 's/^/  /'
  "${CLEOS[@]}" get table "$CONTRACT" "$CONTRACT" landcdconf   | sed 's/^/  /'
fi

cat <<'NOTE'

--- STILL TO DO BY HAND ---

1. D2 is a DOCUMENTATION fix, not a chain fix. 3600s is intended and live.
   a) WARFORZ_DEPLOYMENT.md 182 wrongly says the seeder defaults to 300.
      It defaults to 3600, which is correct.
   b) 182's rationale reads as if 3600 were the bug being fixed. Reword it
      so a future reader does not "fix" it back down to 300.
   c) Economy V1 never mentions land cooldown. Add it to 2 -- right now the
      value exists only inside a shell script and nothing can audit it.
   d) GUARD: the contract falls back to DEFAULT_LAND_COOLDOWN_SEC = 300 when a
      land template has no landcdconf row. All four templates have one today,
      but a NEW land template added without landcdset silently gets 5 minutes
      instead of an hour. Add a post-seed assertion that every landconf row
      has a matching landcdconf row.

2. UPDATE seed-config.sh (~line 210) or the next re-seed silently reverts D1:
       MATCH_EPIC_TYPES="${MATCH_EPIC_TYPES:-common uncommon rare}"
       MATCH_LEGENDARY_TYPES="${MATCH_LEGENDARY_TYPES:-uncommon rare epic}"
       MATCH_DIAMOND_TYPES="${MATCH_DIAMOND_TYPES:-rare epic legendary}"
   Leave land_bonus at 1 and leave MATCH_EPIC/LEGENDARY/DIAMOND at 1.10/1.12/1.15.

3. Economy V1 is silent on land cooldown. Add it to §2 so the seeder has a
   spec to be checked against.

4. D3 (free-play) is not scripted — see WARFORZLANDS_FREEPLAY_GAP.md.

5. Re-run WARFORZLANDS_ECONOMY_AUDIT.md's verification commands and record
   the result.

--- EXPECTED EFFECT (FIX_D1=matched) ---
  Common   + Common gear on Epic Land       74.25 -> 81.68 FT   (+10%, newly boosted)
  Rare     + Rare   gear on Legendary Land 228.00 -> 255.36 FT  (+12%, newly boosted)
  Artifact  stays UNBOOSTED on every premium land -- it loses 24-33 FT/mine
            there regardless of the boost. F2P land only.
  Common   + Common gear on Diamond Land     85.39 -> 74.25 FT   (-15%, NOW OUT OF BAND)
  Legendary+ Legend gear on Diamond Land    583.05 -> 583.05 FT  (unchanged, peak)

  ** Common/Uncommon miners LOSE the Diamond Land boost they have today. **
  Announce this before applying it -- it is a nerf for anyone currently
  pairing a low-tier miner with Diamond Land.
  Peak reservation is UNCHANGED at 583.05 FT (195 x 2.60 x 1.15).
  Land cooldown is UNCHANGED at 1 hour (confirmed intended).
NOTE
