## ADDED Requirements

### Requirement: Saves carry house shortage counts

A save SHALL store, for each house, the consecutive consumption intervals it has been short of each good, in the order of the goods, so a game loaded mid-shortage resumes its grace where it stood. A save written before this field MUST load at the same save version, with a count of 1 for each good the house was already short of.

#### Scenario: Shortage counts survive a save
- **WHEN** a house short of tools for 2 intervals and of bread for 1 is saved and loaded
- **THEN** its counts are 2 for tools and 1 for bread

#### Scenario: An older save starts its grace on load
- **WHEN** a house saved before shortage counts, short of bread, is loaded
- **THEN** its count for bread is 1 and no other good has a count
