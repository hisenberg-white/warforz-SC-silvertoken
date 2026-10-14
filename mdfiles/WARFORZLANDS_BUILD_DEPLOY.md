# Warforz Lands — Build & Deploy Guide (WAX Testnet)

A complete, beginner-friendly walkthrough for compiling the `warforzlands` smart
contract and deploying it to the WAX testnet from this Windows machine.

Everything here was verified on **2026-08-16** during a real deployment
(tx `207baa51aa6f6b1d1767560c9d2ad1f04ec0e6de4d90c2595f951d5472bdfb1b`).

---

## 0. TL;DR — the happy path

If everything is already installed and you just want the commands:

```bash
# 1. Open a WSL Ubuntu terminal (NOT docker-desktop)
wsl -d Ubuntu

# 2. Unlock the wallet (paste password when prompted)
cleos wallet unlock

# 3. Build
cd "/mnt/d/Projects/pratice/wax chain/SC/mininggame"
mkdir -p build
cdt-cpp -abigen -contract warforzlands -I include -R . \
        -o build/warforzlands.wasm src/warforzlands.cpp

# 4. Check what you're about to change
sha256sum build/warforzlands.wasm
cleos -u https://test.wax.eosusa.io get code warforzlands

# 5. Deploy
cleos -u https://test.wax.eosusa.io set contract warforzlands \
      "$(pwd)/build" warforzlands.wasm warforzlands.abi \
      -p warforzlands@active

# 6. Verify the hash now matches step 4's sha256sum
cleos -u https://test.wax.eosusa.io get code warforzlands
```

If any of that is unfamiliar, read the rest of this document.

---

## 1. Before you start — what to open

Work through this checklist **in order**. Do not skip step 2; it is the single
most common cause of confusing errors on this machine.

### ☐ 1.1 Open a WSL Ubuntu terminal

All blockchain tooling (`cleos`, `cdt-cpp`) lives inside WSL, not Windows.

Open **Windows Terminal** or **PowerShell**, then run:

```powershell
wsl -d Ubuntu
```

> ⚠️ **The `-d Ubuntu` part is mandatory.** On this machine the *default* WSL
> distro is `docker-desktop`, which has none of the blockchain tools installed.
> Running plain `wsl` drops you into the wrong place and every command fails
> with "command not found".

Confirm you are in the right place:

```bash
lsb_release -a          # should say Ubuntu 26.04
which cleos             # should print /usr/bin/cleos
```

### ☐ 1.2 Confirm the wallet daemon and wallet

The wallet (`keosd`) holds the private key that signs the deployment. `cleos`
starts `keosd` automatically the first time you use a wallet command.

```bash
cleos wallet list
```

Expected output — note the `*`, which means **unlocked**:

```
Wallets:
[
  "default *"
]
```

- No `*` → the wallet is locked. See step 1.3.
- Empty list `[]` → no wallet exists yet. See §2.3 (one-time setup).

### ☐ 1.3 Unlock the wallet

```bash
cleos wallet unlock
```

It prompts for a password (nothing appears as you type — that is normal).

**Where is the password?** It is stored in plain text in
[`testnet/testnet.txt`](testnet/testnet.txt), on the line beginning `PW5KR3JS...`.

> The wallet re-locks after ~15 minutes of inactivity. If a deploy fails with
> "Error 3120003: Locked wallet", just run `cleos wallet unlock` again.

### ☐ 1.4 Confirm the signing key is loaded

```bash
cleos wallet keys
```

Must include the **active** public key for `warforzlands`:

```
EOS8Dp26CaNdJTEWDpqsM3fcPvYpGSNnvsYTrgtoXs6brWtMpCegq
```

If it is missing, see §2.3.

### ☐ 1.5 Confirm the network is reachable

```bash
cleos -u https://test.wax.eosusa.io get info
```

You want `"chain_id": "f16b1833c747c43682f4386fca9cbb327929334a762755ebec17f6f23c9b8a12"`.

> ⚠️ **Always check the chain_id.** It is your proof that you are pointed at
> testnet and not mainnet. See §10.

### ☐ 1.6 Confirm the compiler exists

```bash
cdt-cpp --version       # should print: cdt-cpp version 4.1.1
```

If this says "command not found", do §2.2 first.

### ☐ 1.7 Close anything holding the contract files

