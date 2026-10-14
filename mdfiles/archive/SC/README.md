# WarForz Lands smart contract

Configuration-driven WAX/Antelope mining and crafting contract. The authoritative mechanics and accepted decisions are in `../../WARFORZLANDS_MASTER_SPEC.md`; implementation and release status are in `../../WARFORZLANDS_IMPLEMENTATION_REPORT.md`.

## Build and verify

With Antelope CDT 3.1.0:

```sh
cdt-cpp --contract=warforzlands -abigen -R . -I include -o warforzlands.wasm src/warforzlands.cpp
```

Or use the reproducible container:

```sh
docker build -f tests/Dockerfile.cdt -t warforz-cdt:3.1.0 .
docker run --rm -v "$PWD:/project" warforz-cdt:3.1.0 --contract=warforzlands -abigen -R /project -I /project/include -o /project/warforzlands.wasm /project/src/warforzlands.cpp
pwsh tests/static_contract_checks.ps1
pwsh tests/normalize_wax_abi.ps1
```

The normalization step is required for Leap 5/WAX deployment: it converts
CDT-derived C++ row labels such as `account_s` into valid EOS ABI type names
and restores singleton table names to their physical on-chain identifiers.

## Deployment order

Use a fresh WAX testnet account first.

1. Set the contract account's active permission to include `eosio.code`.
2. Deploy the generated `warforzlands.wasm` and `warforzlands.abi` with maintenance enabled.
3. Grant the contract the required AtomicAssets collection permissions for all configured mint and burn paths.
4. Configure `configset`, `ftconfigset`, `nftconfigset`, ToS, Miner, Land, Equipment, Mining Type, match, Slot, Free Play, and crafting rows. Long conceptual spec names use EOS-safe physical names: `miningtypes`, `landminmatch`, `fpselectors`, `matchset/matchdel`, and `fpselset/fpseldel`.
5. Register the FT fee account and any platform accounts with the current ToS.
6. Fund rewards by transferring the configured FT **from `ftconfig.fee_account`** to the contract with memo `rewardpool`. The contract reserves maximum mining/crafting liabilities before RNG; underfunded requests fail before consuming gameplay state.
7. Start Free Play with `fpstart` only after at least one enabled selector is configured and the correct ORNG service is available.
8. Run every testnet scenario and reconcile custody and liabilities before disabling maintenance.

## Security model

- Player writes require player authority, current ToS, and non-maintenance state.
- Admin configuration requires contract authority.
- `receiverand` accepts only `orng.wax` and only known association IDs.
- Mining economics/destruction terms and crafting result rules are snapshotted before asynchronous RNG.
- Independent RNG outcomes consume non-overlapping checksum lanes.
- Contract FT liabilities cannot exceed the funded reward pool; pending maximum liabilities are reserved.
- NFT deposits are bounded and collection/template validated. Template usage is tracked so live custody configuration cannot be deleted or silently changed.
- Removal, depletion, death, slot consumption, and crafting input paths burn the real AtomicAssets NFT where the mechanic is destructive.
- Withdrawal fees are recomputed and strictly matched on-chain.
- Recipe/rule references and pending mining-type requests block unsafe deletion.

These controls do not replace live integration testing or an external audit. Mainnet deployment is explicitly out of scope until both are complete.
