#!/usr/bin/env bash
set -euo pipefail

# Complete Warforz Lands configuration seeder. It never stores/imports keys;
# cleos must use an already unlocked local wallet.
#   ./scripts/seed-config.sh testnet
#   CONFIRM_MAINNET=YES FEE_ACCOUNT=treasuryacct ./scripts/seed-config.sh mainnet
#
# Every economic value below comes from WARFORZLANDS_ECONOMY_CONFIG_V1.md.
# Section references (V1 §n) are given at each block so a balance change can be
# traced back to the document. Do not "tidy" these numbers — they are balanced
# against each other and against the 1 Gold = 1,000 FT reference rate.

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
AUTH="${AUTH:-${CONTRACT}@active}" COLLECTION="${COLLECTION:-warforzlands}"
FEE_ACCOUNT="${FEE_ACCOUNT:-warforzfees1}" FT_CONTRACT="${FT_CONTRACT:-eosio.token}"
FT_SYMBOL="${FT_SYMBOL:-8,WAX}" FT_DISPLAY_NAME="${FT_DISPLAY_NAME:-WAX}"
FT_CODE="${FT_SYMBOL#*,}" FT_PRECISION="${FT_SYMBOL%%,*}"
NFT_SCHEMA="${NFT_SCHEMA:-currency}" NFT_DISPLAY_NAME="${NFT_DISPLAY_NAME:-Gold}"
# Optional welcome NFT minted once when a player first accepts the ToS.
# Leave SIGNUP_NFT_TEMPLATE at 0/unset to preserve registration without minting.
SIGNUP_NFT_SCHEMA="${SIGNUP_NFT_SCHEMA:-signup}"
SIGNUP_NFT_TEMPLATE="${SIGNUP_NFT_TEMPLATE:-0}"
WITHDRAW_FEE_PCT="${WITHDRAW_FEE_PCT:-5}" MINING_FEE_PCT="${MINING_FEE_PCT:-0}"
# REFERRAL_RATE is the cut of MINING rewards and stays off for V1.
# REFERRAL_WITHDRAW_PCT is the referrer's share of a referee's WITHDRAWAL,
# carved out of the platform fee (max 5%, the floor of the hourly 5-9% roll),
# so a referred player never receives less than an unreferred one.
REFERRAL_RATE="${REFERRAL_RATE:-0}" REFERRAL_WITHDRAW_PCT="${REFERRAL_WITHDRAW_PCT:-2}"
TOS_VERSION="${TOS_VERSION:-1}"
TOS_TEXT="${TOS_TEXT:-By playing Warforz Lands you accept the published terms, blockchain risks, irreversible NFT burns, and smart-contract rules.}"

# V1 §8: no combination of miner, equipment, land or mining-type bonuses may
# push the final Gold chance above this. 0 would disable the cap entirely.
MAX_GOLD_CHANCE="${MAX_GOLD_CHANCE:-0.10}"

# ---- AtomicAssets templates -------------------------------------------------
# Existing, already minted on testnet:
MINER_COMMON="${MINER_COMMON:-664504}" MINER_UNCOMMON="${MINER_UNCOMMON:-664505}"
MINER_RARE="${MINER_RARE:-664506}" MINER_EPIC="${MINER_EPIC:-664507}"
EQUIP_COMMON="${EQUIP_COMMON:-664510}" EQUIP_UNCOMMON="${EQUIP_UNCOMMON:-664511}" EQUIP_RARE="${EQUIP_RARE:-664512}"
LAND_EPIC="${LAND_EPIC:-664513}" LAND_LEGENDARY="${LAND_LEGENDARY:-664514}" LAND_DIAMOND="${LAND_DIAMOND:-664515}"
GOLD_TEMPLATE="${GOLD_TEMPLATE:-664516}" SLOT_2_TEMPLATE="${SLOT_2_TEMPLATE:-664517}"
SLOT_3_TEMPLATE="${SLOT_3_TEMPLATE:-664519}" SLOT_4_TEMPLATE="${SLOT_4_TEMPLATE:-664520}"
FREEPLAY_LAND="${FREEPLAY_LAND:-664521}"

