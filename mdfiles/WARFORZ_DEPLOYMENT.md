# Warforz Lands — Deployment Runbook (all contracts)

One document to build, deploy and configure **every** contract in this project.

Last verified against testnet: **2026-08-17**

| | |
|---|---|
| Contracts | `warforzlands` (game), `warforzvault` (SILVER token) |
| Testnet endpoint | `https://test.wax.eosusa.io` |
| Mainnet endpoint | `https://wax.greymass.com` |
| Toolchain | `cleos` v5.0.3 (WSL Ubuntu), CDT 4.1.1 (Docker) |

For **installing** `cleos` / CDT from scratch, see
[WARFORZLANDS_BUILD_DEPLOY.md](WARFORZLANDS_BUILD_DEPLOY.md) §2. This runbook
assumes they are already installed and focuses on the deploy sequence itself.

Security reviews: [WARFORZLANDS_AUDIT.md](WARFORZLANDS_AUDIT.md) ·
[WARFORZVAULT_AUDIT.md](WARFORZVAULT_AUDIT.md)

---

## 1. Contract inventory

| Contract | Source | Deploy account | Build output | Needs `eosio.code` |
|---|---|---|---|---|
| **warforzlands** | [SC/mininggame/](SC/mininggame/) | `warforzlands` | `build/warforzlands.wasm` + `.abi` | **Yes** (inline receipts, AtomicAssets, ORNG) |
| **warforzvault** | [SC/silvertoken/](SC/silvertoken/) | `warforzvault` | `build/warforzvault.wasm` + `.abi` | **Yes** (inline `logburn` on fee-bearing transfers) |

### Current testnet state

| Contract | On-chain code hash | Local build hash (CDT 4.1.1) | WASM | ABI |
|---|---|---|---|---|
| `warforzlands` | `711080805b870bdae6534ef4da4522e921ac6d991252e2ec6fd48121b55249d8` | `711080805b870bdae6534ef4da4522e921ac6d991252e2ec6fd48121b55249d8` | ✅ deployed — security remediation, ORNG fix, cooldown rework, notify dispatch, **withdraw health gate** | ✅ 69 actions, 69/69 ricardian |
| `warforzvault` | `12362a1abd88acfd8b8164ec39b714454ca9be54581a0965cb2bba871e3793e0` | `12362a1abd88acfd8b8164ec39b714454ca9be54581a0965cb2bba871e3793e0` | ✅ deployed 2026-08-17 | ✅ 16 actions, 16/16 ricardian |

> **`warforzvault` code is live on testnet as of 2026-08-17** — on-chain hash
> matches the local build, and `warforzvault@eosio.code` is granted on `active`.

### ⚠ The symbol is `4,WFSLV`, not `4,SILVER`

Created on testnet 2026-08-17 (tx `5d828c80…c0a3`):

