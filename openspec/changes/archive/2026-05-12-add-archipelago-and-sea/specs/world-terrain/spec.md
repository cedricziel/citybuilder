## MODIFIED Requirements

### Requirement: World layout
The game SHALL support one of two named world layouts: `single-island` (the MVP layout, target ≥80×80 tiles, one contiguous landmass) or `archipelago` (target ~300×300 tiles, multiple disjoint landmasses separated by water). The layout choice is fixed at new-game creation. For each layout the terrain MUST be deterministic given the (layout, seed) pair: two worlds created with the same layout and same seed MUST have byte-identical terrain.

#### Scenario: Single-island layout deterministic per seed
- **WHEN** two `single-island` worlds are created with the same seed
- **THEN** their terrain layouts are byte-for-byte identical

#### Scenario: Archipelago layout deterministic per seed
- **WHEN** two `archipelago` worlds are created with the same seed
- **THEN** their terrain layouts are byte-for-byte identical

#### Scenario: Different layouts diverge under the same seed
- **WHEN** a `single-island` world and an `archipelago` world are both created with the same seed
- **THEN** their terrain layouts differ (no requirement of overlap)

#### Scenario: Map persists across save/load
- **WHEN** a save is loaded
- **THEN** the terrain of the world matches the terrain at the time the save was written

#### Scenario: Layout choice persists across save/load
- **WHEN** a save is loaded
- **THEN** the world's `layout` field matches the value at the time the save was written

## ADDED Requirements

### Requirement: Island metadata
The world SHALL expose a derived list of `Island` records, one per maximal connected component of non-water buildable tiles. Each `Island` MUST have a stable `IslandID` assigned at world-gen time, a bounding-box, and a tile-count. The `Island` list MUST be recomputed only when terrain changes (initial gen, forest harvest, future terraforming) and otherwise cached.

#### Scenario: Single-island layout produces exactly one island
- **WHEN** the island list of a `single-island` world is queried
- **THEN** the list contains exactly one entry whose tile-count equals the count of non-water buildable tiles in the world

#### Scenario: Archipelago layout produces multiple islands
- **WHEN** the island list of an `archipelago` world is queried
- **THEN** the list contains two or more entries and each entry's tile-count is greater than zero

#### Scenario: IslandID stable across save/load
- **WHEN** a world is saved and loaded
- **THEN** the loaded world's island list has identical `IslandID` values to the saved world

### Requirement: Climate band metadata
Each `Island` SHALL carry a climate band attribute derived deterministically from world-gen (default rule: north half of the map → `temperate`, south half → `tropical`). The climate value MUST be `Codable` and MUST persist with the world. No gameplay rule in this change SHALL gate behavior on climate; the field exists for use by the follow-up `add-island-specialization` change.

#### Scenario: Every island has a climate
- **WHEN** the island list is queried
- **THEN** every `Island` entry has a non-nil `climate` value drawn from the declared enum

#### Scenario: Climate persists across save/load
- **WHEN** a world is saved and loaded
- **THEN** every island's `climate` value in the loaded world equals the value in the saved world
