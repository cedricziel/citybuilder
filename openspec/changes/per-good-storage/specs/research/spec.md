## MODIFIED Requirements

### Requirement: Tech tree

The tech catalog SHALL define these techs:

| Tech | Cost | Requires | Unlocks |
|---|---|---|---|
| Scholarship | 30 | — | library |
| Milling | 720 | — | windmill |
| Mining | 720 | — | mine, charcoal burner |
| Metallurgy | 1,440 | Mining | smelter, toolsmith |
| Seafaring | 60 | — | port, shipyard |

A new game MUST start with Scholarship researched. Every building kind not listed MUST be available from the start.

#### Scenario: New game starts with Scholarship only

- **WHEN** a new game is created
- **THEN** Scholarship is researched and Milling, Mining, Metallurgy and Seafaring are not

### Requirement: Era techs need a thriving city

The era techs SHALL be Feudal Order (150, opens Medieval, needs 20 residents at citizens or above), Printing Press (4,500, needs Feudal Order, opens Renaissance, needs 20 merchants), Steam Power (400, needs Printing Press, opens Industrial, needs 40 merchants) and Electricity (600, needs Steam Power, opens Modern, needs 60 merchants). An era tech SHALL be choosable only when it opens the age right after the world's age and its residents condition holds when it is chosen.

#### Scenario: Era tech needs residents

- **WHEN** an Antiquity world with 19 citizens chooses Feudal Order
- **THEN** the choice is ignored

#### Scenario: Era tech with enough residents

- **WHEN** an Antiquity world with 20 citizens chooses Feudal Order
- **THEN** Feudal Order becomes the current research

#### Scenario: Era techs open one age at a time

- **WHEN** an Antiquity world with 20 merchants chooses Printing Press
- **THEN** the choice is ignored

### Requirement: Choosing research

The player SHALL choose the current research with a command. Only a tech that is not researched and whose prerequisites are researched MAY be chosen; other choices MUST be ignored. Accumulated knowledge flows into the current research; when its cost is reached the tech is researched, the current research is cleared and the surplus is kept as unspent knowledge.

#### Scenario: Research completes when its cost is reached

- **WHEN** the player of a Normal world chooses Milling and 720 knowledge points accumulate
- **THEN** Milling is researched and no research is current

#### Scenario: A tech with unmet prerequisites cannot be chosen

- **WHEN** the player chooses Metallurgy before Mining is researched
- **THEN** no research is current

### Requirement: Research cost scales with difficulty

A tech's research cost SHALL be its catalog cost times the difficulty's research percent, rounded down: 80% on Easy, 100% on Normal and 120% on Hard. Research completes when its progress reaches that scaled cost, and the research panel SHALL show the scaled cost.

#### Scenario: Easy research is cheaper

- **WHEN** an Easy world researches Milling
- **THEN** Milling is researched after 576 knowledge points

#### Scenario: Hard research is dearer

- **WHEN** a Hard world researches Milling
- **THEN** Milling is researched after 864 knowledge points and not after 863
