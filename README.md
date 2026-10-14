# Warforz Vault — SILVER token contract

The fungible-token ("FT") contract for the Warforz Lands economy.

| | |
|---|---|
| **Contract account** | `warforzvault` |
| **Symbol** | `4,SILVER` (4 decimals, e.g. `5000.0000 SILVER`) |
| **Chain** | WAX (testnet first, then mainnet) |
| **Standard** | `eosio.token` — same actions, same `stat`/`accounts` table layout |
| **Transfer fee** | 0.50% of each transfer, **burned**, skipped for exempt accounts |
| **Fee ceiling** | 2.00% hard cap in code; increases need 72h notice |
| **Extra actions** | `burn`, `setissuer`, `setfee`, `feeapply`, `feecancel`, `exemptadd`, `exemptlock`, `exemptunlock`, `exemptdel`, `logburn` |

Precision 4 comes from the master spec (`4,SILVER`) and the frontend, which
already formats amounts as `12.3456 SILVER`. It is fixed at `create` time and
cannot be changed afterwards without a new symbol.

See [WARFORZVAULT_AUDIT.md](../../WARFORZVAULT_AUDIT.md) for the security review.

---

## Actions

| Action | Auth | What it does |
|---|---|---|
| `create(issuer, maximum_supply)` | `warforzvault` | Registers the symbol and fixes the permanent supply ceiling. Once per symbol. |
| `issue(to, quantity, memo)` | issuer | Mints into the **issuer's own** balance, up to `max_supply`. `to` must be the issuer. No fee. |
| `retire(quantity, memo)` | issuer | Destroys tokens in the issuer balance. Lowers `supply`, not `max_supply`. |
| `setissuer(token_symbol, new_issuer)` | issuer **and** `warforzvault` | Rotates minting authority. **Both** keys must sign. |
| `transfer(from, to, quantity, memo)` | `from` | Standard transfer, less the burned fee. Notifies both parties. |
| `open(owner, symbol, ram_payer)` | `ram_payer` | Pre-creates a zero balance row so the owner pays their own RAM. |
| `close(owner, symbol)` | `owner` | Deletes a zero balance row, reclaiming RAM. |
| `burn(owner, quantity, memo)` | `owner` | Any holder destroys their own tokens. |
| `setfee(token_symbol, bps)` | `warforzvault` | Sets the burned fee. `50` = 0.50%, `0` disables. Increases are announced, not instant. |
| `feeapply(token_symbol)` | `warforzvault` | Applies an announced increase after its 72h notice. |
| `feecancel(token_symbol)` | `warforzvault` | Abandons an announced increase. |
| `exemptadd(account, reason)` | `warforzvault` | Excuses an account from the fee, both directions. Starts unlocked. |
| `exemptlock(account)` | `warforzvault` | Marks an exemption load-bearing — cannot be deleted. |
| `exemptunlock(account)` | `warforzvault` | Releases a locked exemption. **Only while every fee is 0.** |
| `exemptdel(account)` | `warforzvault` | Removes an exemption. Refused while locked. |
| `logburn(from, to, fee)` | `warforzvault` | Trace-only receipt for a burned fee. No state change. |

### Why `burn` exists

Plain `eosio.token` can only `retire` from the issuer's balance. Economy V1 §13
routes FT out of circulation through healing, crafting, land/equipment crafting,
slot unlocks, repairs, rerolls and marketplace fees — none of which accumulate in
the issuer account. `burn` lets whoever actually holds the sunk tokens remove
them from supply without a round trip back to the issuer. Accounting is identical
to `retire`: `supply` falls, `max_supply` does not, so burned headroom stays
re-issuable.

---

## Transfer fee

**0.50% of every transfer is destroyed.** It is not paid to a treasury, a fee
account, or anyone else — `supply` simply falls, making the fee a permanent,
publicly verifiable deflationary sink. Every burn emits a `logburn` receipt into
the transaction trace so indexers can attribute the supply change.

### Semantics