Close VS Code tabs / file explorers pointing at
`SC/mininggame/warforzlands.wasm`. Windows can lock these files and cause
"Permission denied" during the copy step.

---

## 2. One-time setup

You only need this section on a fresh machine, or if step 1 revealed something
missing.

### 2.1 Install `cleos` (Antelope Leap)

Already installed here as the `leap` package, version **5.0.3**. To reinstall:

```bash
cd /tmp
curl -L -o leap.deb https://github.com/AntelopeIO/leap/releases/download/v5.0.3/leap_5.0.3-ubuntu22.04_amd64.deb
sudo dpkg -i leap.deb
sudo apt-get install -f -y      # fixes any missing dependencies
cleos version client            # verify
```

### 2.2 Install CDT (the contract compiler)

CDT (Contract Development Toolkit) provides `cdt-cpp`, which compiles C++ into
WebAssembly and generates the ABI.

**Preferred — proper system install (needs your sudo password):**

```bash
cd /tmp
curl -L -o cdt.deb https://github.com/AntelopeIO/cdt/releases/download/v4.1.1/cdt_4.1.1-1_amd64.deb
sudo dpkg -i cdt.deb
cdt-cpp --version
```

**Fallback — no sudo available:**

You can unpack the `.deb` without installing it. CDT is self-contained and runs
fine from any directory.

```bash
cd /tmp
curl -L -o cdt.deb https://github.com/AntelopeIO/cdt/releases/download/v4.1.1/cdt_4.1.1-1_amd64.deb
mkdir -p ~/cdt && dpkg-deb -x cdt.deb ~/cdt
echo 'export PATH="$HOME/cdt/usr/opt/cdt/4.1.1/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
cdt-cpp --version
```

> ⚠️ Extract to `~/cdt`, **not** `/tmp`. Anything in `/tmp` is deleted when WSL
> restarts, and you will have to download the 125 MB package again.
>
> This is exactly the state the machine was left in on 2026-08-16: CDT was
> extracted to `/tmp/cdtx` because sudo needed a password. **That copy is gone
> after a reboot.** Do a proper install (or the `~/cdt` fallback) before your
> next build.

### 2.3 Create the wallet and import the key

Only if `cleos wallet list` was empty or missing the key.

```bash
# Create the wallet — SAVE THE PASSWORD IT PRINTS
cleos wallet create --to-console

# Unlock it
cleos wallet unlock

# Import the warforzlands ACTIVE private key (starts with 5K...)
# Find it in testnet/testnet.txt under "active_key" -> "private"
cleos wallet import
```

`cleos wallet import` prompts for the private key so it does not end up in your
shell history. Paste it and press Enter.

> 🔐 You only need the **active** key to deploy. Leave the **owner** key out of
> the wallet — it is your recovery key, and a locked-away owner key is what
> lets you recover if the active key is ever compromised.

---

## 3. Key facts — accounts, endpoints, paths

### Accounts

| Item | Value |
|---|---|
| Contract account | `warforzlands` |
| Active public key | `EOS8Dp26CaNdJTEWDpqsM3fcPvYpGSNnvsYTrgtoXs6brWtMpCegq` |
| Owner public key | `EOS7i1oLYBvh4aMbPAEpr7K6a9iMiLfxbvZ2QP2w1S9L3VkL8bxTp` |
| Test player account | `testingwarfo` |
| Fee account (config default) | `warforzfees1` |
| Permission used to deploy | `warforzlands@active` |

The account also has `warforzlands@eosio.code` on its active permission. That is
required — it lets the contract send inline actions to itself and to
AtomicAssets. Do not remove it.

**Private keys and the wallet password live in
[`testnet/testnet.txt`](testnet/testnet.txt).**

> 🔐 These are **testnet-only** keys. Testnet WAX has no monetary value, which is
> why storing them in the repo is tolerable. Never reuse any of these keys, or
> this storage pattern, on mainnet.

### Endpoints

| Network | RPC endpoint | Chain ID |
|---|---|---|
| **Testnet** (primary) | `https://test.wax.eosusa.io` | `f16b1833c747c43682f4386fca9cbb327929334a762755ebec17f6f23c9b8a12` |
| **Testnet** (backup) | `https://testnet.waxsweden.org` | same as above |
| Mainnet — ⚠️ see §10 | `https://wax.greymass.com` | `1064487b3cd1a897ce03ae5b6a865651747e2e152090f99c1d19d44e01aea5a4` |

