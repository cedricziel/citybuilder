## MODIFIED Requirements

### Requirement: Tech tree

The tech catalog SHALL define these techs:

| Tech | Cost | Requires | Unlocks |
|---|---|---|---|
| Scholarship | 30 | — | library |
| Milling | 40 | — | windmill |
| Mining | 40 | — | mine, charcoal burner |
| Metallurgy | 80 | Mining | smelter, toolsmith |
| Seafaring | 60 | — | port, shipyard |

A new game MUST start with Scholarship researched. Every building kind not listed MUST be available from the start.

#### Scenario: New game starts with Scholarship only

- **WHEN** a new game is created
- **THEN** Scholarship is researched and Milling, Mining, Metallurgy and Seafaring are not

## ADDED Requirements

### Requirement: Techs belong to ages

Scholarship SHALL belong to Antiquity, and Milling, Mining, Metallurgy and Seafaring to the Medieval age. A tech SHALL be choosable only when its age is at or before the world's age.

#### Scenario: Milling waits for the Medieval age

- **WHEN** an Antiquity world chooses Milling
- **THEN** the choice is ignored

### Requirement: Era techs need a thriving city

The era techs SHALL be Feudal Order (150, opens Medieval, needs 20 residents at citizens or above), Printing Press (250, needs Feudal Order, opens Renaissance, needs 20 merchants), Steam Power (400, needs Printing Press, opens Industrial, needs 40 merchants) and Electricity (600, needs Steam Power, opens Modern, needs 60 merchants). An era tech SHALL be choosable only when it opens the age right after the world's age and its residents condition holds when it is chosen.

#### Scenario: Era tech needs residents

- **WHEN** an Antiquity world with 19 citizens chooses Feudal Order
- **THEN** the choice is ignored

#### Scenario: Era tech with enough residents

- **WHEN** an Antiquity world with 20 citizens chooses Feudal Order
- **THEN** Feudal Order becomes the current research

#### Scenario: Era techs open one age at a time

- **WHEN** an Antiquity world with 20 merchants chooses Printing Press
- **THEN** the choice is ignored
