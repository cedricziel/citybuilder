## ADDED Requirements

### Requirement: Buildings have an owner

Every building SHALL have an owner: the player or a rival. A building placed by a player command SHALL be the player's; a building placed by a `rivalPlace` command SHALL be that rival's. A building decoded without an owner SHALL be the player's.

#### Scenario: Player placement

- **WHEN** the player places a house on the home island
- **THEN** the house's owner is the player

#### Scenario: Rival placement

- **WHEN** a `rivalPlace` command for rival 2 places a farm on rival 2's island
- **THEN** the farm's owner is rival 2 and its $60 cost is deducted from rival 2's treasury, not the player's balance

### Requirement: Placement on another owner's island is rejected

Placement SHALL be rejected with `foreignIsland(owner)`, naming the island's owner, when any land tile of the footprint lies on an island owned by someone other than the placing owner. Water tiles of a shore building SHALL NOT be checked. Rival placements SHALL skip the research lock and the obsolete check; terrain, occupancy, shore and material checks SHALL apply to every owner.

#### Scenario: Player builds on a rival island

- **WHEN** the player asks whether a house can be placed on rival 1's island
- **THEN** the answer is rejected with `foreignIsland(rival 1)`

#### Scenario: Rival builds without research

- **WHEN** rival 1 asks whether a sawmill can be placed on a free grass slot of its own island, with enough materials, in a world where the player has researched nothing
- **THEN** the answer is allowed

### Requirement: Rival buildings are protected from the player

A player `demolish` command on a rival building SHALL be ignored, and a player `harvestForest` command on a rival island SHALL be ignored.

#### Scenario: Demolishing a rival house

- **WHEN** the player demolishes a tile of a rival house
- **THEN** the house still exists and the tick emits no `buildingDemolished`

#### Scenario: Clearing a rival forest

- **WHEN** the player harvests a forest tile on a rival island
- **THEN** the tile is still forest
