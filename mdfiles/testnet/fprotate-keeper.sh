#!/usr/bin/env bash
set -uo pipefail

# Warforz Lands hourly RNG keeper (WAX testnet).
# Use only a disposable, low-value burner account because its active key is
# stored directly in this file as requested.

CONTRACT="warforzlands"
KEEPER_ACCOUNT="REPLACE_WITH_BURNER_ACCOUNT"
KEEPER_PRIVATE_KEY="REPLACE_WITH_BURNER_ACTIVE_PRIVATE_KEY"
WALLET_NAME="warforzkeeper"
WALLET_PASSWORD_FILE="${HOME}/.warforzkeeper-password"

CHAIN_ID="f16b1833c747c43682f4386fca9cbb327929334a762755ebec17f6f23c9b8a12"
ENDPOINTS=(
  "https://test.wax.eosusa.io"
  "https://testnet.waxsweden.org"
)

log() { printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"; }
fail() { log "ERROR: $*"; exit 1; }

command -v cleos >/dev/null 2>&1 || fail "cleos is not installed or not in PATH"
[[ "$KEEPER_ACCOUNT" != REPLACE_* ]] || fail "set KEEPER_ACCOUNT at the top of this file"
[[ "$KEEPER_PRIVATE_KEY" != REPLACE_* ]] || fail "set KEEPER_PRIVATE_KEY at the top of this file"

# Start the local wallet daemon when cron/systemd does not already have one.
if command -v pgrep >/dev/null 2>&1 && ! pgrep -x keosd >/dev/null 2>&1; then
  command -v keosd >/dev/null 2>&1 || fail "keosd is not installed or not in PATH"
  keosd >/tmp/warforz-keosd.log 2>&1 &
  sleep 1
fi

# Create the wallet once and retain its generated unlock password locally.
# After a reboot, keosd must open an existing named wallet before listing it.
if [[ -r "$WALLET_PASSWORD_FILE" ]]; then
  cleos wallet open --name "$WALLET_NAME" >/dev/null 2>&1 || true
fi
wallets="$(cleos wallet list 2>/dev/null || true)"
if ! grep -Fq "\"${WALLET_NAME}\"" <<<"$wallets"; then
  log "Creating local wallet ${WALLET_NAME}"
  created="$(cleos wallet create --name "$WALLET_NAME" --to-console 2>&1)" \
    || fail "wallet creation failed: ${created}"
  wallet_password="$(grep -oE 'PW[A-Za-z0-9]+' <<<"$created" | head -n 1)"
  [[ -n "$wallet_password" ]] || fail "could not read generated wallet password: ${created}"
  printf '%s\n' "$wallet_password" >"$WALLET_PASSWORD_FILE"
fi

[[ -r "$WALLET_PASSWORD_FILE" ]] || fail "missing wallet password file: ${WALLET_PASSWORD_FILE}"
wallet_password="$(tr -d '\r\n' <"$WALLET_PASSWORD_FILE")"
cleos wallet unlock --name "$WALLET_NAME" --password "$wallet_password" >/dev/null 2>&1 || true

# Import only once. The private_keys query is local to keosd.
wallet_private_keys="$(cleos wallet private_keys --name "$WALLET_NAME" --password "$wallet_password" 2>/dev/null || true)"
if ! grep -Fq "$KEEPER_PRIVATE_KEY" <<<"$wallet_private_keys"; then
  log "Importing burner account active key"
  cleos wallet import --name "$WALLET_NAME" --private-key "$KEEPER_PRIVATE_KEY" >/dev/null \
    || fail "private-key import failed"
fi

# Select the first responsive endpoint that reports the WAX testnet chain ID.
NODE=""
for candidate in "${ENDPOINTS[@]}"; do
  info="$(cleos -u "$candidate" get info 2>/dev/null || true)"
  if grep -Fq "$CHAIN_ID" <<<"$info"; then
    NODE="$candidate"
    break
  fi
done
[[ -n "$NODE" ]] || fail "no configured WAX testnet endpoint is available"
log "Using endpoint ${NODE}"

state="$(cleos -u "$NODE" get table "$CONTRACT" "$CONTRACT" freeplaystat 2>&1)" \
  || fail "could not read freeplaystat: ${state}"
log "Current state: ${state//$'\n'/ }"

# The contract rejects early calls and concurrent pending ORNG requests. This
# means cron can safely execute the script every five minutes.
output="$(cleos -u "$NODE" push action \
  "$CONTRACT" fprotate \
  "{\"caller\":\"$KEEPER_ACCOUNT\"}" \
  -p "$KEEPER_ACCOUNT@active" 2>&1)"
status=$?

if [[ $status -eq 0 ]]; then
  log "Rotation request submitted successfully"
  printf '%s\n' "$output"
  exit 0
fi

if grep -Eqi 'not due|not expired|rotation.*pending|request.*pending' <<<"$output"; then
  log "No rotation required yet"
  exit 0
fi

printf '%s\n' "$output" >&2
fail "fprotate transaction failed"
