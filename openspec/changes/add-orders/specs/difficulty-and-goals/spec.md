## ADDED Requirements

### Requirement: Orders goal

A scenario SHALL be able to use the goal "fulfil N orders", met when the player has fulfilled at least N orders since the game started, from any issuer. The count SHALL be part of the world state and SHALL survive a save and load. The goal SHALL be checked on the goal interval like the others.

#### Scenario: Orders goal counts fulfilled orders

- **WHEN** a scenario has the goal "fulfil 2 orders" and the player fulfils one crown order and one rival order
- **THEN** the progress reads 2 of 2 and the goal is met at the next goal check

#### Scenario: Failed orders do not count

- **WHEN** the player has fulfilled 1 order and failed 2
- **THEN** the progress toward "fulfil 3 orders" reads 1 of 3
