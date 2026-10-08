# cultures Specification

## Purpose
TBD - created by archiving change add-cultures. Update Purpose after archive.
## Requirements
### Requirement: The world has a culture

The world SHALL store one culture for the whole game, chosen when the game is created, from Northern European, Mediterranean, East Asian and Middle Eastern. A world created without a choice SHALL be Northern European.

#### Scenario: New game uses the chosen culture

- **WHEN** a new game is created with the East Asian culture
- **THEN** the world's culture is East Asian

#### Scenario: Default culture is Northern European

- **WHEN** a new game is created without a culture
- **THEN** the world's culture is Northern European

#### Scenario: Snapshot carries the culture

- **WHEN** a snapshot is taken of a Mediterranean world
- **THEN** the snapshot's culture is Mediterranean

### Requirement: Tiers are named by culture

Each culture SHALL name the three resident tiers: Northern European peasants, citizens and merchants; Mediterranean plebeians, citizens and patricians; East Asian farmers, artisans and scholars; Middle Eastern farmers, craftsmen and merchants.

#### Scenario: Mediterranean top tier

- **WHEN** the merchants tier is named in the Mediterranean culture
- **THEN** its name is "Patricians"

#### Scenario: Northern European names are unchanged

- **WHEN** each tier is named in the Northern European culture
- **THEN** the names are "Peasants", "Citizens" and "Merchants"
