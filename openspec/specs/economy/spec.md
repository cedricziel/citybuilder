# economy Specification

## Purpose
TBD - created by archiving change add-mvp-foundation. Update Purpose after archive.
## Requirements
### Requirement: Single-currency money balance
The player SHALL have one money balance represented as a 64-bit signed integer. All in-game currency operations MUST update this single balance.

#### Scenario: Balance survives save/load
- **WHEN** a save is written with balance B and then loaded
- **THEN** the loaded balance equals B exactly

### Requirement: Starting balance
A new game SHALL begin with a configured starting balance (target: enough for ~5 initial buildings). The starting balance MUST be deterministic.

#### Scenario: New game starting balance
- **WHEN** a new game is created
- **THEN** the money balance equals the configured starting value

### Requirement: Build costs deducted at placement
Placing a building SHALL deduct its full construction cost from the money balance at the moment of placement. Construction cost MUST NOT be refunded automatically on completion.

#### Scenario: Money deducted at placement
- **WHEN** a player places a building costing 200 with balance 1000
- **THEN** the balance immediately becomes 800

### Requirement: Tax income credited per interval
Tax income from populated houses SHALL be credited to the balance at each configured tax interval, integer-summed across all houses.

#### Scenario: Tax credited each interval
- **WHEN** the tax interval elapses
- **THEN** the balance increases by the sum of every house's tax contribution that tick

### Requirement: Upkeep costs
Buildings MAY declare a recurring upkeep cost in money units per tick interval. Upkeep MUST be deducted from the balance regardless of whether the balance is positive.

#### Scenario: Upkeep allowed to drive negative
- **WHEN** upkeep is due and the current balance is below the upkeep amount
- **THEN** the balance becomes negative by the deficit

### Requirement: Bankruptcy condition
The simulation SHALL detect bankruptcy when the money balance remains at or below a configurable threshold (default: less than zero) for a configurable grace period. Bankruptcy MUST surface a game-over state but MUST NOT auto-delete the save.

#### Scenario: Persistent deficit triggers bankruptcy
- **WHEN** the balance stays below zero for the grace period
- **THEN** the simulation enters game-over state and the UI surfaces a bankruptcy banner

#### Scenario: Recovery cancels bankruptcy timer
- **WHEN** the balance returns to or above zero before the grace period ends
- **THEN** the bankruptcy timer resets

### Requirement: Money UI surface
The HUD SHALL display the current money balance at all times during gameplay. The displayed value MUST stay within one frame of the simulation's current balance.

#### Scenario: HUD reflects balance change
- **WHEN** the balance changes by any amount
- **THEN** the HUD value updates within one render frame

### Requirement: Signature buildings pay upkeep like other buildings

The five age signature buildings SHALL pay their catalog upkeep each upkeep interval while operational, scaled by difficulty, whether or not they are fuelled or commissioned. A gallery commission SHALL be paid once, when it starts.

#### Scenario: Cold power plant still costs upkeep

- **WHEN** one upkeep interval passes on Normal with only an unfuelled power plant operational
- **THEN** the money balance decreases by 6

### Requirement: Forum bonus counts as tax

The forum's extra tax SHALL be part of the owner's house tax: it SHALL be reported in `taxesCollected` and SHALL be raised by a completed monument's bonus like the rest of the tax.

#### Scenario: Forum and monument

- **WHEN** one tax interval passes with a completed monument and a single merchant house of 8 residents within 8 tiles of a served forum
- **THEN** the tax collected is 52

### Requirement: Caravan income

Caravan revenue SHALL be credited to the caravanserai owner's balance when the caravan leaves, outside the tax and upkeep intervals' figures.

#### Scenario: Caravan income is not tax

- **WHEN** on Normal, with an unserved caravanserai as the only building and no houses, a caravan sells 4 bread on a tick that is also a tax and upkeep interval
- **THEN** the balance rises by 46 (48 revenue minus 2 upkeep) and no `taxesCollected` event is emitted

### Requirement: Each owner has its own purse

Tax and upkeep SHALL be booked to the owner of the house or building: the player's balance or the rival's treasury. Difficulty upkeep scaling SHALL apply to the player only. The `taxesCollected` and `upkeepPaid` events SHALL report the player's amounts only, and SHALL NOT be emitted when the player's amount is zero.

#### Scenario: Upkeep split by owner

- **WHEN** upkeep is due on Hard while the player has two operational sawmills (upkeep 2 each) and rival 1 has two
- **THEN** the player's balance drops by $5, rival 1's treasury drops by $4, and `upkeepPaid` reports 5

#### Scenario: Only rivals earn tax

- **WHEN** taxes are collected and only rival houses have residents
- **THEN** the player's balance is unchanged and no `taxesCollected` event is emitted
