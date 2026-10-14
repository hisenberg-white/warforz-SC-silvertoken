# WarForz Lands
## Product Requirements Document (PRD)

Version: 1.0
Blockchain: WAX
Backend: EOSIO Smart Contracts
Frontend: React
Authentication: WAX Wallet

---

# Table of Contents

1. Overview
2. Core Game Assets
3. Authentication
4. Currency System
5. Slot System
6. Land System
7. Miner System
8. Equipment / Booster System
9. Mining System
10. Mining Types
11. Durability System
12. Health System
13. Crafting (Smithy)
14. Admin Configuration System
15. Future Expansion
16. Smart Contract Modules
17. Frontend Modules

---

# 1. Overview

WarForz Lands is a blockchain mining strategy game built on WAX.

Players own NFTs that represent:

- Slots
- Lands
- Miners
- Equipment
- Boosters

Players stake these NFTs into the game to mine in-game currencies.

There are two reward currencies:

- Fungible Token (Silver)
- NFT Reward (Gold)

Mining rewards are determined by configurable probabilities, NFT attributes, boosters, mining types, RNG, and admin-defined game configurations.

The entire game should be highly configurable so future content can be introduced without deploying new smart contract logic whenever possible.

---

# 2. Core Game Assets

## Slots

Purpose:

- Holds one active Land.

Default:

- Every new account starts with one unlocked slot.

Maximum Initial Slots:

- 5

Future:

Admin should be able to create additional slot indexes without contract modification.

---

## Lands

Purpose:

A Land acts as the mining location.

Properties:

- Rarity
- Durability
- Compatible Miner Types
- Mining Bonus
- Mining Restrictions
- Unlimited/Finite Durability
- Mining Type Restrictions

Example rarities:

- Common
- Rare
- Epic
- Legendary

---

## Miners

Purpose:

Produces mining rewards.

Properties:

- Base Silver Reward
- Base Gold Reward Chance
- Health
- Max Health
- Mining Power
- Compatible Boosters
- Compatible Lands

---

## Equipment / Boosters

Purpose:

Increase mining rewards.

Properties:

- Reward Multiplier
- NFT Drop Multiplier
- FT Reward Multiplier
- Durability
- Compatible Miner Types

---

## Reward Currencies

### FT Currency

Example:

Silver Token

Configurable:

- Contract Address
- Symbol
- Precision

### NFT Currency

Example:

Gold NFT

Configurable:

- Collection
- Schema
- Template IDs

---

# 3. Authentication

Login Method

- WAX Wallet Login

Signup

- Automatic on first login

Referral

Signup URL may contain:

```

?ref=username

```

Requirements

- Store referral
- Validate referral
- Prevent self-referrals
- Referral reward configurable

---

# 4. Currency Configuration

Admin should configure:

## FT Currency

- Contract
- Symbol
- Precision

## NFT Currency

- Collection
- Schema
- Template IDs

The contract must never hardcode these values.

---

# 5. Slot System

Every player starts with:

```

Slot 1 (Unlocked)

```

Remaining slots are locked.

Example

```

Slot 1 ✔
Slot 2 🔒
Slot 3 🔒
Slot 4 🔒
Slot 5 🔒

```

Unlocking

Each slot requires its own Slot NFT.

Example

```

Slot 2 NFT
→ unlocks Slot 2 only

Slot 3 NFT
→ unlocks Slot 3 only

```

Rules

- Slots must be unlocked sequentially.
- Cannot unlock Slot 3 before Slot 2.
- Slot NFT is burned permanently.
- Unlock cannot be reversed.

Admin Configurations

Each slot should define:

- Slot Index
- Required Template ID
- Burn Required
- Active/Inactive

Future

Admin can add:

Slot 6
Slot 7
Slot 8

without code changes.

---

# 6. Land System

Players place lands inside slots.

Activation

Land NFT is burned.

The game stores:

- Land configuration
- Remaining durability
- Current state

Destroy Land

Player may destroy the active land.

Destroyed land does NOT return the NFT.

Durability

Example

```

Legendary Land

Durability:
1000 Mines

```

Every mining action decreases durability.

When durability reaches zero:

Land becomes unusable.

Unlimited Lands

Some lands are Free-to-Play.

Properties:

```

Unlimited Durability

```

Restrictions

Instead of durability they use RNG.

Example

Only Miner Type A
Only Miner Type B

Cannot mine using incompatible miners.

Matching Bonuses

Some lands provide bonus if miner matches.

Example

```

Land:
+20% reward

Only if Miner = Fire Miner

```

Admin Configuration

Every land should support:

- Template
- Rarity
- Durability
- Unlimited Flag
- Compatible Miners
- Mining Bonus
- NFT Drop Bonus
- FT Bonus
- Burn on Activation

---

# 7. Miner System

A Miner cannot mine without land.

Properties

- Health
- Max Health
- Base FT Reward
- Base NFT Chance
- Health Cost
- Compatible Boosters
- Compatible Lands

Mining

Each mining action

↓

Consumes health.

When health reaches zero

↓

Cannot mine.

Healing

Consumes FT currency.

Admin Configurations

