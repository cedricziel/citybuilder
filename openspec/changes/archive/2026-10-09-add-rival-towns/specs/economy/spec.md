## ADDED Requirements

### Requirement: Each owner has its own purse

Tax and upkeep SHALL be booked to the owner of the house or building: the player's balance or the rival's treasury. Difficulty upkeep scaling SHALL apply to the player only. The `taxesCollected` and `upkeepPaid` events SHALL report the player's amounts only, and SHALL NOT be emitted when the player's amount is zero.

#### Scenario: Upkeep split by owner

- **WHEN** upkeep is due on Hard while the player has two operational sawmills (upkeep 2 each) and rival 1 has two
- **THEN** the player's balance drops by $5, rival 1's treasury drops by $4, and `upkeepPaid` reports 5

#### Scenario: Only rivals earn tax

- **WHEN** taxes are collected and only rival houses have residents
- **THEN** the player's balance is unchanged and no `taxesCollected` event is emitted
