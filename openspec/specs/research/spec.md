# research Specification

## Purpose
Knowledge accumulates over time and unlocks buildings through a small tech tree, giving the city a sense of development.
## Requirements
### Requirement: Knowledge accumulates

The world SHALL track a knowledge total. Each tick, every operational library MUST add 1 point every 10 ticks, and every citizen or merchant resident MUST add 1 point every 100 ticks.

#### Scenario: A library produces knowledge

- **WHEN** one operational library exists and 100 ticks pass with no citizens or merchants
- **THEN** 10 knowledge points have accumulated

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

### Requirement: Choosing research

The player SHALL choose the current research with a command. Only a tech that is not researched and whose prerequisites are researched MAY be chosen; other choices MUST be ignored. Accumulated knowledge flows into the current research; when its cost is reached the tech is researched, the current research is cleared and the surplus is kept as unspent knowledge.

#### Scenario: Research completes when its cost is reached

- **WHEN** the player chooses Milling and 40 knowledge points accumulate
- **THEN** Milling is researched and no research is current

#### Scenario: A tech with unmet prerequisites cannot be chosen

- **WHEN** the player chooses Metallurgy before Mining is researched
- **THEN** no research is current

### Requirement: Locked buildings cannot be placed

Placement of a building whose unlocking tech is not researched SHALL be rejected with reason `locked(tech)`.

#### Scenario: Mine is locked before Mining

- **WHEN** the player tries to place a mine on mountain ground before Mining is researched
- **THEN** placement is rejected with `locked(.mining)`

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
