# Warforz Lands — System Audit (game + token together)

Date: 2026-08-17
Scope: the **integration** between `warforzlands` (game) and `warforzvault` (SILVER token)

The two contracts are audited individually elsewhere. This document covers what
neither of those can: the invariants that only exist when both are deployed and
wired to each other.

| Document | Scope |
|---|---|
| [WARFORZLANDS_AUDIT.md](WARFORZLANDS_AUDIT.md) | Game contract in isolation — 0 High, 6 Medium, 8 Low |
| [WARFORZVAULT_AUDIT.md](WARFORZVAULT_AUDIT.md) | Token contract in isolation — 1 High, 6 Medium, 6 Low |
| **This document** | The two together — 1 High, 4 Medium, 3 Low |

## Builds covered

| Contract | Audited WASM | Deployed (testnet) |
|---|---|---|
| `warforzlands` | `38f444c7e1bea197fb4c50c5ecf6cea4d3e1d5b35437d87375611ed2f36ac2f7` | `c6f6541f…bcf4` (older) |
| `warforzvault` | `12362a1abd88acfd8b8164ec39b714454ca9be54581a0965cb2bba871e3793e0` | none |

**Neither audited build is deployed. Neither has ever executed.**
The two have never run against each other in any environment.

---

## Summary

| Severity | Count | Findings |
|---|---|---|
| **High** | 1 | S1 |
| **Medium** | 4 | S2–S5 |
| **Low** | 3 | S6–S8 |

**No integration finding permits theft.** The failures available here are
*silent accounting divergence* and *silent loss of a user's deposit* — both of
which are worse than a revert, because nothing surfaces at the time.

### The one invariant that matters

Everything in this document reduces to a single solvency relation:

```
balance_of(warforzvault, warforzlands)   >=   Σ player ledgers  +  rewardpool.available
```

The left side is real tokens. The right side is what the game believes it owes.
The game **never checks this**, and cannot: it has no view of its own token
balance. Every High and Medium below is a way to break it.

---

## Verified sound

Worth stating, because these are the paths where an integration usually fails:

- **The withdrawal waterfall is exact.** `wdrawft` recomputes the fee from
  config and rejects a caller-supplied mismatch, then pays
  `platform_fee + referral + net`, which sums to exactly `quantity` — the amount
  debited. The referral share is carved *out of* the fee rather than added on
  top, so a referred player withdraws precisely what an unreferred one does. No
  rounding path lets the three payouts exceed the debit.
- **Basis-point conventions agree.** Both contracts define `BPS = 10000` and do
  the multiply in `int128`, so a rate means the same thing on both sides.
- **Reservation precedes randomness.** `reserve_reward` runs before the ORNG
  request, so FT liabilities can never exceed funded liquidity even with many
  concurrent mines.
- **Deposit notification wiring is correct.** `warforzvault::transfer` calls
  `require_recipient` on both parties, which is what fires the game's
  `[[eosio::on_notify("*::transfer")]]` handler; the game verifies
  `get_first_receiver()` against the configured contract before crediting, so a
  look-alike token cannot spoof a deposit.
- **The token knows nothing about the game.** No game dependency leaked into
  `warforzvault` — currency identity is read from config on the game side only,
  as the master spec requires.

---

## HIGH

### S1 — The solvency invariant is unmonitored, and it is already violated on testnet

Neither contract can see the relation above. The game tracks `rewardpool.available`
and per-player ledgers; the real tokens live in the token contract's `accounts`
row for `warforzlands`. Nothing reconciles them.

**Measured on testnet, 2026-08-17:**

| | |
|---|---|
| Real tokens held by `warforzlands` | **920.94831625 WAX** |
| Σ player ledgers | 100.00000000 WAX |
| `rewardpool.available` | singleton not set (0) |
| **Unaccounted surplus** | **~820.95 WAX** |

The surplus direction is *safe* — the contract holds more than it owes — and it
is the expected consequence of game finding M1 (sinks are one-way: `heal` and
craft FT inputs debit the player without crediting the pool). But it
demonstrates that the two sides of the relation drift with nothing observing it.