- The **sender is debited the full `quantity`**.
- The **recipient is credited `quantity - fee`**.
- The fee is burned: `stat.supply -= fee`.
- Rounding **truncates**, so the fee rounds down in the holder's favour. At
  0.50% with 4 decimals, transfers below `0.0200 SILVER` move at par.
- The rate is stored per symbol in `feeconfig` and is **hard-capped at 2.00%**
  in code. `fee_units` clamps to that ceiling when reading, so a stored rate
  above it can never take effect.

### Fee governance

| Change | When it takes effect |
|---|---|
| Decrease (including to 0) | Immediately — always better for holders. |
| **First** activation of a symbol's fee | Immediately, **but refused unless a locked exemption already exists.** |
| Any later increase | Announced on-chain, applied by `feeapply` after **72 hours**. |

The `activated` flag makes the immediate-first-activation allowance one-shot, so
dropping the rate to 0 and raising it again cannot be used to skip the notice
period.

### ⚠ Exemptions, and why they are enforced

The transfer **notification still carries the gross `quantity`** — that is the
action's own argument and cannot be rewritten. Any contract that credits an
internal ledger from that notification will credit more than it actually
received. `warforzlands` does exactly that in two places:

| Path | Code | Effect without an exemption |
|---|---|---|
| Player deposit | [`on_token_transfer`](../mininggame/src/warforzlands.cpp#L1321) → `add_balance(from, quantity)` | Credits the player the gross amount; the contract holds 0.5% less. Deficit grows with every deposit. |
| Reward funding | [memo `rewardpool`](../mininggame/src/warforzlands.cpp#L1315) → `add_reward_pool(quantity)` | Pool believes it is 0.5% larger than the tokens backing it. |

**The contract now enforces both ordering hazards itself:**

1. `setfee` refuses a non-zero rate while **no exemption is locked**, so "fee
   switched on before exemptions were registered" is unreachable.
2. `exemptunlock` refuses while **any fee is live**, and `exemptdel` refuses on a
   locked row — so a load-bearing exemption cannot be stripped out from under a
   running fee.

**What those guards do guarantee:** no exemption can be pulled out from under a
*live* fee. Stripping one always costs a visible, deliberate "turn every fee off
first", so an integration is never exposed silently or mid-flight.

**What they do not guarantee:** that any *particular* account stays exempt. The
check only asks whether *some* lock exists — so with two locked rows an admin
can still, in four deliberate steps, zero the fee, unlock and delete one of
them, and re-enable the fee with that integration now exposed.

**What is not enforceable at all:** the contract cannot know *which* accounts
need exemption. Every new ledger-keeping integration — marketplace, bridge,
staking, exchange deposit processor — must still be exempted by hand. This is
inherent to fee-on-transfer and is the residual risk of the design.

A transfer is fee-free if **either** party is exempt, so one row covers both
directions:

| Account | Why | Lock it? |
|---|---|---|
| `warforzlands` | Credits ledgers from notifications; covers deposits *and* withdrawals. | **Yes** |
| `warforzfees1` | Funds the reward pool; also receives withdrawal fees. | **Yes** |
| `warforzvault` | Treasury and liquidity movements should not self-burn. | Optional |

### Front-end note

Quote the **net** amount, not the gross. The `get_net_transfer` helper in the
header does the calculation on-chain; off-chain, read `feeconfig` and
`feeexempt` and apply the same truncating math. A UI that shows the gross will
be wrong by 0.5% on every wallet-to-wallet send.

---

## How this pairs with the game contract

`warforzvault` knows nothing about the game, and it must stay that way — the game
contract reads its currency identity from config, never from hardcoded symbols.
The wiring is entirely on the `warforzlands` side:

- **Config** — `warforzlands::ftconfigset` is told this account and the `4,SILVER`
  symbol. The symbol is **immutable after first configuration**
  ([warforzlands.cpp:392](../mininggame/src/warforzlands.cpp#L392)), so get it
  right the first time on each network.
- **Deposits** — a player calls `transfer(player, warforzlands, q, memo)` here.
  `transfer` runs `require_recipient` on both parties, which fires
  `warforzlands::on_token_transfer` and credits the in-game balance in the same
  transaction.
- **Reward pool** — a `transfer` from the configured **fee account** with memo
  `rewardpool` funds mining rewards. From any other sender that memo is rejected.
- **Withdrawals** — `warforzlands::wdrawft` sends an inline `transfer` back out,
  splitting a fee to the fee account.

> **Do not fund the reward pool straight from `warforzvault`.**
> `warforzlands::on_token_transfer` treats any memo other than `rewardpool` as a
> player deposit and calls `check_tos_accepted(from)`, and the `rewardpool` memo
> is only accepted from the configured fee account. A transfer direct from the
> issuer reverts. Route funding through `warforzfees1`, as step 8 does.

### RAM note

On withdrawal the sender is `warforzlands`, so if the player has no SILVER
balance row yet, **`warforzlands` pays the RAM for it** (standard `eosio.token`
payer rule: `has_auth(to) ? to : from`). Two ways to avoid that cost drifting
upward with the player count:

1. Have the frontend call `open(player, "4,SILVER", player)` at registration, or
2. Accept it and keep the game account's RAM funded.

Option 1 is cheaper for the project and is what `open` is for.

---

## Build

Same toolchain and workflow as the game contract — see
[WARFORZLANDS_BUILD_DEPLOY.md](../../WARFORZLANDS_BUILD_DEPLOY.md) for
installing `cleos` / `cdt-cpp`. All tooling lives inside WSL Ubuntu, not Windows.

Run the structural checks first — they are regex-level, not a compiler, but they
catch the mistakes that are expensive to find on-chain:

```powershell
pwsh SC/silvertoken/tests/static_contract_checks.ps1
```

### Verified build command (Docker, CDT 4.1.1)

This is the command that actually produced the current artifacts, using the
`warforz-cdt:4.1.1` image already on this machine (built from
`SC/mininggame/tests/Dockerfile.cdt`):

```powershell
$p = 'd:\Projects\pratice\wax chain\SC\silvertoken'
New-Item -ItemType Directory -Force "$p\build" | Out-Null
docker run --rm -v "${p}:/project" warforz-cdt:4.1.1 `
  -abigen -contract warforzvault -I include -I . -R . `
  -o build/warforzvault.wasm src/warforzvault.cpp
```

Or from WSL with a native CDT install:

```bash
wsl -d Ubuntu
cd "/mnt/d/Projects/pratice/wax chain/SC/silvertoken"
mkdir -p build

cdt-cpp -abigen \
        -contract warforzvault \
        -I include -I . \
        -R . \
        -o build/warforzvault.wasm \
        src/warforzvault.cpp
```

**Two flags matter and are easy to get wrong:**

- **`-I .` is required in addition to `-I include`.** CDT's second (codegen)
  pass copies the source to `/tmp` and rewrites the include as
  `include/warforzvault.hpp`, which then cannot be resolved from `/tmp` unless
  the project root is also on the include path. Without it the build fails with
  `fatal error: 'include/warforzvault.hpp' file not found` *after* the ABI pass
  has already succeeded — which makes it look like a source error when it is not.
- **`-R .` picks up the Ricardian files**, but only if their headings use the
  HTML form CDT parses:

  ```html
  <h1 class="contract">transfer</h1>     <!-- in warforzvault.contracts.md -->
  <h1 class="clause">transfer_fee</h1>   <!-- in warforzvault.clauses.md   -->
  ```

  Markdown `## transfer` headings are silently ignored: the build still
  succeeds, every action logs `does not have a ricardian contract`, and the ABI
  ships with `"ricardian_contract": ""` everywhere. For this token that would
  mean the burned-fee disclosure never reaches the user's wallet, so treat those
  warnings as errors.

  > `SC/mininggame/warforzlands.contracts.md` still uses the markdown form, and
  > the deployed `warforzlands.abi` has empty `ricardian_contract` on every
  > action as a result. Worth fixing there too.

Expected result: `build/warforzvault.wasm` (~35 KB) and `build/warforzvault.abi`
(~15 KB), with **0 ricardian warnings** and 16 of 16 actions carrying Ricardian
text. Verify before deploying:

```powershell
$abi = Get-Content -Raw build\warforzvault.abi | ConvertFrom-Json
"$(($abi.actions | Where-Object { $_.ricardian_contract -ne '' }).Count) of $($abi.actions.Count) actions have ricardian text"
```

CMake works too (`mkdir build && cd build && cmake .. && make`), but the direct
`cdt-cpp` invocation above is what has actually been verified.

---

## Deploy

```bash
cleos wallet unlock

# See what you're about to change
sha256sum build/warforzvault.wasm
cleos -u https://test.wax.eosusa.io get code warforzvault

cleos -u https://test.wax.eosusa.io set contract warforzvault \
      "$(pwd)/build" warforzvault.wasm warforzvault.abi \
      -p warforzvault@active

# Verify the on-chain hash now matches the sha256sum above
cleos -u https://test.wax.eosusa.io get code warforzvault
```

### Required: grant the contract `eosio.code`

`transfer` sends an inline `logburn` receipt whenever a fee is charged. Without
the `eosio.code` permission every **fee-bearing** transfer reverts:

```bash
cleos -u https://test.wax.eosusa.io set account permission warforzvault active \
      --add-code -p warforzvault@active
```

Fee-free transfers are unaffected, so a missing `eosio.code` fails loudly on the
first taxed transfer rather than silently. Step 11 below is the check.

Mainnet is the same with `-u https://wax.greymass.com`.

---

## First-run setup

**Run in order.** Steps 3–5 are ordered deliberately; the contract will reject
step 6 if step 5 has not happened.

### 1. Create the symbol — two permanent decisions

Neither `max_supply` nor the initial `issuer` choice can be undone by any action
(`setissuer` can rotate the issuer later, but only with both keys).

```bash
cleos -u https://test.wax.eosusa.io push action warforzvault create \
      '["warforzvault", "1000000000.0000 SILVER"]' -p warforzvault@active
```

> `1000000000.0000 SILVER` (1 billion) is a **placeholder** — the economy doc
> fixes per-mine rewards and craft costs but never states a total supply.
> Decide this before mainnet. For mainnet, prefer a dedicated multisig issuer
> account over `warforzvault` itself, so minting authority and code-upgrade
> authority are different keys.

### 2. Issue the initial float

```bash
cleos -u https://test.wax.eosusa.io push action warforzvault issue \
      '["warforzvault", "10000000.0000 SILVER", "initial issuance"]' \
      -p warforzvault@active
```

### 3. Register the exemptions

```bash
cleos -u https://test.wax.eosusa.io push action warforzvault exemptadd \
      '["warforzlands", "game contract: credits player ledger from transfer notifications"]' \
      -p warforzvault@active

cleos -u https://test.wax.eosusa.io push action warforzvault exemptadd \
      '["warforzfees1", "fee account: funds reward pool, receives withdrawal fees"]' \
      -p warforzvault@active

cleos -u https://test.wax.eosusa.io push action warforzvault exemptadd \
      '["warforzvault", "issuer treasury"]' \
      -p warforzvault@active
```

### 4. Lock the load-bearing ones

```bash
cleos -u https://test.wax.eosusa.io push action warforzvault exemptlock \
      '["warforzlands"]' -p warforzvault@active
cleos -u https://test.wax.eosusa.io push action warforzvault exemptlock \
      '["warforzfees1"]' -p warforzvault@active
```

### 5. Confirm before enabling the fee

```bash
cleos -u https://test.wax.eosusa.io get table warforzvault warforzvault feeexempt
# expect three rows; warforzlands and warforzfees1 with "locked": 1
```

### 6. Turn on the 0.50% burned fee

```bash
cleos -u https://test.wax.eosusa.io push action warforzvault setfee \
      '["4,SILVER", 50]' -p warforzvault@active
```

`50` basis points = 0.50%. This is the symbol's one-shot immediate activation;
it will be **rejected** if step 4 was skipped. Any later increase is announced
and needs `feeapply` after 72 hours. Decreases (including back to `0`) are
always immediate.

### 7. Point the game at the token

```bash
cleos -u https://test.wax.eosusa.io push action warforzlands ftconfigset \
      '["warforzvault", "4,SILVER", "Silver", "warforzfees1", 5, 2]' \
      -p warforzlands@active
```

Arguments are `token_contract, token_symbol, display_name, fee_account,
withdraw_fee_pct, referral_withdraw_pct`. The existing seeder passes these via
`FT_CONTRACT` / `FT_SYMBOL` / `FT_DISPLAY_NAME`:

```bash
FT_CONTRACT=warforzvault FT_SYMBOL=4,SILVER FT_DISPLAY_NAME=Silver \
  ./scripts/seed-config.sh testnet
```

This replaces the disposable `eosio.token` `8,WAX` stand-in that testnet has been
using.

### 8. Fund the reward pool

Send from the **configured fee account** with the exact memo `rewardpool`.

```bash
# issuer -> fee account (both exempt, so nothing is burned)
cleos -u https://test.wax.eosusa.io push action warforzvault transfer \
      '["warforzvault", "warforzfees1", "500000.0000 SILVER", "pool funding"]' \
      -p warforzvault@active

# fee account -> game contract
cleos -u https://test.wax.eosusa.io push action warforzvault transfer \
      '["warforzfees1", "warforzlands", "500000.0000 SILVER", "rewardpool"]' \
      -p warforzfees1@active
```

### 9. Update the frontend

Set `VITE_SILVER_TOKEN_CONTRACT=warforzvault` and `VITE_SILVER_SYMBOL=4,SILVER`.
These are startup fallbacks only — live values are read from `ftconfig` — but a
stale fallback shows wrong numbers before the first config fetch resolves.
Also update any send/transfer UI to quote the **net** amount.

### 10. Verify the deposit path — proves the exemption is live

```bash
cleos -u https://test.wax.eosusa.io push action warforzvault transfer \
      '["<player>", "warforzlands", "100.0000 SILVER", ""]' -p <player>@active

cleos -u https://test.wax.eosusa.io get table warforzlands <player> accounts --limit 1
# balances must show exactly 100.0000 SILVER, and stat.supply must be unchanged
```

### 11. Verify the fee path — proves `eosio.code` is granted

```bash
# 1000.0000 SILVER between two ordinary wallets -> 995.0000 received, 5.0000 burned
cleos -u https://test.wax.eosusa.io push action warforzvault transfer \
      '["<walletA>", "<walletB>", "1000.0000 SILVER", "fee test"]' -p <walletA>@active

cleos -u https://test.wax.eosusa.io get currency balance warforzvault <walletB> SILVER
cleos -u https://test.wax.eosusa.io get table warforzvault SILVER stat
```

The transaction trace should contain a `logburn` action showing `5.0000 SILVER`.
If the transfer fails with a permission error, `eosio.code` was not granted.

---

## Ongoing state inspection

```bash
cleos -u https://test.wax.eosusa.io get table warforzvault SILVER       stat
cleos -u https://test.wax.eosusa.io get table warforzvault warforzvault feeconfig
cleos -u https://test.wax.eosusa.io get table warforzvault warforzvault feeexempt
cleos -u https://test.wax.eosusa.io get table warforzlands warforzlands ftconfig --limit 1
```

`feeconfig` shows `transfer_fee_bps` (live), plus `pending_fee_bps` /
`pending_at` when an increase has been announced but not yet applied.

---

## Before mainnet

Code hardening cannot fix key custody. From the audit's H3, still outstanding:

- Split the issuer from the contract account at `create` time.
- Put both behind `eosio.msig` multisig permissions.
- Once the code is final, resign the contract account to `eosio.prods` or a
  locked multisig so the code becomes effectively immutable — and say so
  publicly. Until then, whoever holds `warforzvault@active` can replace this
  code with anything.
