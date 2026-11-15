## ADDED Requirements

### Requirement: Saves before seeded maps are classic

A save SHALL store the world's terrain, size and island list, and loading SHALL never regenerate them. A save without map settings SHALL load as a classic map with no generation attempt, with its terrain exactly as saved. Adding the map settings SHALL NOT change the save version.

#### Scenario: Old save loads as classic

- **WHEN** a save written before map settings existed is loaded
- **THEN** the world records the classic style and no attempt, and its terrain, size and island list equal those in the file

#### Scenario: Loading does not regenerate a generated map

- **WHEN** a generated archipelago world is saved, its terrain is changed in the save file by one forest tile turned to grass, and the file is loaded
- **THEN** the loaded world has the edited tile as grass and every other tile as saved