Testnet block explorer: <https://testnet.waxblock.io/account/warforzlands>

### Paths

| What | Windows | Inside WSL |
|---|---|---|
| Project root | `d:\Projects\pratice\wax chain` | `/mnt/d/Projects/pratice/wax chain` |
| Contract folder | `…\SC\mininggame` | `…/SC/mininggame` |
| Source | `src\warforzlands.cpp` | `src/warforzlands.cpp` |
| Headers | `include\warforzlands.hpp` | `include/warforzlands.hpp` |
| Build output | `build\` | `build/` |

> ⚠️ **The path contains a space** ("wax chain"). Always wrap paths in double
> quotes in bash, or the command will break in confusing ways:
> ```bash
> cd "/mnt/d/Projects/pratice/wax chain/SC/mininggame"   # ✅
> cd /mnt/d/Projects/pratice/wax chain/SC/mininggame     # ❌ breaks
> ```

### Source layout

```
SC/mininggame/
├── CMakeLists.txt              # optional CMake build definition
├── src/warforzlands.cpp        # all action implementations (~128 KB)
├── include/
│   ├── warforzlands.hpp        # contract class, TABLE structs, action decls
│   └── ext/
│       ├── atomicassets.hpp    # AtomicAssets NFT interface
│       ├── token.hpp           # eosio.token interface
│       └── wax_orng.hpp        # WAX RNG oracle interface
├── warforzlands.contracts.md   # Ricardian contracts
├── warforzlands.clauses.md     # Ricardian clauses
├── warforzlands.wasm           # last built/deployed binary
└── warforzlands.abi            # last built/deployed ABI
```

---

## 4. Build the contract

### 4.1 The build command

```bash
cd "/mnt/d/Projects/pratice/wax chain/SC/mininggame"
mkdir -p build

cdt-cpp -abigen \
        -contract warforzlands \
        -I include \
        -R . \
        -o build/warforzlands.wasm \
        src/warforzlands.cpp
