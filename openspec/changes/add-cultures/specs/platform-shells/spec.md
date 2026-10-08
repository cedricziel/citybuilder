## ADDED Requirements

### Requirement: New Game offers a culture

The New Game dialog SHALL let the player pick one of the four cultures, show a one-line description of the selected culture, default to Northern European, and create the world with the selected culture.

#### Scenario: Chosen culture reaches the world

- **WHEN** the player selects Middle Eastern and starts
- **THEN** the committed world's culture is Middle Eastern

#### Scenario: Cancel resets the culture

- **WHEN** the player selects East Asian and cancels
- **THEN** the dialog's culture is Northern European again

### Requirement: Inspector uses culture tier names

The inspector SHALL name a house's tier with the world culture's name for it.

#### Scenario: Mediterranean inspector

- **WHEN** the inspector shows a peasants-tier house in a Mediterranean world
- **THEN** its tier line reads "Tier: Plebeians"
