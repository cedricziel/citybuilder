## ADDED Requirements

### Requirement: New Game offers a starting age

The New Game dialog SHALL let the player pick one of the five ages, default to Medieval, reset to Medieval on cancel, and create the world in the selected age.

#### Scenario: Chosen age reaches the world

- **WHEN** the player selects Industrial and starts
- **THEN** the committed world's age is Industrial

### Requirement: Age changes show a banner

When the age advances, the game screen SHALL show a banner titled "The <Age> age begins" for 60 ticks.

#### Scenario: Medieval banner

- **WHEN** a tick emits `ageAdvanced(medieval)`
- **THEN** the session's banner title is "The Medieval age begins"

### Requirement: Palette hides obsolete buildings

The build palette SHALL leave out building kinds that are obsolete in the world.

#### Scenario: Quern house leaves the palette

- **WHEN** Milling is researched
- **THEN** the palette has no quern house entry
