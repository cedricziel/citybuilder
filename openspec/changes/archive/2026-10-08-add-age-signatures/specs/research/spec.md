## ADDED Requirements

### Requirement: Era techs unlock signature buildings

Feudal Order SHALL unlock the guild hall, Printing Press the gallery, Steam Power the steam engine and Electricity the power plant. The monument SHALL need no tech.

#### Scenario: Gallery locked before Printing Press

- **WHEN** a Medieval world places a gallery before Printing Press is researched
- **THEN** the placement is rejected as locked by Printing Press

#### Scenario: Era tech unlock lists

- **WHEN** the unlock lists of the era techs are read
- **THEN** Feudal Order unlocks the guild hall, Printing Press the gallery, Steam Power the steam engine and Electricity the power plant
