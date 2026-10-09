## ADDED Requirements

### Requirement: Town center starter road

World generation SHALL ring every town center the player owns with road on each non-water, unoccupied tile that touches its footprint, including the corners. The starter road SHALL be free. Rival town centers SHALL NOT get a starter road.

#### Scenario: Fresh-world town center starts ringed by road
- **WHEN** a new single-island game is created
- **THEN** every non-water tile around the town center's footprint holds a player road and the town center is road-connected

#### Scenario: The starter road is free
- **WHEN** a new Normal game is created
- **THEN** the balance equals Normal's starting balance

#### Scenario: Rival town centers get no starter road
- **WHEN** a new archipelago game with rivals is created
- **THEN** no tile around a rival's town center holds road