The dangerous direction is the same mechanism with the sign reversed. If the
game ever credits more than arrives — which is exactly what a transfer fee
without an exemption causes (S2) — the deficit is equally invisible, and it
surfaces only when a withdrawal fails for a player who did nothing wrong.

A second observation from the same query: **`rewardpool` does not exist on
testnet**, so `reserve_reward` would abort with "reward pool is not funded" and
no mine can currently be started. Whatever funded the pool previously has been
withdrawn or wiped.

**Fix.** Add an off-chain solvency monitor before mainnet — it is three queries
and a subtraction, and it is the only thing standing between a silent deficit
and a player-visible failure:

```bash
NODE=https://test.wax.eosusa.io
FT=$(cleos -u $NODE get table warforzlands warforzlands ftconfig --limit 1)
cleos -u $NODE get currency balance warforzvault warforzlands SILVER   # real
cleos -u $NODE get table warforzlands warforzlands rewardpool --limit 1 # owed: pool
# owed: ledgers — iterate tosuser, read each account singleton
```

Alert whenever `real < ledgers + pool`. Consider also reconciling the surplus
periodically so M1's growth is deliberate rather than accidental.

---

## MEDIUM

### S2 — A missing fee exemption converts every deposit into a silent shortfall

The token's transfer fee deducts from the delivered amount, but the notification
carries the **gross** `quantity`. The game credits the gross:

| Path | Game code | Result with fee, no exemption |
|---|---|---|
| Player deposit | `on_token_transfer` → `add_balance(from, quantity)` | Player credited 100%, contract receives 99.5% |
| Reward funding | memo `rewardpool` → `add_reward_pool(quantity)` | Pool believes it is 0.5% larger than its backing |

The token now enforces the two ordering hazards itself — a fee cannot be enabled
with no locked exemption, and a locked exemption cannot be released while a fee
is live. That closes the *accidental* paths.

What it does not close is identity: `has_locked_exemption()` counts locked rows,
it does not verify that `warforzlands` specifically is among them (token M8). And
no future integration is covered at all (token M7).

**Fix.** Treat "add and lock a `feeexempt` row" as a mandatory step in the
deployment checklist for every contract that will hold or receive SILVER, and
verify it with the deposit round-trip test before enabling the fee. The
solvency monitor in S1 is the backstop that catches it if the checklist is missed.

### S3 — A symbol or precision mismatch silently swallows deposits

`on_token_transfer` returns early when `quantity.symbol != ft.token_symbol`. The
tokens have already moved by then: they sit in the game contract, credited to
nobody, with no event and no revert.

`asset` compares symbols *including precision*, so `4,SILVER` and `8,SILVER` are
different symbols. Configuring the game with one precision and creating the token
with the other produces exactly this: every deposit is a silent total loss for
the depositing player.

Compounding it, `ftconfigset` makes the symbol **immutable after first
configuration**, so a mistake here cannot be corrected without a factory reset
(`maintset` → `resetuser` every player → `wipeall` → re-seed).

**Fix.** Before opening deposits, verify the two agree exactly:

```bash
cleos -u $NODE get table warforzlands warforzlands ftconfig --limit 1   # token_symbol
cleos -u $NODE get table warforzvault SILVER stat                       # supply symbol
```

Both must read `4,SILVER`. Then run one small deposit and confirm the ledger
moves by exactly the amount sent, before any player uses it.

### S4 — The game contract pays RAM for every withdrawing player's balance row

`wdrawft` transfers out with `warforzlands` as sender. Under the standard
`eosio.token` payer rule (`has_auth(to) ? to : from`), a player with no SILVER
balance row has that row billed to the **game contract**.

The cost is small per player and unbounded in aggregate; it grows with the player
base and is never reclaimed, since only the row's owner can `close` it.

**Fix.** Have the frontend call `warforzvault::open(player, "4,SILVER", player)`
at registration. That is what `open` exists for, and it moves the cost to the
player who benefits from it.