| | |
|---|---|
| Symbol | `4,WFSLV` — ticker styled **`$WFSLV`** in UI only; `$` is not a legal symbol character |
| Display name | "Warforzland Silver" — lives in `ftconfigset` / frontend, **not** in the token contract |
| `max_supply` | `1000000000.0000 WFSLV` — **permanent**, written only at [warforzvault.cpp:151](SC/silvertoken/src/warforzvault.cpp#L151) |
| `supply` | `0.0000 WFSLV` — nothing issued yet |
| `issuer` | `warforzvault` (see audit H3: split this before mainnet) |

**Every `4,SILVER` and `SILVER` literal elsewhere in this repo is now stale**,
including `SC/silvertoken/README.md`, `WARFORZVAULT_AUDIT.md`,
`WARFORZ_SYSTEM_AUDIT.md`, `Frontend/.env.example` and the `SILVER_*` constant
names in `Frontend/src/lib/chain/config.ts`. No contract code hardcodes the
symbol, so no rebuild is required — but substitute `WFSLV` when following any
command below.

### Testnet setup completed 2026-08-17

| Step | tx | State |
|---|---|---|
| `setcode` / `setabi` | `3e4699fc…caf1` | hash matches local build |
| `--add-code` | `5bc7ba02…b311` | `warforzvault@eosio.code` on `active` |
| `create` | `5d828c80…c0a3` | `4,WFSLV`, ceiling 1B |
| `issue` | `8979a0a5…f5ff` | 10,000,000 float to issuer |
| `exemptadd` ×2 | `7ec95431…45fd`, `29a7d0cc…1c4b` | `warforzlands`, `warforzfees1` |
| `exemptlock` ×2 | `de1262f5…f6b1`, `a50f9ce0…6b13` | both `locked: 1` |
| `setfee` | — | **row exists at 0 bps, `activated: 0`** |

**The fee is deliberately OFF.** `setfee 0` creates the policy row without
consuming the one-shot immediate-activation allowance ([warforzvault.cpp:350](SC/silvertoken/src/warforzvault.cpp#L350)
sets `activated = bps > 0`), so enabling 50 bps later is still a single
immediate command. Both locked exemptions are already in place, so the
ordering guard is satisfied whenever you want it.

### Action sweep: 38 of 41 assertions passed

Every action exercised except the **success** paths of `feeapply` and
`feecancel`, which are unreachable while the fee is 0: both require
`pending_at != 0`, and a pending change is only written on the non-immediate
path, which requires `activated == true`. Their rejection paths were verified.
The inline `logburn` path likewise needs a live fee; `logburn` was verified by
direct push instead, so **`eosio.code` remains the one untested link.**

Supply moved `10,000,000 → 9,999,400` via a 100 `burn` + 500 `retire`, with
`max_supply` unchanged — burned headroom stays re-issuable, as designed.

### ✅ Game integration live — `ftconfig` now points at WFSLV (2026-08-17)

§7.3's factory reset was carried out. `ftconfig` is now:

```
contract: warforzvault   token_symbol: 4,WFSLV   display_name: Warforzland Silver
fee_account: warforzfees1   withdraw_fee_pct: 5   referral_withdraw_pct: 2
```

Sequence: `maintset true` → `resetuser testingwarfo` (returned 3 custodied NFTs,
refunded 100 WAX) → `wipeall` (`79db4ca3…4af9`) → re-seed → `maintset false`.

**The re-seed needed `ALLOW_MISSING_TIERS=YES`.** Four economy tiers have never
been minted on testnet — `MINER_ARTIFACT`, `MINER_LEGENDARY`, `EQUIP_EPIC`,
`EQUIP_LEGENDARY` — and the seeder refuses without the flag. This is why testnet
carries 4 miners and 3 equipment rather than the 5+5 of Economy V1. Every table
was restored to its exact pre-wipe row count.

#### End-to-end verification (closes M6's deposit round-trip)

| Leg | Result |
|---|---|
| `tosaccept` re-register | ✅ |
| Deposit 200 WFSLV | ✅ in-game credited **exactly** `200.0000` — exemption works, no gross/net drift |
| `wdrawft` 100 WFSLV | ✅ `5.0000` → `warforzfees1`, `95.0000` → player |
| Custody backing | ✅ `warforzlands` holds `100.0000`, player's in-game balance is `100.0000` — 1:1 |
| Supply | ✅ unchanged at `9,999,400` throughout (fee is 0) |

Frontend `.env` / `.env.example` updated to `warforzvault` / `4,WFSLV`.

> `fee_account` stays `warforzfees1` rather than `warforzvault`. Either works —
> only `token_symbol` is immutable — but pointing it at the issuer would
> concentrate token contract, issuer, treasury, fee sink and upgrade authority in
> one account, against H3, and would mix earned fees with unissued treasury.

### 🔴→✅ Free-heal exploit closed: withdraw now requires full health (`71108080…49d8`)

`wdrawminer` had no health check, and `mineradd` re-creates a returning miner at
`health_max` ([:1922](SC/mininggame/src/warforzlands.cpp#L1922)). **Withdrawing a
damaged miner and re-depositing it was therefore a free full heal**, bypassing
the heal sink completely — 1,000 FT dodged per reset on a common miner
(200 HP × 5 FT, economy V1 §4). The FT sink the economy depends on was optional.

Now: a miner in the `miners` table must be at `health_max` to be withdrawn.
Miners still sitting in `deposits` are exempt — they have never mined, so they
have no health state.

**Cooldown is deliberately not a gate.** A cooldown limits *mining*, not taking
your own NFT home; the row carrying it is erased on withdrawal, and `mineradd`
restarts a returning miner at `current_time_point()`, so nothing is escaped by
leaving. Confirmed on chain below.

If a miner's template config is missing, "full" cannot be evaluated and the
withdrawal is allowed — an admin config change must never strand a player's NFT.

#### Verified on testnet

| Step | Result |
|---|---|
| Withdraw miner at 190/200 (also on cooldown) | ❌ *"miner must be at full health to withdraw — heal it first"* |
| `heal` 10 HP | balance `2223.5650 → 2173.5650` — exactly 50 WFSLV at 5 FT/HP |
| Withdraw at 200/200, **still on cooldown for 51 min** | ✅ succeeded — NFT returned to wallet, row erased |

Frontend: the Unstake button now reads "Heal to unstake" and is disabled below
full health, so the rule surfaces before a signature rather than as a failed
transaction. Cooldown still does not disable it.

### ✅ 2026-08-17: `notify` now reaches the player (`1ccddbc5…e4e1`)

Receipts were landing in the **contract's** history only — `notify` carried
`warforzlands`' authorization and no `require_recipient`, so a player's wallet
never saw them.

`notify` gained a `dispatch` flag: `notify(owner, info[], dispatch)`. When true
it calls `require_recipient(owner)`, which is what puts the receipt in the
player's own history.

**It is a flag, not always-on, for a real reason.** `require_recipient` executes
the recipient's contract code, if any, inside the parent transaction:

| Path | Parent signed by | dispatch | Why |
|---|---|---|---|
| `mine`, `heal`, `craft`, withdrawals, staking, deposits… (22 sites) | the player | **true** | a rejecting recipient can only break the player's own call |
| `resolve_mine`, `resolve_craft` | **orng.wax** | false | would let untrusted code abort an oracle settlement |
| `resetuser` | **admin** | false | a player could block their own reset, and so block `wipeall` |

Helpers: `send_notify` (dispatch) and `send_notify_trace` (trace-only).

**Verified:** exactly 5 `notify` actions are indexed against `testingwarfo`, all
after the deploy; none before it. The mine payout still arrives via contract
history, which is why `getActivity` keeps both sources — it dedupes on
`global_sequence`.

### ✅ 2026-08-17: land + equipment cooldown rework (`e3de0c8a…8fc6`)

Two gameplay rules were wrong; both traced to reusing the **miner's**
`cooldown_sec` for things that are not the miner.

| | Before | After |
|---|---|---|
| **Land** rest between mines | miner's cooldown (3600s) — one mine per land per hour, no matter how many miners you owned | per-template, **default 300s (5 min)** |
| **Equipment** | cooldown = miner's 3600s, **enforced** — gear unusable for an hour | **no cooldown**; limited only by uses, burns at 0 |
| Miner cooldown | 3600s | 3600s (unchanged, by design) |
| Gear burn at 0 uses | already correct | unchanged |
| Gear detaches each mine | yes | yes (kept, so gear can move between miners) |

Equipment's cooldown made its durability nearly unreachable — 125 uses at one
per hour is over five days of continuous play — so the stated item lifetime
never actually governed anything.

#### Migration note: why a new table, not a new `landconf` field

The cooldown lives in its own `landcdconf` table rather than as a field on
`landconf`. Appending a field to a live TABLE struct makes every existing row
fail to deserialize, and the usual fix — delete and re-create — is **impossible**
for a template referenced by NFTs in custody: `landdel` refuses with
*"template is referenced by NFTs currently in game custody"*. Land that players
are standing on could therefore never be migrated. A separate table sidesteps
it: a missing row simply falls back to `DEFAULT_LAND_COOLDOWN_SEC`. Verified —
all four `landconf` rows still read correctly after the deploy.

New actions: `landcdset(template_id, cooldown_sec)` (capped at 24h; 0 disables
the wait entirely) and `landcddel(template_id)`. Seeded by
`scripts/seed-config.sh` via `LAND_COOLDOWN_SEC` (default 300).

#### Verified on testnet

Mine resolved 16:16:41 UTC — land free again at 16:**21**:41 (+5 min), gear
available 16:16:41 with durability 125→124, miner 17:16:41 (+1h).

### ✅ FIXED 2026-08-17: mining was broken — ORNG changed its callback protocol

**Resolved.** Handler added, built, deployed as `da72e8be…4ebb`
(tx `ac60b545…0d61`), and verified end to end — see "Fix verified" below.
The history is kept because the failure mode is invisible to code review.

Discovered 2026-08-17 by running a real mine on testnet (`6ce48f1f…3c12`).

Everything up to the oracle worked: land activated in slot 1, miner placed,
and `reserve_reward` deducted **exactly** `60.5000 WFSLV` (base 55 × land bonus
1.10). The inline `orng.wax::requestrand` was sent correctly and **the oracle
answered in 3 seconds**. The callback then went nowhere.

**The live `orng.wax` delivers randomness as a notification:**

```
orng.wax::randnotify(uint64_t request_id, name dapp, uint64_t assoc_id, checksum256 rnd)
```

**`warforzlands` implements only the legacy direct callback:**

```
receiverand(uint64_t assoc_id, checksum256 random_value)     // never invoked
```

There is no `[[eosio::on_notify("orng.wax::randnotify")]]` handler in the
contract — its only notify handlers are `atomicassets::transfer` and
`*::transfer`. So **every** randomness-dependent path hangs forever: `mine`,
non-deterministic `craft`, and the `fpstart` / `fprotate` free-play rotation.

`orng.wax` keeps a legacy allowlist (`addlegacy`, `updatelegacy`, `verifyhash`,
`skiplegacy`) for dapps still on `receiverand`. `warforzlands` is not on it,
which is why it got `randnotify` instead.

#### Made worse: the deployed ABI has no recovery path

`minecancel`, `craftcancel` and `assocdel` exist in source but are **not in the
deployed 64-action ABI** — they are part of the pending 64 → 67 redeploy. So
right now:

| Stuck | Effect |
|---|---|
| miner `1099603752639` | locked on plot 1, unrecoverable on-chain |
| `60.5000 WFSLV` | reservation stranded out of the pool |
| orphan `rngassocs` row (`assoc_id: 1`) | **blocks `wipeall` permanently** — no further factory reset is possible until the redeploy |

#### The fix, as shipped

`warforzlands.hpp` / `warforzlands.cpp`:

- Added `[[eosio::on_notify("orng.wax::randnotify")]] on_randnotify(...)`, which
  checks `dapp == get_self()`, re-asserts `orng.wax` authority, and routes into
  the resolvers.
- Extracted the dispatch shared by both callbacks into `dispatch_random(assoc_id,
  rv, tolerant)`. `receiverand` passes `tolerant=false` and still asserts on an
  unknown id; the notification passes `tolerant=true` and returns quietly,
  because asserting there would abort **`orng.wax`'s own transaction** and turn
  our stale row into a failed delivery for the oracle.
- `receiverand` is retained, so the contract works under either protocol if the
  account is ever added to ORNG's legacy allowlist.

Safe inside a notification handler because every resolver bills new RAM to
`get_self()` (never to a player), which nodeos permits; all other writes use
`same_payer` or shrink the table.

#### Fix verified on testnet

| Check | Result |
|---|---|
| Deploy | `da72e8be…4ebb`, 67 actions, 67/67 Ricardian |
| Singletons survived ABI swap | `ftconfig`, `rewardpool`, `config`, player rows all intact |
| `tosdel` guard (remediation) | rejected: *"cannot delete the current Terms of Service version"* |
| `minecancel` staleness gate | rejected: *"request is not stale yet"* |
| `fpstart` → `randnotify` | **resolved**; `freeplaystat` written, selector `rare`, `rotation_assoc_id` cleared |
| Full mine (epic, plot 2) | **resolved**; pool −170.5, player +170.5 — exactly 155 × 1.10 |
| Side effects | miner health 200→175, cooldown +1h, land durability 75→74 |

> **The pre-fix stuck mine (`assoc_id: 1`) is still pending** and cannot
> self-heal: its `randnotify` was delivered before the handler existed and the
> oracle does not re-deliver. Clear it with
> `minecancel '["testingwarfo",1]'` once an hour has passed since
> `2026-08-17T14:56:46` — that also releases its 60.5 WFSLV reservation and
> unblocks `wipeall`.

### ⚠ H3 confirmed empirically: `setissuer` dual-auth is vacuous right now

`setissuer` calls `require_auth` on both the contract and the issuer, but
`issuer == warforzvault` today, so **both resolve to the same key** and a single
signature rotates minting authority to any account. Verified on testnet:

| Signers | issuer == contract | issuer separate |
|---|---|---|
| contract only | ✅ rotation succeeds | ❌ `missing authority of <issuer>` |
| issuer only | — | ❌ `missing authority of warforzvault` |
| both | ✅ | ✅ |

The code is correct; the *configuration* defeats it. The guard only becomes
real once the issuer is a distinct account, which is exactly what audit H3
asks for. **Split the issuer at `create` time on mainnet** — after `create`
the only way to split is `setissuer`, which at that point is protected by a
single key.

> `WARFORZLANDS_AUDIT.md` still cites `aac0469b…c4a4` as the audited build. That
> was the 2026-08-13 deployment; the live code was replaced on 2026-08-16 with
> `c6f6541f…bcf4`. The audit predates the current binary.

---

## 2. Account and key inventory

**Public keys only.** Private keys for these testnet accounts live in
[testnet/testnet.txt](testnet/testnet.txt) as JSON blocks keyed by `"account"`.

| Account | Role | `active` public key | `owner` public key |
|---|---|---|---|
| `warforzlands` | Game contract | `EOS8Dp26CaNdJTEWDpqsM3fcPvYpGSNnvsYTrgtoXs6brWtMpCegq` | `EOS7i1oLYBvh4aMbPAEpr7K6a9iMiLfxbvZ2QP2w1S9L3VkL8bxTp` |
| `warforzfees1` | Fee / reward-pool funder | *(same as above)* | *(same as above)* |
| `warforzvault` | SILVER token | `EOS7E9JSmXa7BaK8KKo8RpfuoMrfxPTuHeDPv9HWabzebWhj8kdqM` | `EOS5uRu2DxNast9fV11REzGRJgbF85xbqujBaGqpCWDMVv7AVd5Pu` |
| `testingwarfo` | Test player | `EOS8jDeFFtVGvZzDKnHcjV8HDhSW24V7ufZdMXJP9k31EcYEKKfYK` | `EOS4yovinACuY7grD6kfRLGVBxajwr5Dak1UApAfiJb18AULafAMW` |

**Three distinct keypairs, not one.** `warforzlands` and `warforzfees1` share a
key; `warforzvault` and `testingwarfo` each have their own. Having the wallet
unlocked is *not* the same as having the right key in it — this is the single
most common cause of a failed deploy here.

### Which keys does each task need?

| Task | Required key |
|---|---|
| Deploy / configure `warforzlands` | `warforzlands@active` → `EOS8Dp26…Cegq` |
| Fund reward pool | `warforzfees1@active` → `EOS8Dp26…Cegq` |
| Deploy / configure `warforzvault` | `warforzvault@active` → `EOS7E9JS…kdqM` |
| Player-side testing | `testingwarfo@active` → `EOS8jDeF…KKfYK` |

### ⚠ Key hygiene

`testnet/testnet.txt` holds plaintext private keys **and** the `cleos` wallet
password. Acceptable for disposable testnet accounts; never for mainnet.

- The project root is not a git repo, but `SC/mininggame/` **is**, with an
  `origin` remote. Keep key material out of anything that could get tracked.
- For mainnet: hardware wallet or `eosio.msig`, issuer split from the contract
  account, and the contract account resigned once code is final. See
  `WARFORZVAULT_AUDIT.md` finding **H3**.

---

## 3. Wallet setup

Do this **first**, every session. Most "deploy failed" reports are this.

```bash
# You are on Windows; all tooling lives inside WSL Ubuntu.
wsl -d Ubuntu
# (if you are ALREADY in the Ubuntu shell, skip that — running `wsl` inside
#  WSL prints "Command 'wsl' not found", which is harmless but confusing)

cleos wallet unlock          # password is in testnet/testnet.txt
cleos wallet keys            # list what you actually hold
```

Compare the output against §2. If a key you need is missing:

```bash
cleos wallet import
# paste the matching "private" value from the right block of testnet/testnet.txt
```

Use the **interactive** form with no arguments. `cleos wallet import
--private-key <key>` writes the key into your shell history.

For a full session covering both contracts you want all three keys loaded:

```
EOS8Dp26CaNdJTEWDpqsM3fcPvYpGSNnvsYTrgtoXs6brWtMpCegq   warforzlands + warforzfees1
EOS7E9JSmXa7BaK8KKo8RpfuoMrfxPTuHeDPv9HWabzebWhj8kdqM   warforzvault
EOS8jDeFFtVGvZzDKnHcjV8HDhSW24V7ufZdMXJP9k31EcYEKKfYK   testingwarfo
```

---

## 4. Running these commands

**Run one step at a time, or set `set -e` first.** `bash` does not stop on
error, so pasting a whole block means one failure cascades into a wall of
misleading follow-on errors (`No ABI found`, `Table … is not specified in the
ABI`) that all trace back to a single earlier problem.

```bash
set -e     # abort the batch at the first failure
NODE=https://test.wax.eosusa.io
```

Every command below uses `$NODE`. For mainnet, set
`NODE=https://wax.greymass.com` and re-read §8 first.

---

## 5. Build

Both contracts build with the same Docker CDT image
(`warforz-cdt:4.1.1`, built from `SC/mininggame/tests/Dockerfile.cdt`).
Run these from **PowerShell**, not WSL — Docker Desktop must be running.

### 5.1 warforzvault (SILVER token)

```powershell
pwsh "d:\Projects\pratice\wax chain\SC\silvertoken\tests\static_contract_checks.ps1"

$p = 'd:\Projects\pratice\wax chain\SC\silvertoken'
New-Item -ItemType Directory -Force "$p\build" | Out-Null
docker run --rm -v "${p}:/project" warforz-cdt:4.1.1 `
  -abigen -contract warforzvault -I include -I . -R . `
  -o build/warforzvault.wasm src/warforzvault.cpp
```

### 5.2 warforzlands (game)

```powershell
pwsh "d:\Projects\pratice\wax chain\SC\mininggame\tests\static_contract_checks.ps1"

$p = 'd:\Projects\pratice\wax chain\SC\mininggame'
New-Item -ItemType Directory -Force "$p\build" | Out-Null
docker run --rm -v "${p}:/project" warforz-cdt:4.1.1 `
  -abigen -contract warforzlands -I include -I . -R . `
  -o build/warforzlands.wasm src/warforzlands.cpp
```

### 5.3 Two build flags that are easy to get wrong

**`-I .` is required in addition to `-I include`.** CDT's codegen pass copies the
source to `/tmp` and rewrites the include as `include/<name>.hpp`, which cannot
resolve from `/tmp` unless the project root is also on the include path. Without
it you get `fatal error: 'include/warforzvault.hpp' file not found` *after* the
ABI pass already succeeded — which looks like a source bug but is not.

**Ricardian files must use HTML headings, not markdown.** CDT parses:

```html
<h1 class="contract">transfer</h1>      <!-- in <name>.contracts.md -->
<h1 class="clause">transfer_fee</h1>    <!-- in <name>.clauses.md   -->
```

Markdown `## transfer` is silently ignored: the build still succeeds, every
action logs `does not have a ricardian contract`, and the ABI ships with
`"ricardian_contract": ""` throughout. **Treat those warnings as errors.**

> **Both contracts now use the correct HTML form.** `warforzvault` carries
> Ricardian text on 16 of 16 actions with 10 clauses; `warforzlands` on 64 of 64
> with 7 clauses (it previously had 0 and 0, and 7 actions — `blockset`,
> `blockdel`, `equipstake`, `fprotate`, `resetuser`, `wdrawgold`, `wipeall` —
> had no entry written at all). The `warforzlands` ABI change is **not yet
> deployed**; see §6.3.

### 5.3.1 ⚠ The CDT version is load-bearing

**Build both contracts with CDT 4.1.1. Never 3.1.0.**

CDT 3.1.0's abigen ignores the name in a singleton declaration
(`singleton<"config"_n, config_s>`) and emits the *struct* name as the ABI table
name. All seven `warforzlands` singletons are affected:

| Declared | CDT 4.1.1 (correct) | CDT 3.1.0 (broken) |
|---|---|---|
| `config` | `config` | `config_s` |
| `ftconfig` | `ftconfig` | `ftconfig_s` |
| `nftconfig` | `nftconfig` | `nftconfig_s` |
| `accounts` | `accounts` | `account_s` |
| `rewardpool` | `rewardpool` | `rewardpool_s` |
| `goldbalance` | `goldbalance` | `goldbalance_s` |
| `freeplaystat` | `freeplaystat` | `freeplaystate_s` |

Deploying a 3.1.0-built ABI makes all seven unqueryable
(`Table config is not specified in the ABI`) and breaks the frontend, which
reads `config`, `ftconfig`, `accounts` and `rewardpool`. Actions and
`multi_index` tables are unaffected, which is what makes it easy to miss.
`warforzvault` uses no singletons, so its ABI was never affected — but build it
with 4.1.1 anyway so the artifact comes from the sanctioned toolchain.

**Reproducibility is the check.** On CDT 4.1.1, unchanged `warforzlands` source
rebuilds to the deployed hash bit-for-bit
(`c6f6541f…bcf4`). If yours differs for unchanged source, your CDT is wrong.

> `tests/normalize_wax_abi.ps1` exists only to repair 3.1.0 output. With 4.1.1
> it is unnecessary, and running it would rename 33 struct type labels and make
> the ABI diverge from what is deployed. Do not put it in the build path.

### 5.4 Verify the build before deploying

```powershell
$c = 'warforzvault'     # or 'warforzlands'
$d = "d:\Projects\pratice\wax chain\SC\silvertoken\build"   # or ...\mininggame\build
(Get-FileHash "$d\$c.wasm" -Algorithm SHA256).Hash.ToLower()
$abi = Get-Content -Raw "$d\$c.abi" | ConvertFrom-Json
"actions: $($abi.actions.Count)"
"ricardian: $((($abi.actions | Where-Object { $_.ricardian_contract -ne '' }).Count)) of $($abi.actions.Count)"
```

Expected for `warforzvault`: 16 actions, 16 of 16 ricardian, hash
`12362a1abd88acfd8b8164ec39b714454ca9be54581a0965cb2bba871e3793e0`.

---

## 6. Deploy

### 6.1 Deploy a contract (same shape for both)

```bash
cd "/mnt/d/Projects/pratice/wax chain/SC/silvertoken"    # or SC/mininggame
CONTRACT=warforzvault                                     # or warforzlands

# 1. confirm you are deploying what you built and audited
sha256sum build/$CONTRACT.wasm

# 2. see what is there now
cleos -u $NODE get code $CONTRACT

# 3. deploy
cleos -u $NODE set contract $CONTRACT "$(pwd)/build" \
      $CONTRACT.wasm $CONTRACT.abi -p $CONTRACT@active

# 4. the on-chain hash must now equal step 1
cleos -u $NODE get code $CONTRACT
```

### 6.2 Deploy an ABI-only change

When only the Ricardian files changed, the WASM is unchanged and there is no
reason to push code. `set abi` updates the ABI alone — cheaper, and it cannot
disturb running state:

```bash
cleos -u $NODE set abi $CONTRACT build/$CONTRACT.abi -p $CONTRACT@active
```

Confirm the WASM really is unchanged first:

```bash
sha256sum build/$CONTRACT.wasm
cleos -u $NODE get code $CONTRACT      # hashes must match
```

### 6.3 ✅ DONE 2026-08-17: the warforzlands security remediation

> **Shipped.** Deployed as `da72e8be…4ebb` together with the ORNG `randnotify`
> fix, so the built hash below (`38f444c7…`) is superseded. The acceptance tests
> in this section were run — results in §1. Kept for the procedure and the
> remaining acceptance items.

`warforzlands` has a **code** change pending, not just an ABI one. It closes all
five HIGH findings from the previous audit and adds three recovery actions
(`assocdel`, `craftcancel`, `minecancel`). See
[WARFORZLANDS_AUDIT.md](WARFORZLANDS_AUDIT.md).

| | |
|---|---|
| Built WASM | `38f444c7e1bea197fb4c50c5ecf6cea4d3e1d5b35437d87375611ed2f36ac2f7` |
| Currently live | `c6f6541fef6f4c66af4b388db3a4de4bd9d79f736d3fa9e175cfe13cb12fbcf4` |
| Actions | 64 → **67**, all with Ricardian text; 8 clauses |

> ⚠ This is `set contract`, not `set abi` — the code hash changes and the
> contract's behaviour changes with it. **Nothing in this build has executed.**
> Deploy it to testnet and work through the acceptance list below before
> considering mainnet.

```bash
cd "/mnt/d/Projects/pratice/wax chain/SC/mininggame"
sha256sum build/warforzlands.wasm     # expect 38f444c7…c2f7

cleos -u $NODE set contract warforzlands "$(pwd)/build" \
      warforzlands.wasm warforzlands.abi -p warforzlands@active

cleos -u $NODE get code warforzlands                                   # 38f444c7…
cleos -u $NODE get table warforzlands warforzlands ftconfig --limit 1  # singletons intact
```

That last query is the regression check — it proves the singleton table names
survived the ABI replacement.

#### Acceptance tests — none of this code has ever run

```bash
# 1. tosdel can no longer empty the ToS table
cleos -u $NODE push action warforzlands tosdel '[1]' -p warforzlands@active
#    expect: "cannot delete the current Terms of Service version"

# 2. a fresh request cannot be cancelled (staleness gate)
cleos -u $NODE push action warforzlands minecancel '["<player>", <assoc>]' -p <player>@active
#    expect: "request is not stale yet"

# 3. after an hour, cancelling a stuck mine releases the miner and the reservation
cleos -u $NODE get table warforzlands warforzlands rewardpool --limit 1   # note the balance
cleos -u $NODE push action warforzlands minecancel '["<player>", <assoc>]' -p <player>@active
cleos -u $NODE get table warforzlands warforzlands rewardpool --limit 1   # must have risen
cleos -u $NODE get table warforzlands <player> miners                     # plot_id back to 0

# 4. cancelling a stuck craft unlocks its non-burn inputs
cleos -u $NODE push action warforzlands craftcancel '["<player>", <assoc>]' -p <player>@active
cleos -u $NODE get table warforzlands <player> deposits                   # locked back to 0

# 5. admin can clear a stuck rotation, and fprotate then works
cleos -u $NODE push action warforzlands maintset '[true]'  -p warforzlands@active
cleos -u $NODE push action warforzlands assocdel '[<assoc>]' -p warforzlands@active
cleos -u $NODE push action warforzlands maintset '[false]' -p warforzlands@active
cleos -u $NODE push action warforzlands fprotate '["<any>"]' -p <any>@active

# 6. an ORPHANED assoc (no mine/craft row) clears too — this is what unblocked wipeall
#    verify rngassocs is empty afterwards
cleos -u $NODE get table warforzlands warforzlands rngassocs

# 7. resetuser completes across calls for an account holding >50 NFTs
cleos -u $NODE push action warforzlands resetuser '["<player>"]' -p warforzlands@active   # repeat
cleos -u $NODE get table warforzlands warforzlands templateuse   # must reach empty
```

### 6.4 Grant `eosio.code` (both contracts need it)

Required for any contract that sends inline actions. `warforzlands` already has
it on testnet; `warforzvault` does **not** yet.

```bash
cleos -u $NODE set account permission $CONTRACT active --add-code -p $CONTRACT@active
```

Check status without changing anything:

```bash
cleos -u $NODE get account $CONTRACT | grep -A2 active
# look for: warforzvault@eosio.code
```

For `warforzvault`, a missing `eosio.code` breaks **only fee-bearing transfers**
(the inline `logburn`). Fee-free traffic keeps working, so the failure surfaces
later, at §7.1 step 10, not at deploy time.

---

## 7. Configure

### 7.1 warforzvault — first-run setup

Full detail and rationale in [SC/silvertoken/README.md](SC/silvertoken/README.md).

```bash
# 1. create the symbol — max_supply is PERMANENT
cleos -u $NODE push action warforzvault create \
      '["warforzvault","1000000000.0000 SILVER"]' -p warforzvault@active

# 2. issue the float
cleos -u $NODE push action warforzvault issue \
      '["warforzvault","10000000.0000 SILVER","initial issuance"]' -p warforzvault@active

# 3. exemptions — NOT warforzvault yet; step 6 uses it to test the fee
cleos -u $NODE push action warforzvault exemptadd \
      '["warforzlands","game contract: credits player ledger from transfer notifications"]' -p warforzvault@active
cleos -u $NODE push action warforzvault exemptadd \
      '["warforzfees1","fee account: funds reward pool, receives withdrawal fees"]' -p warforzvault@active

# 4. lock them — setfee refuses a non-zero rate with no locked exemption
cleos -u $NODE push action warforzvault exemptlock '["warforzlands"]' -p warforzvault@active
cleos -u $NODE push action warforzvault exemptlock '["warforzfees1"]' -p warforzvault@active

# 5. both must show "locked": 1 before continuing
cleos -u $NODE get table warforzvault warforzvault feeexempt

# 6. enable the 0.50% burned fee
cleos -u $NODE push action warforzvault setfee '["4,SILVER",50]' -p warforzvault@active

# 7. FEE TEST — warforzvault is still un-exempt, so this transfer is taxed
cleos -u $NODE push action warforzvault transfer \
      '["warforzvault","testingwarfo","1000.0000 SILVER","fee test"]' -p warforzvault@active
#    trace must contain an inline >> logburn ... 5.0000 SILVER
cleos -u $NODE get currency balance warforzvault testingwarfo SILVER   # 995.0000 SILVER
cleos -u $NODE get table warforzvault SILVER stat                      # supply 9999995.0000

# 8. now exempt the treasury
cleos -u $NODE push action warforzvault exemptadd \
      '["warforzvault","issuer treasury"]' -p warforzvault@active
```

Step 7 is the acceptance test: it proves the fee arithmetic, the burn, the
`logburn` receipt and `eosio.code` all work together.

### 7.2 warforzlands — full configuration

Driven by [scripts/seed-config.sh](scripts/seed-config.sh), which seeds every
economic value from `WARFORZLANDS_ECONOMY_CONFIG_V1.md`.

```bash
cd "/mnt/d/Projects/pratice/wax chain"
./scripts/seed-config.sh testnet
```

To point it at SILVER instead of the disposable `8,WAX` stand-in:

```bash
FT_CONTRACT=warforzvault FT_SYMBOL=4,SILVER FT_DISPLAY_NAME=Silver \
  ./scripts/seed-config.sh testnet
```

### 7.3 ⚠ Switching the game's FT symbol requires a factory reset

`ftconfigset` enforces **the FT symbol is immutable after first configuration**
([warforzlands.cpp:392](SC/mininggame/src/warforzlands.cpp#L392)). Testnet is
currently configured for `eosio.token 8,WAX`, so re-running the seeder with
`FT_SYMBOL=4,SILVER` **will fail** until the config is wiped.

Only `wipeall` clears `ftconfig`, and it has hard preconditions:

| Precondition | How to satisfy |
|---|---|
| maintenance mode on | `maintset '[true]'` |
| `tosuser` empty | `resetuser` every registered player |
| `rngassocs` empty | wait for pending RNG to settle |
| `templateuse` empty | `resetuser` returns custodied NFTs |
| all recipe scopes passed | currently `equipment`, `essentials`, `land`, `miners` |

```bash
cleos -u $NODE push action warforzlands maintset '[true]' -p warforzlands@active
cleos -u $NODE push action warforzlands resetuser '["testingwarfo"]' -p warforzlands@active

# BOTH must come back empty before the next command
cleos -u $NODE get table warforzlands warforzlands tosuser
cleos -u $NODE get table warforzlands warforzlands templateuse

cleos -u $NODE push action warforzlands wipeall \
      '[["equipment","essentials","land","miners"]]' -p warforzlands@active

# re-seed from scratch, now pointing at SILVER
FT_CONTRACT=warforzvault FT_SYMBOL=4,SILVER FT_DISPLAY_NAME=Silver \
  ./scripts/seed-config.sh testnet

cleos -u $NODE push action warforzlands maintset '[false]' -p warforzlands@active
```

This erases all templates, recipes, ToS and config. `resetuser` refunds NFTs and
FT first, so nothing is lost — but re-seeding is mandatory afterwards.

**Confirm the recipe scopes are still those four before running `wipeall`:**

```bash
curl -s $NODE/v1/chain/get_table_by_scope \
  -d '{"code":"warforzlands","table":"craftrecipes","limit":100}' | jq '.rows[].scope'
```

Any scope you omit leaves orphaned recipe rows that `wipeall` will not clean up.

### 7.4 Fund the reward pool

Must come from the configured fee account with memo exactly `rewardpool`.

```bash
# issuer -> fee account (both exempt, nothing burned)
cleos -u $NODE push action warforzvault transfer \
      '["warforzvault","warforzfees1","500000.0000 SILVER","pool funding"]' -p warforzvault@active

# fee account -> game contract
cleos -u $NODE push action warforzvault transfer \
      '["warforzfees1","warforzlands","500000.0000 SILVER","rewardpool"]' -p warforzfees1@active
```

**Never fund straight from `warforzvault` to `warforzlands`.** Any memo other
than `rewardpool` is treated as a player deposit and hits `check_tos_accepted`,
and `rewardpool` is only accepted from the configured fee account. It reverts
safely, but it will not work.

---

## 8. Verification

```bash
# --- warforzvault ---
cleos -u $NODE get table warforzvault SILVER       stat
cleos -u $NODE get table warforzvault warforzvault feeconfig
cleos -u $NODE get table warforzvault warforzvault feeexempt

# --- warforzlands ---
cleos -u $NODE get table warforzlands warforzlands config     --limit 1
cleos -u $NODE get table warforzlands warforzlands ftconfig   --limit 1
cleos -u $NODE get table warforzlands warforzlands nftconfig  --limit 1
cleos -u $NODE get table warforzlands warforzlands rewardpool --limit 1

# --- end-to-end: deposit must credit with ZERO shortfall ---
cleos -u $NODE push action warforzvault transfer \
      '["testingwarfo","warforzlands","100.0000 SILVER",""]' -p testingwarfo@active
cleos -u $NODE get table warforzlands testingwarfo accounts --limit 1
#   must show exactly 100.0000 SILVER, and stat.supply must be UNCHANGED
```

That last check is the one that proves the fee exemption is live. Any shortfall
means `warforzlands` is not exempt and the game is accruing a deficit.

---

## 9. Mainnet

Do not treat mainnet as "the same commands with a different `$NODE`".

```bash
NODE=https://wax.greymass.com
CONFIRM_MAINNET=YES ./scripts/seed-config.sh mainnet
```

Blocking items before any mainnet deploy:

| Item | Source |
|---|---|
| Decide SILVER `max_supply` — permanent, no action raises it | `WARFORZVAULT_AUDIT.md` M2 |
| Decide the sink-recycling design (game sinks → `burn`?) | M2 |
| Split issuer from contract account **at `create` time** | H3, M1 |
| Both behind `eosio.msig`; resign contract account when code is final | H3 |
| Keys off disk — hardware wallet, never `testnet.txt`-style storage | H3 |
| Confirm fee-on-transfer against listing/DEX/bridge plans | M5 |
| Write a test suite — nothing has ever executed | M6 |
| Independent review by someone who did not write the code | both audits |
| Fix the ricardian format in `warforzlands.contracts.md`, add the 7 actions it never documented (57 headings vs 64 actions), rebuild, redeploy | §5.3 |
| Re-audit `warforzlands` — the audit predates the live binary | §1 |

Mainnet accounts, keys, collection and fee account are all **different** from
testnet. Re-do §2 for mainnet before you start, and never reuse a testnet key.

---

## 10. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Command 'wsl' not found` | You ran `wsl -d Ubuntu` while already inside WSL | Harmless; skip that line |
| `Error 3090003 … does not have signatures for it` | Wallet lacks the key for that account | §3 — `cleos wallet keys`, compare to §2, `cleos wallet import` |
| `Error 3120003: Locked wallet` | Wallet timed out | `cleos wallet unlock` |
| `ABI for contract X not found` | Contract not deployed (usually a cascade from an earlier failure) | Fix the first error; use `set -e` |
| `Table X is not specified in the ABI` | Same cascade | As above |
| `fatal error: 'include/<name>.hpp' file not found` after the ABI pass | Missing `-I .` | §5.3 |
| `Action <x> does not have a ricardian contract` | Markdown `##` headings in the `.md` | §5.3 — use `<h1 class="contract">` |
| `FT symbol is immutable after configuration` | `ftconfig` already set to another symbol | §7.3 factory reset |
| `lock at least one fee exemption before enabling a fee` | `setfee` ran before `exemptlock` | §7.1 steps 3–5 |
| `set every transfer fee to 0 before unlocking…` | `exemptunlock` while a fee is live | `setfee '["4,SILVER",0]'` first |
| Fee-bearing transfers revert, fee-free ones work | `eosio.code` not granted | §6.4 |
| `Table config is not specified in the ABI` after a rebuild | ABI built with CDT 3.1.0 | §5.3.1 — rebuild with 4.1.1 |
| Rebuilt WASM hash differs for unchanged source | Wrong CDT version | §5.3.1 |
| Deposit credits more than arrived | `warforzlands` not fee-exempt | §7.1 steps 3–4, then reconcile the deficit |
| `only the configured fee account may fund rewards` | Pool funded from the wrong account | §7.4 |

### Recovering a partial run

Every step here is idempotent or safely re-runnable **except**:

- `create` — one-shot per symbol; fails with "token with symbol already exists"
- `wipeall` — destructive; re-seed afterwards
- `setfee` first activation — later increases are timelocked 72h, so if you
  overshoot the rate, `setfee` **down** (immediate) rather than waiting

Re-running `set contract` with identical code is a no-op that still costs a
transaction. Re-running `exemptadd` on an existing row updates only its
`reason` and never clears `locked`.
