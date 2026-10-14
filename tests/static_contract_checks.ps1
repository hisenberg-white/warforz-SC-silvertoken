# ============================================================================
#  static_contract_checks.ps1 — structural checks for the Warforz Vault token.
#
#  These are regex-level checks, NOT a compiler. They catch the mistakes that
#  are easy to make and expensive to find on-chain: an action declared but never
#  defined, a name too long for EOSIO's 12-character encoding, a mismatched
#  action_wrapper, a helper left undefined, an accidental change to the
#  eosio.token standard table layouts, and a recipient dispatch on the receipt
#  action. Run them before every build.
#
#      pwsh SC/silvertoken/tests/static_contract_checks.ps1
#
#  Mirrors SC/mininggame/tests/static_contract_checks.ps1.
# ============================================================================
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$header = Get-Content -Raw -LiteralPath (Join-Path $root 'include\warforzvault.hpp')
$source = Get-Content -Raw -LiteralPath (Join-Path $root 'src\warforzvault.cpp')
$fail = 0

# ---- 1. Every declared action is defined, and vice versa --------------------
$declared = [regex]::Matches($header, 'ACTION\s+([a-z0-9]+)\s*\(') |
  ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$defined = [regex]::Matches($source, 'ACTION\s+warforzvault::([a-z0-9]+)\s*\(') |
  ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

Write-Output "actions declared ($($declared.Count)): $($declared -join ', ')"
$diff = Compare-Object $declared $defined
if ($diff) { Write-Output "FAIL declaration/definition mismatch"; $diff | Out-String | Write-Output; $fail++ }
else { Write-Output "PASS declaration/definition parity" }

# ---- 2. EOSIO name encoding limits -----------------------------------------
# Names are packed into 64 bits from the [a-z1-5.] alphabet; this project caps
# public identifiers at 12 characters.
foreach ($a in $declared) {
  if ($a.Length -gt 12) { Write-Output "FAIL action >12 chars: $a ($($a.Length))"; $fail++ }
  if ($a -notmatch '^[a-z1-5]+$') { Write-Output "FAIL action charset: $a"; $fail++ }
}
Write-Output "PASS action name limits"

$tables = [regex]::Matches($header, 'multi_index<\s*"([a-z1-5.]+)"_n') |
  ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$idx = [regex]::Matches($header, 'indexed_by<"([a-z1-5.]+)"_n') |
  ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
Write-Output "tables: $($tables -join ', ') | indexes: $($idx -join ', ')"
foreach ($t in ($tables + $idx)) {
  if ($t.Length -gt 12) { Write-Output "FAIL name >12 chars: $t"; $fail++ }
}
Write-Output "PASS table/index name limits"

# ---- 3. action_wrapper names match the actions they wrap --------------------
$wrappers = [regex]::Matches($header, 'action_wrapper<"([a-z1-5]+)"_n,\s*&warforzvault::([a-z0-9]+)>')
foreach ($w in $wrappers) {
  if ($w.Groups[1].Value -ne $w.Groups[2].Value) {
    Write-Output "FAIL wrapper mismatch: $($w.Groups[1].Value) vs $($w.Groups[2].Value)"; $fail++
  }
}
if ($wrappers.Count -ne $declared.Count) {
  Write-Output "FAIL wrapper count $($wrappers.Count) != action count $($declared.Count)"; $fail++
}
Write-Output "PASS $($wrappers.Count) action wrappers"

# ---- 4. Every private helper is defined -------------------------------------
$helpers = @('sub_balance','add_balance','require_symbol','fee_units','is_fee_exempt',
             'any_fee_configured','has_locked_exemption','send_burn_receipt')
foreach ($h in $helpers) {
  if ($source -notmatch "warforzvault::$h\s*\(") { Write-Output "FAIL helper not defined: $h"; $fail++ }
}
Write-Output "PASS $($helpers.Count) helpers defined"

# ---- 5. eosio.token standard table layouts are untouched --------------------
# Wallets, explorers and light-API indexers deserialize these two rows by
# position. Changing a field name, type or order silently breaks all of them.
$bare = [regex]::Replace($header, '(?m)//.*$', '')
$bare = [regex]::Replace($bare, '\s+', ' ')
if ($bare -notmatch 'TABLE account \{ asset balance;') {
  Write-Output "FAIL accounts layout changed"; $fail++
}
if ($bare -notmatch 'TABLE currency_stats \{ asset supply; asset max_supply; name issuer;') {
  Write-Output "FAIL stat layout changed"; $fail++
}
Write-Output "PASS eosio.token standard table layouts intact"

# ---- 6. The receipt action must never dispatch a notification ---------------
# Finding H1 of the game contract's audit: a require_recipient on a path that
# must not fail lets the notified account's code revert the parent transaction.
if ($source -match '(?s)ACTION warforzvault::logburn.*?require_recipient') {
  Write-Output "FAIL logburn dispatches a notification"; $fail++
}
$rr = [regex]::Matches($source, 'require_recipient\((\w+)\)') | ForEach-Object { $_.Groups[1].Value }
if (($rr | Sort-Object -Unique) -join ',' -ne 'from,to') {
  Write-Output "FAIL unexpected require_recipient targets: $($rr -join ', ')"; $fail++
}
Write-Output "PASS notification dispatch limited to transfer's from/to"

# ---- 7. Fee-safety invariants are still wired ------------------------------
# These three guards are what make the fee design safe (audit H1/H2). If a
# refactor drops one, the contract still compiles and still looks correct.
if ($source -notmatch '(?s)ACTION warforzvault::setfee.*?has_locked_exemption') {
  Write-Output "FAIL setfee no longer requires a locked exemption"; $fail++
}
if ($source -notmatch '(?s)ACTION warforzvault::feeapply.*?has_locked_exemption') {
  Write-Output "FAIL feeapply no longer re-checks the locked exemption"; $fail++
}
if ($source -notmatch '(?s)ACTION warforzvault::exemptunlock.*?any_fee_configured') {
  Write-Output "FAIL exemptunlock no longer requires fees to be off"; $fail++
}
if ($source -notmatch '(?s)ACTION warforzvault::exemptdel.*?locked') {
  Write-Output "FAIL exemptdel no longer refuses locked rows"; $fail++
}
Write-Output "PASS fee-safety guards present"

if ($fail -eq 0) { Write-Output "`nALL CHECKS PASSED" }
else { Write-Output "`n$fail CHECK(S) FAILED"; exit 1 }