### S5 — Funding the reward pool has exactly one valid route, and the others fail confusingly

`add_reward_pool` accepts memo `rewardpool` **only** from the configured
`ft.fee_account`. Any other sender with that memo aborts. Any other memo is
treated as a player deposit and runs `check_tos_accepted(from)`, which aborts for
an unregistered account.

So a transfer straight from `warforzvault` (the issuer) to `warforzlands` fails —
which is correct, but the error names the Terms of Service and gives no hint that
the real problem is the funding route. Funding must go
`warforzvault → warforzfees1 → warforzlands`.

It fails safe: the transaction reverts and no tokens are lost.

**Fix.** Documented in the runbook §7.4; no code change warranted. Note that if
`ftconfig.fee_account` is ever changed, the previous funder immediately loses the
ability to top up the pool.

---

## LOW

| # | Finding |
|---|---|
| **S6** | **Fee-rate changes are invisible to the game.** The game snapshots its own economic terms before each RNG request, but the token's transfer fee is read live at transfer time. While `warforzlands` is exempt this is moot; if an exemption were ever removed, in-flight expectations and delivered amounts would diverge with no snapshot to appeal to. |
| **S7** | **`wipeall` refunds the pool to `fee_account` via a token transfer.** Correct while both accounts are exempt. If the fee ever applied to that leg, the factory-reset refund would silently lose its cut — the one path where a fee applies to a contract-initiated, non-player transfer. |
| **S8** | **Two independent fee systems share a name.** `ftconfig.withdraw_fee_pct` (game, 5%, paid to the fee account) and `feeconfig.transfer_fee_bps` (token, 0.5%, burned) are unrelated but both present as "the fee" in UI and support conversations. Worth distinguishing explicitly in the frontend to avoid mis-set configuration. |

---

## Deployment order (integration-critical)

The sequence matters because several steps are irreversible or gate each other:

1. Deploy `warforzvault`; grant it `eosio.code`.
2. `create` the symbol — **`max_supply` and precision are permanent.**
3. `exemptadd` + `exemptlock` for `warforzlands` and `warforzfees1` — **before** any fee.
4. `setfee` (rejected if step 3 was skipped).
5. Deploy the `warforzlands` remediation (`set contract`, code hash changes).
6. Factory-reset the game if `ftconfig` is already bound to another symbol —
   the FT symbol is immutable once set.
7. `ftconfigset` with `4,SILVER` — **verify the symbol matches the token exactly (S3).**
8. Fund the pool `warforzvault → warforzfees1 → warforzlands` memo `rewardpool` (S5).
9. **Deposit round-trip test: send a known amount, confirm the ledger moves by
   exactly that amount and `stat.supply` is unchanged.** This single test proves
   S2 and S3 simultaneously and is the gate on everything else.
10. Stand up the solvency monitor (S1) before opening to players.

---

## Verdict

The integration is designed correctly. Currency identity is configured rather
than hardcoded, the notification wiring is right, the withdrawal waterfall is
exact, and the token carries no knowledge of the game. The individual contracts
are in good shape — the game has no High findings left, and the token's only
High is key custody rather than code.

The system-level risk is not a flaw in either contract. It is that **the
relation binding them is unenforced and unobserved.** The game cannot see its own
token balance, so every way of breaking solvency — a missing exemption, a symbol
mismatch, a one-way sink — fails silently and accumulates. The testnet surplus of
~821 WAX against 100 WAX of ledgers is that drift already happening, in the safe
direction, with nobody watching.

Two things would change the risk profile more than any further code review:

1. **The deposit round-trip test** (step 9), which catches the two silent-loss
   failure modes at deployment time rather than in production.
2. **The solvency monitor** (S1), which is the only mechanism that would ever
   tell you the invariant has broken.

Beyond that, the limiting factor is unchanged and unchanged by more reading:
**neither audited build has executed, the two have never run against each other,
and no test suite exists for either.** An independent review by someone who did
not write this code remains necessary before mainnet.
