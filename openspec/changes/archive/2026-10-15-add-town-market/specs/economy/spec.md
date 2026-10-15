## ADDED Requirements

### Requirement: Market money is not tax or upkeep

Money paid or earned at the town center market SHALL change the player's balance when the trade is applied, outside the tax and upkeep figures. It SHALL NOT be reported in `taxesCollected` or `upkeepPaid`. A purchase SHALL move only the units the balance pays for, so a market trade never drives the balance below zero.

#### Scenario: Market sale is not tax
- **WHEN** on a tick that is also a tax interval, with no houses, the player sells 5 tools at the market
- **THEN** the balance rises by $75 and no `taxesCollected` event is emitted

#### Scenario: Buying never overdraws
- **WHEN** the player with $5 asks the market for wood
- **THEN** nothing is bought and the balance stays $5
