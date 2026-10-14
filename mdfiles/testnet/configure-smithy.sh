#!/usr/bin/env bash
set -euo pipefail

# Configure deterministic Smithy recipes on WAX testnet.
# Run after deploying the deterministic-crafting contract build.

NODE="${NODE:-https://test.wax.eosusa.io}"
CONTRACT="${CONTRACT:-warforzlands}"
AUTH="${AUTH:-warforzlands@active}"
CLEOS_TIMEOUT="${CLEOS_TIMEOUT:-45}"
SEED_DELAY="${SEED_DELAY:-1}"

# Public RPCs may throttle a long burst of signed transactions. Reads can fail
# over safely; signed writes stay on the selected NODE to avoid uncertain
# duplicate submissions when an endpoint accepts a transaction but drops its
# response.
READ_NODES=("$NODE")
if [[ "$NODE" == "https://test.wax.eosusa.io" ]]; then
  READ_NODES+=("https://testnet.waxsweden.org")
fi

push() {
  local action="$1"
  local data="$2"
  echo "==> ${action} ${data}"
  timeout --foreground "${CLEOS_TIMEOUT}s" cleos -u "$NODE" push action "$CONTRACT" "$action" "$data" -p "$AUTH" || {
    local status=$?
    if [[ $status -eq 124 ]]; then
      echo "Timed out after ${CLEOS_TIMEOUT}s at ${action}. The transaction result is uncertain; do not repeat it manually. Rerun this script so it reconciles the on-chain row first." >&2
    else
      echo "Action ${action} failed (exit ${status}). Check wallet unlock, CPU and the assertion above." >&2
    fi
    return "$status"
  }
  sleep "$SEED_DELAY"
}

row_exists() {
  local table="$1"
  local scope="$2"
  local key_name="$3"
  local key="$4"
  local endpoint output
  for endpoint in "${READ_NODES[@]}"; do
    if output="$(timeout --foreground "${CLEOS_TIMEOUT}s" cleos -u "$endpoint" get table "$CONTRACT" "$scope" "$table" --limit 1000 2>/dev/null)"; then
      printf '%s' "$output" | grep -Eq "\"${key_name}\"[[:space:]]*:[[:space:]]*\"?${key}\"?"
      return $?
    fi
  done
  echo "Could not read ${scope}:${table} from any configured RPC." >&2
  return 2
}

echo "Checking RPC and unlocked wallet before Smithy writes..."
timeout --foreground "${CLEOS_TIMEOUT}s" cleos -u "$NODE" get info >/dev/null
if ! cleos wallet list 2>/dev/null | grep -q '\*'; then
  echo "No unlocked cleos wallet. Run: cleos wallet unlock" >&2
  exit 5
fi

configure_recipe() {
  local category="$1"
  local recipe_id="$2"
  local display_name="$3"
  local schema="$4"
  local template_id="$5"
  local cost="$6"
  local rule_id="$7"

  echo "Configuring ${display_name} (${template_id}) for ${cost} WAX"

  # Make reruns deterministic: detach/delete our prior recipe, then recreate
  # its one-output rule. These IDs are reserved by this script.
  if row_exists craftrecipes "$category" recipe_id "$recipe_id"; then
    push recdel "{\"category\":\"$category\",\"recipe_id\":$recipe_id}"
  fi
  if row_exists craftrules "$CONTRACT" rule_id "$rule_id"; then
    push ruledel "{\"rule_id\":$rule_id}"
  fi

  push ruleset "{\"rule_id\":$rule_id}"
  push ruleitemadd "{\"rule_id\":$rule_id,\"result_type\":1,\"ft_amount\":\"0.00000000 WAX\",\"template_id\":$template_id,\"schema_name\":\"$schema\",\"weight\":100}"
  push recset "{\"category\":\"$category\",\"recipe_id\":$recipe_id,\"display_name\":\"$display_name\",\"start_ms\":0,\"end_ms\":0}"
  push recreqaddft "{\"category\":\"$category\",\"recipe_id\":$recipe_id,\"quantity\":\"$cost WAX\"}"
  push recresadd "{\"category\":\"$category\",\"recipe_id\":$recipe_id,\"rule_id\":$rule_id}"
}

# Recommended testnet economy defaults. Recipe and rule IDs equal the output
# template ID, avoiding collisions across categories and simplifying audits.
configure_recipe miners    664504 "Mine Worker"       miners    664504 "5.00000000"   664504
configure_recipe miners    664505 "Prospector"        miners    664505 "10.00000000"  664505
configure_recipe miners    664506 "Mine Foreman"      miners    664506 "20.00000000"  664506
configure_recipe miners    664507 "Master Excavator"  miners    664507 "40.00000000"  664507

configure_recipe equipment 664510 "Stone Maul"      equipment 664510 "3.00000000"   664510
configure_recipe equipment 664511 "Iron Pickaxe"    equipment 664511 "6.00000000"  664511
configure_recipe equipment 664512 "Blasting Charge" equipment 664512 "12.00000000"  664512

configure_recipe land      664513 "Deep Vein Mine"     land      664513 "50.00000000"  664513
configure_recipe land      664514 "Mother Lode"        land      664514 "100.00000000" 664514
configure_recipe land      664515 "Grand Reserve"      land      664515 "200.00000000" 664515

configure_recipe essentials 664517 "Second Claim Permit" essentials 664517 "25.00000000"  664517
configure_recipe essentials 664519 "Third Claim Permit" essentials 664519 "50.00000000"  664519
configure_recipe essentials 664520 "Fourth Claim Permit" essentials 664520 "100.00000000" 664520

echo
echo "Smithy configuration complete. Gold #664516 and Public Mining Claim #664521 remain system-issued."
cleos -u "$NODE" get table "$CONTRACT" "$CONTRACT" craftrules --limit 100