- Max Health
- Base Reward
- Health Loss
- Compatible Lands
- Compatible Equipment

---

# 8. Equipment / Booster System

Boosters improve mining.

Activation

Equipment NFT is burned.

Player equips booster.

Game stores:

- Remaining durability
- Equipped state

Rules

Cannot unequip.

Durability decreases every mining action.

When durability reaches zero

↓

Equipment is destroyed.

Possible Bonuses

- FT Reward
- NFT Reward Chance
- Critical Chance
- Mining Speed
- Health Reduction

Admin Configurations

- Template
- Rarity
- Durability
- Compatible Miners
- Reward Modifiers

---

# 9. Mining System

Mining Flow

1. Player selects Slot.
2. Land is loaded.
3. Compatible miners shown.
4. Player selects miner.
5. Player equips booster.
6. Start Mining.
7. RNG executed.
8. Rewards distributed.
9. Durability reduced.
10. Health reduced.

Rewards

Two reward types.

Silver

↓

FT Token

Gold

↓

NFT Reward

NFT Animation

When NFT reward occurs

Display:

- Animation
or
- Video

Requirements

- Skippable
- Replayable in inventory

---

# 10. Mining Types

Current

Normal Mining

Future

Dangerous Mining

Dangerous Mining should NOT require contract redesign.

Mining Types should be configurable.

Example

```

Normal

```

Health Cost

Failure Chance

Success Reward

```

Dangerous

```

Health Cost

Failure Chance

Death Chance

Reward Multiplier

Penalty

Possible Outcomes

- Lose Health
- Lose Durability
- Lose Booster
- Lose Miner

Admin should be able to create additional mining types later.

---

# 11. Durability System

Objects using durability

- Lands
- Equipment

Future

Can also support:

- Miners
- Pets
- Vehicles

Durability decreases after successful mining.

Admin controls:

- Consumption Rate
- Repair Cost
- Maximum Durability

---

# 12. Health System

Only Miners use health.

Health Loss

Per mining attempt.

Healing

Consumes FT.

Admin Configurations

- Healing Cost
- Max Health
- Health Loss

---

# 13. Crafting (Smithy)

Players craft NFTs.

Inputs

- FT
- NFTs

Outputs

- New NFT

Examples

```

100 Silver

+

Iron

↓

Sword NFT

```

```

Legendary Fragment x5

↓

Legendary Booster

```

Recipes

Admin Configurable

Each recipe defines:

- Inputs
- Outputs
- Burn Inputs
- RNG Success
- Failure Chance

---

# 14. Admin Configuration System

Everything should be data-driven.

Admin Panel should configure:

## Slots

- Slot Index
- Unlock NFT
- Burn Rule

## Lands

- Durability
- Compatibility
- Bonuses
- Rarity

## Miners

- Health
- Rewards
- Compatible Lands

## Equipment

- Boost
- Durability
- Compatibility

## Mining Types

- Rewards
- Risks
- Failure
- Death Chance

## Craft Recipes

- Ingredients
- Outputs
- Burn Rules

## Currency

- FT Contract
- NFT Templates

## Referral

- Reward
- Cooldown
- Validation

No gameplay logic should require contract redeployment if only balancing values change.

---

# 15. Future Expansion

The architecture should support:

- New Slot Types
- New Lands
- New Mining Types
- PvP Mining
- Guild System
- Boss Mining
- Daily Quests
- Seasonal Events
- Achievement System
- Leaderboards
- Marketplace
- Rentals
- Land Upgrades
- Equipment Upgrades
- Staking Pools

without major contract redesign.

---

# 16. Smart Contract Modules

Suggested modules:

```

accounts

```

Player profile

```

slots

```

Slot management

```

lands

```

Land activation

```

miners

```

Miner state

```

equipment

```

Booster management

```

mining

```

Mining logic

```

rng

```

Randomness

```

crafting

```

Smithy

```

currencies

```

Reward configuration

```

admin

```

Game configuration

```

referrals

```

Referral rewards

---

# 17. Frontend Modules

Pages

- Login
- Dashboard
- Slots
- Lands
- Mining
- Inventory
- Smithy
- Marketplace
- Profile
- Leaderboard
- Referral

Components

- Slot Card
- Land Card
- Miner Card
- Booster Card
- Reward Popup
- NFT Animation
- Health Bar
- Durability Bar
- Crafting Window
- Mining Progress
- Inventory Grid

```

---

## Recommended next step

I would split this into a full **Game Design Document (GDD)** with separate Markdown files, for example:

```
docs/
│
├── 01-overview.md
├── 02-smart-contract-architecture.md
├── 03-database-tables.md
├── 04-admin-panel.md
├── 05-mining-engine.md
├── 06-rng-system.md
├── 07-crafting-system.md
├── 08-land-system.md
├── 09-miner-system.md
├── 10-slot-system.md
├── 11-equipment-system.md
├── 12-api-spec.md
├── 13-react-pages.md
├── 14-smart-contract-actions.md
├── 15-future-roadmap.md
```

This modular structure is much easier to maintain and use as the single source of truth while developing the WAX smart contracts and the React frontend.