# Required by economy V1 but NOT yet minted. There is no safe default: guessing
# a template id silently configures a template that does not exist, and the
# contract cannot detect that. Supply them explicitly, or set
# ALLOW_MISSING_TIERS=YES to seed everything else first.
MINER_ARTIFACT="${MINER_ARTIFACT:-0}" MINER_LEGENDARY="${MINER_LEGENDARY:-0}"
EQUIP_EPIC="${EQUIP_EPIC:-0}" EQUIP_LEGENDARY="${EQUIP_LEGENDARY:-0}"

missing_tiers=()
[[ "$MINER_ARTIFACT"  != 0 ]] || missing_tiers+=("MINER_ARTIFACT (V1 §5 Artifact/F2P miner)")
[[ "$MINER_LEGENDARY" != 0 ]] || missing_tiers+=("MINER_LEGENDARY (V1 §5 Legendary miner)")
[[ "$EQUIP_EPIC"      != 0 ]] || missing_tiers+=("EQUIP_EPIC (V1 §6 Epic equipment)")
[[ "$EQUIP_LEGENDARY" != 0 ]] || missing_tiers+=("EQUIP_LEGENDARY (V1 §6 Legendary equipment)")
if (( ${#missing_tiers[@]} )) && [[ "${ALLOW_MISSING_TIERS:-}" != YES ]]; then
  echo "These economy V1 templates have no id configured:" >&2
  printf '  - %s\n' "${missing_tiers[@]}" >&2
  echo "Mint them in the '$COLLECTION' collection and pass their ids, or set" >&2
  echo "ALLOW_MISSING_TIERS=YES to seed the remaining tiers now." >&2
  exit 2
fi
if (( ${#missing_tiers[@]} )); then
  echo "WARNING: seeding an INCOMPLETE economy; these tiers are skipped:" >&2
  printf '  - %s\n' "${missing_tiers[@]}" >&2
  echo "The free-play miner pool will not match V1 §3 until they are added." >&2
fi

[[ "$PROFILE" != mainnet || "$FEE_ACCOUNT" != warforzfees1 ]] || { echo "Set a production FEE_ACCOUNT." >&2; exit 2; }
if [[ "$PROFILE" == mainnet ]] && (( ${#missing_tiers[@]} )); then
  echo "Refusing to seed an incomplete economy on mainnet." >&2; exit 2
fi
chain_id="$(cleos -u "$NODE" get info | tr -d '\r\n ' | sed -n 's/.*"chain_id":"\([0-9a-f]*\)".*/\1/p')"
[[ "$chain_id" == "$EXPECTED_CHAIN" ]] || { echo "Wrong chain ID: ${chain_id:-unknown}" >&2; exit 3; }
cleos -u "$NODE" get account "$CONTRACT" >/dev/null
cleos -u "$NODE" get account "$FEE_ACCOUNT" >/dev/null

# This seeder is deliberately for a fresh/wiped deployment. Refuse partial
# overwrites: use admin setters for later isolated live changes.
existing_config="$(cleos -u "$NODE" get table "$CONTRACT" "$CONTRACT" config --limit 1)"
if printf '%s' "$existing_config" | grep -q '"maintenance_mode"' && [[ "${SEED_RESUME:-}" != YES ]]; then
  echo "Contract is partially/configured. Set SEED_RESUME=YES to resume/upsert this reviewed seed." >&2
  exit 4
fi

CLEOS_TIMEOUT="${CLEOS_TIMEOUT:-45}"
SEED_DELAY="${SEED_DELAY:-1}"
push() {
  echo "==> $1 $2"
  timeout --foreground "${CLEOS_TIMEOUT}s" cleos -u "$NODE" push action "$CONTRACT" "$1" "$2" -p "$AUTH" || {
    status=$?
    [[ $status -ne 124 ]] || echo "Timed out after ${CLEOS_TIMEOUT}s at action '$1'. Check RPC and retry with SEED_RESUME=YES." >&2
    return "$status"
  }
  sleep "$SEED_DELAY"
}
row_exists() {
  local table="$1" scope="$2" key_name="$3" key="$4"
  timeout --foreground "${CLEOS_TIMEOUT}s" cleos -u "$NODE" get table "$CONTRACT" "$scope" "$table" --limit 1000 \
    | grep -Eq "\"${key_name}\"[[:space:]]*:[[:space:]]*\"?${key}\"?"
}
escape() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; printf %s "$s"; }
# Render a plain number as an asset string at the configured FT precision, so
# the same balance figures work against an 8-decimal or 4-decimal token.
ft() { printf "%.${FT_PRECISION}f %s" "$1" "$FT_CODE"; }

echo "Seeding $PROFILE on $NODE (maintenance remains enabled)"
push configset "{\"maintenance_mode\":true,\"collection_name\":\"$COLLECTION\",\"mining_fee_pct\":$MINING_FEE_PCT,\"referral_rate\":$REFERRAL_RATE,\"max_freeplay_lands_per_account\":1,\"referral_cycle_depth\":10,\"max_nft_drop_rate\":$MAX_GOLD_CHANCE}"
push ftconfigset "{\"token_contract\":\"$FT_CONTRACT\",\"token_symbol\":\"$FT_SYMBOL\",\"display_name\":\"$(escape "$FT_DISPLAY_NAME")\",\"fee_account\":\"$FEE_ACCOUNT\",\"withdraw_fee_pct\":$WITHDRAW_FEE_PCT,\"referral_withdraw_pct\":$REFERRAL_WITHDRAW_PCT}"
push nftconfigset "{\"collection\":\"$COLLECTION\",\"schema\":\"$NFT_SCHEMA\",\"template_ids\":[$GOLD_TEMPLATE],\"display_name\":\"$(escape "$NFT_DISPLAY_NAME")\"}"
if [[ "$SIGNUP_NFT_TEMPLATE" != 0 ]]; then
  push signupnftset "{\"schema_name\":\"$SIGNUP_NFT_SCHEMA\",\"template_id\":$SIGNUP_NFT_TEMPLATE}"
else
  echo "Signup NFT is not configured; registration will continue without a welcome mint."
fi
push tosset "{\"version\":$TOS_VERSION,\"tos\":\"$(escape "$TOS_TEXT")\"}"

# ---- Miners (V1 §5) ---------------------------------------------------------
# base_reward_rate  = Base FT per successful mine (whole tokens).
# base_nft_drop_rate= Gold chance as a fraction; V1 §16 deliberately INVERTS the
#                     usual curve — higher rarity yields LESS Gold and more FT.
# health_cost_per_mine = the miner's own damage per mine (V1 §5 Damage column).
# health_cost_per_point = 5 FT per HP healed (V1 §4), identical for every tier.
HEAL_COST="$(ft 5)"
miner() { # template type rarity base_ft gold_chance cooldown damage
  push minerset "{\"template_id\":$1,\"miner_type\":\"$2\",\"rarity\":$3,\"health_max\":200,\"base_reward_rate\":$4,\"base_nft_drop_rate\":$5,\"cooldown_sec\":$6,\"compatible_land_types\":[],\"compatible_equipment_types\":[\"equipment\"],\"health_cost_per_point\":\"$HEAL_COST\",\"health_cost_per_mine\":$7}"
}
[[ "$MINER_ARTIFACT" == 0 ]]  || miner "$MINER_ARTIFACT"  artifact  1  27 0.005 7200  5
miner "$MINER_COMMON"   common    2  55 0.05  3600 10
miner "$MINER_UNCOMMON" uncommon  3  85 0.04  3600 15
miner "$MINER_RARE"     rare      4 120 0.03  3600 20
miner "$MINER_EPIC"     epic      5 155 0.02  3600 25
[[ "$MINER_LEGENDARY" == 0 ]] || miner "$MINER_LEGENDARY" legendary 6 195 0.015 3600 30

# ---- Equipment (V1 §6) ------------------------------------------------------
# reward_boost   = FT multiplier applied before the land boost.
# nft_drop_boost = percentage POINTS added to the Gold chance (0.025 = +2.50%).
#                  V1 §7 makes Common the Gold-farming tier and Legendary the
#                  FT tier, so this value FALLS as rarity rises.
equip() { # template rarity reward_boost gold_points
  push equipset "{\"template_id\":$1,\"equipment_type\":\"equipment\",\"rarity\":$2,\"durability_max\":125,\"reward_boost\":$3,\"nft_drop_boost\":$4,\"compatible_miner_types\":[],\"compatible_mining_types\":[]}"
}
equip "$EQUIP_COMMON"   1 1.35 0.025
equip "$EQUIP_UNCOMMON" 2 1.60 0.020
equip "$EQUIP_RARE"     3 1.90 0.015
[[ "$EQUIP_EPIC" == 0 ]]      || equip "$EQUIP_EPIC"      4 2.25 0.0075
[[ "$EQUIP_LEGENDARY" == 0 ]] || equip "$EQUIP_LEGENDARY" 5 2.60 0.0025

# ---- Land (V1 §2) -----------------------------------------------------------
# land_bonus     = FT multiplier, so V1's "+10% FT" is 1.10.
# nft_drop_bonus = percentage POINTS added to the Gold chance.
# Premium land carries no miner restriction (V1 §17); only free-play does, and
# that restriction is enforced by the rotation rather than by these lists.
push landset "{\"template_id\":$LAND_EPIC,\"rarity\":4,\"durability_max\":75,\"unlimited_durability\":false,\"is_freeplay\":false,\"land_type\":\"epic\",\"land_bonus\":1,\"compatible_miner_types\":[],\"compatible_mining_types\":[],\"nft_drop_bonus\":0.01}"
push landset "{\"template_id\":$LAND_LEGENDARY,\"rarity\":5,\"durability_max\":300,\"unlimited_durability\":false,\"is_freeplay\":false,\"land_type\":\"legendary\",\"land_bonus\":1,\"compatible_miner_types\":[],\"compatible_mining_types\":[],\"nft_drop_bonus\":0.01}"
push landset "{\"template_id\":$LAND_DIAMOND,\"rarity\":6,\"durability_max\":600,\"unlimited_durability\":false,\"is_freeplay\":false,\"land_type\":\"diamond\",\"land_bonus\":1,\"compatible_miner_types\":[],\"compatible_mining_types\":[],\"nft_drop_bonus\":0.0125}"
push landset "{\"template_id\":$FREEPLAY_LAND,\"rarity\":1,\"durability_max\":0,\"unlimited_durability\":true,\"is_freeplay\":true,\"land_type\":\"freeplay\",\"land_bonus\":1,\"compatible_miner_types\":[],\"compatible_mining_types\":[],\"nft_drop_bonus\":0}"

# ---- Land cooldowns ---------------------------------------------------------
# How long a LAND rests between mines. Deliberately independent of the miner's
# own cooldown: a land is a shared venue, so tying the two together idled the
# plot for the full hour of whichever miner used it last, and no second miner
# could work it. The contract defaults to 300s when a template has no row; these
# are set explicitly so the value is visible on chain rather than implied.
# Per-TEMPLATE, so each rarity can differ — the table is keyed by template id
# and every land template is one rarity tier. `LAND_COOLDOWN_SEC` is only the
# shared default; override a single tier with e.g. LAND_COOLDOWN_DIAMOND=1800.
LAND_COOLDOWN_SEC="${LAND_COOLDOWN_SEC:-3600}"
LAND_COOLDOWN_EPIC="${LAND_COOLDOWN_EPIC:-$LAND_COOLDOWN_SEC}"
LAND_COOLDOWN_LEGENDARY="${LAND_COOLDOWN_LEGENDARY:-$LAND_COOLDOWN_SEC}"
LAND_COOLDOWN_DIAMOND="${LAND_COOLDOWN_DIAMOND:-$LAND_COOLDOWN_SEC}"
LAND_COOLDOWN_FREEPLAY="${LAND_COOLDOWN_FREEPLAY:-$LAND_COOLDOWN_SEC}"
push landcdset "{\"template_id\":$LAND_EPIC,\"cooldown_sec\":$LAND_COOLDOWN_EPIC}"
push landcdset "{\"template_id\":$LAND_LEGENDARY,\"cooldown_sec\":$LAND_COOLDOWN_LEGENDARY}"
push landcdset "{\"template_id\":$LAND_DIAMOND,\"cooldown_sec\":$LAND_COOLDOWN_DIAMOND}"
push landcdset "{\"template_id\":$FREEPLAY_LAND,\"cooldown_sec\":$LAND_COOLDOWN_FREEPLAY}"

# ---- Land / miner pairing bonuses (V1 §17) ---------------------------------
# WHO gets a land's boost, and HOW MUCH, both live in the `landminmatch` table
# and are set here — nothing is hardcoded in the contract or the UI.
#
# `landconf.land_bonus` is deliberately left at 1: it is a UNIVERSAL multiplier
# that applied to every miner on the land regardless of type, which is exactly
# what made premium land boost everything equally. The selective bonus belongs
# in this table, keyed on (land_type, miner_type), so an operator can retune
# pairings at runtime with `matchset` without redeploying anything.
#
# Absent pair => no bonus (the contract defaults match_bonus to 1).
MATCH_EPIC="${MATCH_EPIC:-1.10}"
MATCH_LEGENDARY="${MATCH_LEGENDARY:-1.12}"
MATCH_DIAMOND="${MATCH_DIAMOND:-1.15}"
# Space-separated miner types each land rewards. Diamond deliberately lists
# every type — V1: "0.5% boost on every miner".
MATCH_EPIC_TYPES="${MATCH_EPIC_TYPES:-epic}"
MATCH_LEGENDARY_TYPES="${MATCH_LEGENDARY_TYPES:-legendary}"
MATCH_DIAMOND_TYPES="${MATCH_DIAMOND_TYPES:-common uncommon rare epic legendary}"

match_pairs() { # land_type multiplier types...
  local _land="$1" _mult="$2"; shift 2
  for _type in $@; do
    push matchset "{\"land_type\":\"$_land\",\"miner_type\":\"$_type\",\"bonus_multiplier\":$_mult}"
  done
}
match_pairs epic      "$MATCH_EPIC"      $MATCH_EPIC_TYPES
match_pairs legendary "$MATCH_LEGENDARY" $MATCH_LEGENDARY_TYPES
match_pairs diamond   "$MATCH_DIAMOND"   $MATCH_DIAMOND_TYPES

push landdset "{\"template_id\":$LAND_EPIC,\"land_name\":\"Deep Vein Mine\",\"rarity\":\"Epic\",\"img\":\"QmWc56BWmBo4pujCn2DagaBbBUz6DF1MBwnsKojW6E1RXL\"}"
push landdset "{\"template_id\":$LAND_LEGENDARY,\"land_name\":\"Mother Lode\",\"rarity\":\"Legendary\",\"img\":\"QmcohQ6r9yuTxtaA3qmsQdrB1ENsYwC2x9XprYdKmX4gZc\"}"
push landdset "{\"template_id\":$LAND_DIAMOND,\"land_name\":\"Grand Reserve\",\"rarity\":\"Diamond\",\"img\":\"QmdPF7qT8eofphkswYe56y9EXKJyP9pazKVYKeE3fdt5vP\"}"
push landdset "{\"template_id\":$FREEPLAY_LAND,\"land_name\":\"Public Mining Claim\",\"rarity\":\"Artifact\",\"img\":\"QmZLmBYjdTy2JfA7u7nLiVBsyVB6dHyg2PiR37c3SE6nGV\"}"

# ---- Mining types -----------------------------------------------------------
# health_cost is now a MULTIPLIER on the miner's own damage, so 1 means "each
# miner spends exactly its V1 §5 Damage value". V1 defines only normal mining;
# a dangerous type would raise this along with failure/death chance.
# decay_on_failure=false makes Land uses and Equipment uses cost nothing on a
# failed or fatal mine (V1 §2). Normal Mining cannot fail today, so this only
# takes effect once a mining type with a real failure/death chance is added.
push mtypeset '{"mining_type_id":1,"display_name":"Normal Mining","enabled":true,"health_cost":1,"reward_multiplier":1,"nft_drop_bonus":0,"cooldown_sec":0,"failure_chance":0,"death_chance":0,"land_damage_multiplier":1,"equipment_damage_multiplier":1,"decay_on_failure":false,"special_modifiers":[]}'

push slotconfset '{"slot_index":1,"template_id":-1,"enabled":true,"burn_rule":0}'
push slotconfset "{\"slot_index\":2,\"template_id\":$SLOT_2_TEMPLATE,\"enabled\":true,\"burn_rule\":0}"
push slotconfset "{\"slot_index\":3,\"template_id\":$SLOT_3_TEMPLATE,\"enabled\":true,\"burn_rule\":0}"
push slotconfset "{\"slot_index\":4,\"template_id\":$SLOT_4_TEMPLATE,\"enabled\":true,\"burn_rule\":0}"

# ---- Free-play miner pool (V1 §3) -------------------------------------------
# Weights are relative, so V1's fractional percentages are expressed out of
# 10,000: artifact 55%, common 25%, uncommon 12%, rare 6%, epic 1.75%,
# legendary 0.25%. Tiers whose template is not yet minted are omitted, which
# re-weights the remainder — see the ALLOW_MISSING_TIERS warning above.
# These MUST run after the miner block: the contract rejects a selector whose
# value does not match a configured `minerconf.miner_type`, so that a rotation
# can never land on a tier no player is able to own.
[[ "$MINER_ARTIFACT" == 0 ]]  || push fpselset '{"selector_value":"artifact","weight":5500,"rotation_period_sec":3600}'
push fpselset '{"selector_value":"common","weight":2500,"rotation_period_sec":3600}'
push fpselset '{"selector_value":"uncommon","weight":1200,"rotation_period_sec":3600}'
push fpselset '{"selector_value":"rare","weight":600,"rotation_period_sec":3600}'
push fpselset '{"selector_value":"epic","weight":175,"rotation_period_sec":3600}'
[[ "$MINER_LEGENDARY" == 0 ]] || push fpselset '{"selector_value":"legendary","weight":25,"rotation_period_sec":3600}'

# ---- Smithy recipes (V1 §1) -------------------------------------------------
# Every craft is priced in Gold + FT at the V1 reference rate of
# 1 Gold = 1,000 FT. Gold currency and the Free2play land stay system-issued so
# crafting cannot bypass reward or onboarding issuance controls, and the
# Legendary miner is deliberately NOT craftable in V1 (§1).
configure_recipe() {
  local category="$1" id="$2" title="$3" schema="$4" ft_cost="$5" gold_cost="$6"
  # recdel first decrements the old rule reference count; only then can the
  # old rule be deleted and recreated. This makes SEED_RESUME deterministic.
  if row_exists craftrecipes "$category" recipe_id "$id"; then
    push recdel "{\"category\":\"$category\",\"recipe_id\":$id}"
  fi
  if row_exists craftrules "$CONTRACT" rule_id "$id"; then
    push ruledel "{\"rule_id\":$id}"
  fi
  push ruleset "{\"rule_id\":$id}"
  push ruleitemadd "{\"rule_id\":$id,\"result_type\":1,\"ft_amount\":\"$(ft 0)\",\"template_id\":$id,\"schema_name\":\"$schema\",\"weight\":100}"
  push recset "{\"category\":\"$category\",\"recipe_id\":$id,\"display_name\":\"$title\",\"start_ms\":0,\"end_ms\":0}"
  push recreqaddft "{\"category\":\"$category\",\"recipe_id\":$id,\"quantity\":\"$(ft "$ft_cost")\"}"
  push recreqaddgld "{\"category\":\"$category\",\"recipe_id\":$id,\"amount\":$gold_cost}"
  push recresadd "{\"category\":\"$category\",\"recipe_id\":$id,\"rule_id\":$id}"
}

configure_recipe miners "$MINER_COMMON"   'Mine Worker'       miners  5000 13
configure_recipe miners "$MINER_UNCOMMON" 'Prospector'        miners 18250 22
configure_recipe miners "$MINER_RARE"     'Mine Foreman'      miners 23150 30
configure_recipe miners "$MINER_EPIC"     'Master Excavator'  miners 32500 35

configure_recipe equipment "$EQUIP_COMMON"   'Stone Maul'       equipment 1800  3
configure_recipe equipment "$EQUIP_UNCOMMON" 'Iron Pickaxe'     equipment 2500  3
configure_recipe equipment "$EQUIP_RARE"     'Blasting Charge'  equipment 4500  5
[[ "$EQUIP_EPIC" == 0 ]] || \
  configure_recipe equipment "$EQUIP_EPIC"      'Steam Bore'          equipment 7000  7
[[ "$EQUIP_LEGENDARY" == 0 ]] || \
  configure_recipe equipment "$EQUIP_LEGENDARY" 'Dwarven Earthbreaker' equipment 8900 10

configure_recipe land "$LAND_EPIC"      'Deep Vein Mine' land  986  3
configure_recipe land "$LAND_LEGENDARY" 'Mother Lode'    land 3100 11
configure_recipe land "$LAND_DIAMOND"   'Grand Reserve'  land 5150 21

# Slot-unlock pricing is NOT specified by economy V1 (§13 lists slot unlocks as
# an FT sink but sets no figures). These follow the V1 land curve and the
# 1 Gold = 1,000 FT reference; confirm them before mainnet.
SLOT_2_FT="${SLOT_2_FT:-10000}"  SLOT_2_GOLD="${SLOT_2_GOLD:-5}"
SLOT_3_FT="${SLOT_3_FT:-25000}"  SLOT_3_GOLD="${SLOT_3_GOLD:-10}"
SLOT_4_FT="${SLOT_4_FT:-50000}"  SLOT_4_GOLD="${SLOT_4_GOLD:-20}"
configure_recipe essentials "$SLOT_2_TEMPLATE" 'Second Claim Permit' essentials "$SLOT_2_FT" "$SLOT_2_GOLD"
configure_recipe essentials "$SLOT_3_TEMPLATE" 'Third Claim Permit' essentials "$SLOT_3_FT" "$SLOT_3_GOLD"
configure_recipe essentials "$SLOT_4_TEMPLATE" 'Fourth Claim Permit' essentials "$SLOT_4_FT" "$SLOT_4_GOLD"

echo "Seed complete. Maintenance remains ON; fund rewardpool and verify before launch."
echo
echo "Reward-pool sizing note: the contract reserves the MAXIMUM possible reward"
echo "before each mine. Under V1 that peak is 195 FT x 2.60 equipment x 1.15 land"
echo "= 583.05 FT per concurrent mine, so fund accordingly."
for table in config ftconfig nftconfig tosconfig minerconf miningtypes equipconf landconf landdef slotconf fpselectors craftrules; do
  cleos -u "$NODE" get table "$CONTRACT" "$CONTRACT" "$table" --limit 100
done
