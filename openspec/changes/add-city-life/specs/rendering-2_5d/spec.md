## ADDED Requirements

### Requirement: Night falls on the scene

The scene SHALL darken by the time of day's darkness, and inhabited houses SHALL show lit windows whose brightness follows the darkness.

#### Scenario: Night overlay

- **WHEN** the scene renders a snapshot at tick 780
- **THEN** its night overlay has alpha 0.55

### Requirement: Residents stroll the streets

During day and dusk, each inhabited house with an adjacent road SHALL show up to three strollers (one per three residents) walking the nearby roads, and none at night. Stroller positions SHALL be a pure function of house, slot and tick.

#### Scenario: Strollers by day

- **WHEN** a house with 9 residents next to a road is planned at midday
- **THEN** there are 3 strollers for it

#### Scenario: No strollers at night

- **WHEN** the same house is planned at midnight
- **THEN** there are no strollers for it