```

What each flag does:

| Flag | Meaning |
|---|---|
| `-abigen` | Also generate `warforzlands.abi` next to the `.wasm`. Without this you get a binary with no ABI, and nothing can call it. |
| `-contract warforzlands` | The contract name recorded in the ABI. **Must match the account** you deploy to. |
| `-I include` | Where to find `warforzlands.hpp` and `ext/*.hpp`. |
| `-R .` | Where to find the Ricardian `.md` files. |
| `-o build/warforzlands.wasm` | Output path. The `.abi` is written alongside it. |

Build takes roughly 1–3 minutes.

### 4.2 Expected output

You will see **many** warnings like:

```
Warning, action <mine> does not have a ricardian contract
Warning, action <heal> does not have a ricardian contract
...
```

**These are harmless.** Ricardian contracts are optional human-readable legal
descriptions per action. The build succeeded if you end with:

```
=== BUILD EXIT: 0 ===
```

and both files exist:

```bash
ls -la build/
# warforzlands.abi    ~71 KB
# warforzlands.wasm   ~295 KB
```

Reference values from the 2026-08-16 build:

| File | Size |
|---|---|
| `warforzlands.wasm` | 295,699 bytes |
| `warforzlands.abi` | 71,798 bytes |

### 4.3 Alternative: CMake

`CMakeLists.txt` is present and works the same way. It needs `cmake` installed
in WSL (`sudo apt install cmake`), which was **not** verified on this machine.

```bash
cd "/mnt/d/Projects/pratice/wax chain/SC/mininggame"
mkdir -p build && cd build
cmake ..
make
```

The direct `cdt-cpp` command in §4.1 is what was actually used and verified.
Prefer it unless you have a reason not to.

---

## 5. Pre-deploy checks — do not skip these

This is the part beginners skip and then spend an afternoon debugging.

### 5.1 Will this deploy actually change anything?

Compare your new binary's hash against what is live:

```bash
# Hash of what you just built
sha256sum build/warforzlands.wasm

# Hash of what is currently on chain
cleos -u https://test.wax.eosusa.io get code warforzlands
```

- **Hashes differ** → good, you have a real change to deploy.
- **Hashes are identical** → the deploy would be a no-op. Either you already
  deployed this code, or you forgot to rebuild after editing.

> 💡 This exact trap hit us on 2026-08-16: the source had been edited a day
> after the last build, so `warforzlands.wasm` on disk was stale and its hash
> still matched the chain. Deploying it would have changed nothing while
> looking like it worked.

### 5.2 Did the ABI's action list change?

Compare the actions in your new ABI against the live one:

```bash
# Live ABI
cleos -u https://test.wax.eosusa.io get abi warforzlands > /tmp/live.abi

# Action names, live vs new
python3 -c "import json;print(sorted(a['name'] for a in json.load(open('/tmp/live.abi'))['actions']))"
python3 -c "import json;print(sorted(a['name'] for a in json.load(open('build/warforzlands.abi'))['actions']))"
```

Any action that disappears is a **breaking change for the frontend**. Before
deploying, grep the frontend for it:

```bash
grep -rn "actionname" "/mnt/d/Projects/pratice/wax chain/Frontend/src"
```

### 5.3 Did any table's row layout change?

This is the dangerous one. Adding, removing, or reordering a field in a `TABLE`
struct changes how rows are decoded — **existing rows already on chain will
decode as garbage**, because the raw bytes were written under the old layout.

Table *names* and struct *names* are safe to look at, but what matters is the
**field list and order** of each table's row struct.

If you changed a `TABLE` struct in `warforzlands.hpp`, you must plan a data
migration — normally: add a new table, copy rows over with a migration action,
then delete the old one. Do not just deploy and hope.

> Renaming a struct (e.g. `craftrow` → `craft_s`) while keeping its fields
> identical is **safe**. Serialization depends on field order and types, not on
> the struct's name.

### 5.4 Check account resources

```bash
cleos -u https://test.wax.eosusa.io get account warforzlands
```

Look at:

- **memory / RAM** — needs free space of at least the new wasm size. As of
  2026-08-16: quota 8.849 MiB, used 2.951 MiB, so ~5.9 MiB free. Plenty.
- **cpu bandwidth** — deploying a ~300 KB contract is CPU-heavy. ~1.95 sec
  available was ample.
- **net bandwidth** — the transaction is ~81 KB.

If RAM is short:

```bash
cleos -u https://test.wax.eosusa.io system buyram warforzlands warforzlands "10.00000000 WAX" -p warforzlands@active
```

### 5.5 Back up what is currently deployed

Always, so you can roll back.

```bash
cd "/mnt/d/Projects/pratice/wax chain"
BK="archive/deployed-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BK"
cp SC/mininggame/warforzlands.wasm "$BK/"
cp SC/mininggame/warforzlands.abi  "$BK/"
echo "Backed up to $BK"
```

---

## 6. Deploy

### 6.1 The deploy command

```bash
cd "/mnt/d/Projects/pratice/wax chain/SC/mininggame"

cleos -u https://test.wax.eosusa.io set contract warforzlands \
      "$(pwd)/build" \
      warforzlands.wasm warforzlands.abi \
      -p warforzlands@active
```

Breaking it down:

| Part | Meaning |
|---|---|
| `-u https://test.wax.eosusa.io` | Which network. **Get this wrong and you deploy to mainnet.** |
| `set contract` | Push code + ABI in one transaction (`setcode` + `setabi`). |
| `warforzlands` | The account receiving the code. |
| `"$(pwd)/build"` | Folder holding the artifacts. Use an absolute path. |
| `warforzlands.wasm warforzlands.abi` | The two files, relative to that folder. |
| `-p warforzlands@active` | Sign with the active permission. |

### 6.2 What success looks like

```
Reading WASM from .../build/warforzlands.wasm...
Publishing contract...
executed transaction: 207baa51aa6f...  80976 bytes  5680 us
warn  transaction executed locally, but may not be confirmed by the network yet
#         eosio <= eosio::setcode      {"account":"warforzlands",...}
#         eosio <= eosio::setabi       {"account":"warforzlands",...}
```

Both `setcode` **and** `setabi` must appear. Save the transaction ID.

> The "may not be confirmed by the network yet" warning is **normal**. It means
> your node accepted the transaction but it is not yet irreversible. §7 confirms
> it properly.

### 6.3 Deploying code and ABI separately

If the combined transaction is too large or times out:

```bash
# Code only
cleos -u https://test.wax.eosusa.io set code warforzlands build/warforzlands.wasm -p warforzlands@active

# ABI only
cleos -u https://test.wax.eosusa.io set abi  warforzlands build/warforzlands.abi  -p warforzlands@active
```

---

## 7. Verify the deployment

Never trust the deploy output alone. Confirm against the chain.

### 7.1 Code hash — check on two endpoints

```bash
sha256sum build/warforzlands.wasm
cleos -u https://test.wax.eosusa.io   get code warforzlands
cleos -u https://testnet.waxsweden.org get code warforzlands
```

All three must print the same hash. Checking a second, independent endpoint
proves the change actually propagated across the network rather than sitting on
one node.

### 7.2 ABI landed correctly

```bash
cleos -u https://test.wax.eosusa.io get abi warforzlands > /tmp/live.abi
python3 -c "
import json
a=json.load(open('/tmp/live.abi'))
print('actions:', len(a['actions']))
print('tables :', len(a['tables']))
print('structs:', len(a['structs']))
"
```

Reference values after the 2026-08-16 deploy: **64 actions, 33 tables,
103 structs**.

### 7.3 Existing data still decodes

The real proof that you did not break the tables. Read a few and confirm the
values look sane rather than garbled:

```bash
cleos -u https://test.wax.eosusa.io get table warforzlands warforzlands config      --limit 1
cleos -u https://test.wax.eosusa.io get table warforzlands warforzlands minerconf   --limit 3
cleos -u https://test.wax.eosusa.io get table warforzlands warforzlands miningtypes --limit 3
```

Healthy `config` output looks like:

```json
{"maintenance_mode":0,"collection_name":"warforzlands","mining_fee_pct":"0.00000000000000000",
 "referral_rate":"0.00000000000000000","next_assoc_id":1,"max_freeplay_lands_per_account":1,
 "referral_cycle_depth":10,"max_nft_drop_rate":"0.10000000000000001"}
```

Nonsense values, absurd numbers, or a decode error mean the row layout changed —
see §5.3, and roll back (§8).

### 7.4 If WSL dies mid-verification

WSL became unresponsive right after the 2026-08-16 deploy
(`HCS_E_CONNECTION_TIMEOUT`). You can verify entirely from **Windows
PowerShell** without WSL, by calling the RPC directly:

```powershell
Invoke-RestMethod -Uri "https://test.wax.eosusa.io/v1/chain/get_code_hash" `
  -Method Post -Body '{"account_name":"warforzlands"}' `
  -ContentType "application/json" | Select-Object -ExpandProperty code_hash
```

To recover WSL:

```powershell
wsl --shutdown
wsl -d Ubuntu
```

`wsl --shutdown` stops **all** distros, including docker-desktop, so Docker
containers will restart too.

---

## 8. Rollback

Your backup folder from §5.5 is a complete, deployable contract.

```bash
cleos -u https://test.wax.eosusa.io set contract warforzlands \
      "/mnt/d/Projects/pratice/wax chain/archive/deployed-backup-YYYYMMDD-HHMMSS" \
      warforzlands.wasm warforzlands.abi \
      -p warforzlands@active
```

The 2026-08-16 backup is at `archive/deployed-backup-20260816-054257`
(code hash `cc09665b98f28641a0e7eaab1a2d460cc0b8f5bb0db9c2d555b543c435fe2d7b`).

> ⚠️ Rolling back **code** is instant and safe. Rolling back does **not** undo
> any table data written by the newer version. If the new code wrote rows in a
> new layout, restoring old code can leave those rows undecodable.

---

## 9. After deploying — seed the configuration

A freshly deployed contract still needs its economy data. Two scripts do this.

### 9.1 Main configuration

```bash
cd "/mnt/d/Projects/pratice/wax chain"
./scripts/seed-config.sh testnet
```

Every value traces back to
[`WARFORZLANDS_ECONOMY_CONFIG_V1.md`](WARFORZLANDS_ECONOMY_CONFIG_V1.md).
The script verifies the chain ID before writing, and never imports keys — it
relies on your already-unlocked wallet.

> ⚠️ Four templates required by economy V1 have **no template ID configured**
> because they were never minted: `MINER_ARTIFACT`, `MINER_LEGENDARY`,
> `EQUIP_EPIC`, `EQUIP_LEGENDARY`. The script refuses to run until you either
> supply them or explicitly skip them:
>
> ```bash
> # Supply them once minted
> MINER_ARTIFACT=664530 MINER_LEGENDARY=664531 \
> EQUIP_EPIC=664532 EQUIP_LEGENDARY=664533 \
>   ./scripts/seed-config.sh testnet
>
> # Or seed everything else for now
> ALLOW_MISSING_TIERS=YES ./scripts/seed-config.sh testnet
> ```

### 9.2 Smithy crafting recipes

```bash
./testnet/configure-smithy.sh
```

> As of 2026-08-16 the `craftrecipes` table is **empty (0 rows)** — crafting is
> not configured on the current build. Run this script if you need the Smithy
> working.

Check whether recipes exist:

```bash
cleos -u https://test.wax.eosusa.io get table warforzlands warforzlands craftrecipes --limit 5
```

### 9.3 If a seeding script times out

Both scripts are written to be re-runnable: they check whether a row already
exists before writing it. If one times out, **do not re-push the action by
hand** — the transaction result is uncertain. Just run the script again and let
it reconcile against the chain.

---

## 10. ⚠️ Mainnet

This document is for **testnet**. Before ever touching mainnet:

1. **Everything is permanent.** Real WAX, real user assets, real money.
2. **The endpoint is the only difference in the command.** `-u https://wax.greymass.com`
   instead of `-u https://test.wax.eosusa.io`. It is genuinely that easy to
   deploy to the wrong chain. Always run `get info` and check the chain ID first.
3. **Mainnet keys must never live in a repo file** the way testnet keys do in
   `testnet/testnet.txt`. Use a hardware wallet or a properly secured signer.
4. **`seed-config.sh` requires `CONFIRM_MAINNET=YES`** as a deliberate safety gate.
5. **Get the contract audited.** See [`WARFORZLANDS_AUDIT.md`](WARFORZLANDS_AUDIT.md).
6. **Consider giving up `setcode`.** Once stable, moving the contract's code
   permission to a multisig or `eosio.null` is what makes it genuinely
   trustless — but it also means you can never patch it again.

---

## 11. Troubleshooting

Problems actually hit on this machine, and their fixes.

### "command not found: cleos" / "cdt-cpp"

You are in the wrong WSL distro. Exit and run `wsl -d Ubuntu`. See §1.1.

### "Error 3120003: Locked wallet"

```bash
cleos wallet unlock
```

### "Error 3090003: Provided keys, permissions... not sufficient"

The active key is not in the wallet. `cleos wallet keys` should list
`EOS8Dp26CaNdJTEWDpqsM3fcPvYpGSNnvsYTrgtoXs6brWtMpCegq`. If not, see §2.3.

### "Permission denied" writing `warforzlands.wasm`

`SC/mininggame/warforzlands.wasm` is owned by `root` on the Windows mount, so
WSL cannot overwrite it. Two ways out:

```bash
# From WSL, with sudo
sudo cp build/warforzlands.wasm warforzlands.wasm
```

```powershell
# Or from Windows PowerShell, which is not subject to the WSL ownership
Copy-Item "d:\Projects\pratice\wax chain\SC\mininggame\build\warforzlands.wasm" `
          "d:\Projects\pratice\wax chain\SC\mininggame\warforzlands.wasm" -Force
```

This does **not** block deployment — `cleos` only needs to *read* the files in
`build/`. It only affects keeping the repo copies in sync.

### Deploy times out or hangs

Public RPCs throttle large transactions. Try the backup endpoint, or split code
and ABI (§6.3):

```bash
cleos -u https://testnet.waxsweden.org set contract ...
```

> ⚠️ If a deploy times out, **check the chain before retrying** (§7.1). The node
> may have accepted the transaction and only dropped the response.

### "Transaction exceeds allowed CPU/NET usage"

The network is congested or the account is low on resources. Wait a few minutes,
or stake more:

```bash
cleos -u https://test.wax.eosusa.io system delegatebw warforzlands warforzlands \
      "10.00000000 WAX" "50.00000000 WAX" -p warforzlands@active
```

(Order is NET then CPU.)

### WSL: `HCS_E_CONNECTION_TIMEOUT`

```powershell
wsl --shutdown
wsl -d Ubuntu
```

Verify deployments from PowerShell in the meantime (§7.4).

### Calling WSL from PowerShell mangles the command

PowerShell expands `$PATH` and misreads `|` before WSL ever sees them, and Git
Bash rewrites `/usr/...` into Windows paths. Symptoms are bizarre errors
mentioning `Program Files (x86)`.

**Fix: put your commands in a `.sh` file and run the file.** It sidesteps all
quoting problems:

```powershell
wsl -d Ubuntu -- bash "/mnt/c/path/to/script.sh"
```

From Git Bash, prefix with `MSYS_NO_PATHCONV=1`.

Best practice: just work **inside** a WSL terminal (§1.1) and avoid the issue.

### The ABI trap — hand-edited ABI files

**Read this if you ever edit `warforzlands.abi` by hand.**

The committed ABI had been hand-edited to use friendlier struct names
(`config`, `miner`, `modifier`) than the source actually generates (`config_s`,
`miner_s`, `Modifier`). That is cosmetic and harmless on its own.

The real problem: because it was maintained by hand, it **drifted out of sync**
with the contract. It still advertised `listland` and `unlistland` actions long
after they had been deleted from the source. A frontend reading that ABI would
happily build a transaction for an action that no longer exists, and it would
fail on chain.

**Rule: never hand-edit the ABI.** Always deploy the `-abigen` output. If you
want friendlier names, rename the structs in `warforzlands.hpp` so the generator
produces them.

---

## 12. Command cheat sheet

```bash
# --- Environment ---
wsl -d Ubuntu                                  # correct WSL distro
cleos version client                           # cleos version
cdt-cpp --version                              # compiler version

# --- Wallet ---
cleos wallet list                              # '*' = unlocked
cleos wallet unlock                            # prompts for password
cleos wallet keys                              # public keys loaded
cleos wallet lock                              # lock when done

# --- Chain info ---
NODE=https://test.wax.eosusa.io
cleos -u $NODE get info                        # CHECK THE CHAIN ID
cleos -u $NODE get account warforzlands        # resources, permissions
cleos -u $NODE get code warforzlands           # deployed code hash
cleos -u $NODE get abi  warforzlands           # deployed ABI

# --- Build ---
cd "/mnt/d/Projects/pratice/wax chain/SC/mininggame"
mkdir -p build
cdt-cpp -abigen -contract warforzlands -I include -R . \
        -o build/warforzlands.wasm src/warforzlands.cpp
sha256sum build/warforzlands.wasm

# --- Deploy ---
cleos -u $NODE set contract warforzlands "$(pwd)/build" \
      warforzlands.wasm warforzlands.abi -p warforzlands@active
cleos -u $NODE set code warforzlands build/warforzlands.wasm -p warforzlands@active
cleos -u $NODE set abi  warforzlands build/warforzlands.abi  -p warforzlands@active

# --- Read tables ---
cleos -u $NODE get table warforzlands warforzlands config --limit 1
cleos -u $NODE get table warforzlands warforzlands minerconf --limit 10
cleos -u $NODE get table warforzlands <player> account --limit 10

# --- Call an action manually ---
cleos -u $NODE push action warforzlands <action> '<json-args>' -p warforzlands@active

# --- Seed configuration ---
cd "/mnt/d/Projects/pratice/wax chain"
./scripts/seed-config.sh testnet
./testnet/configure-smithy.sh
```

---

## 13. Deployment log

| Date | Code hash | Notes |
|---|---|---|
| 2026-08-14 | `cc09665b98f28641a0e7eaab1a2d460cc0b8f5bb0db9c2d555b543c435fe2d7b` | 306,184 B. Hand-edited ABI, 66 actions. |
| 2026-08-16 | `c6f6541fef6f4c66af4b388db3a4de4bd9d79f736d3fa9e175cfe13cb12fbcf4` | 295,699 B. Generated ABI, 64 actions. Removed `listland`/`unlistland`. tx `207baa51aa6f6b1d1767560c9d2ad1f04ec0e6de4d90c2595f951d5472bdfb1b` |

Add a row here every time you deploy. Recording the hash is what makes it
possible to answer "what is actually running right now?" later.

---

## Related documents

- [`WARFORZLANDS_CONTRACT.md`](WARFORZLANDS_CONTRACT.md) — contract design and action reference
- [`WARFORZLANDS_ECONOMY_CONFIG_V1.md`](WARFORZLANDS_ECONOMY_CONFIG_V1.md) — economy values
- [`WARFORZLANDS_AUDIT.md`](WARFORZLANDS_AUDIT.md) — audit findings
- [`WARFORZLANDS_FRONTEND.md`](WARFORZLANDS_FRONTEND.md) — frontend integration
