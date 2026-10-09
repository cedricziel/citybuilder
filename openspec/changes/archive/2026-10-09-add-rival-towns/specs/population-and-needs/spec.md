## ADDED Requirements

### Requirement: Player totals exclude rival houses

The city's total population, the residents counted for era research gates and the residents counted for goals SHALL include only player-owned houses.

#### Scenario: Total population

- **WHEN** player houses hold 30 residents and rival houses hold 50
- **THEN** the snapshot's total population is 30

#### Scenario: Era gate ignores rivals

- **WHEN** the player has 10 citizens' residents and a rival has 30 in the Antiquity age
- **THEN** Feudal Order (20 citizens) cannot be chosen
