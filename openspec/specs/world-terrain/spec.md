# world-terrain Specification

## Purpose
TBD - created by archiving change add-mvp-foundation. Update Purpose after archive.
## Requirements
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

### Requirement: Terrain types
The system SHALL classify every tile into exactly one terrain type from: `grass`, `forest`, `beach`, `water`, `mountain`. Each terrain type MUST have stable, documented build-eligibility rules.

#### Scenario: Tile has exactly one terrain type
- **WHEN** the simulation inspects any tile coordinate inside the map bounds
- **THEN** the terrain type returned is exactly one of grass, forest, beach, water, or mountain

#### Scenario: Forest tile can be cleared
- **WHEN** a forest tile is harvested by a lumberjack
- **THEN** its terrain type becomes `grass` and re-grows over a configured number of ticks

### Requirement: Build eligibility
The system SHALL provide a query `canPlace(building, at: tile)` that returns whether a given building may be placed on a given tile based on terrain type, occupancy, and adjacency rules.

#### Scenario: Cannot build on water
- **WHEN** the player attempts to place any land building on a water tile
- **THEN** `canPlace` returns false and the placement is rejected with a reason code `terrain_not_buildable`

#### Scenario: Cannot build on occupied tile
- **WHEN** the player attempts to place a building whose footprint overlaps an existing building
- **THEN** `canPlace` returns false with reason code `tile_occupied`

### Requirement: Coordinate system
The terrain SHALL expose tile coordinates as integer `(x, y)` pairs in a single canonical grid. Iso projection is a rendering-layer concern and MUST NOT leak into terrain logic.

#### Scenario: Coordinates are integer
- **WHEN** any subsystem queries a tile by coordinate
- **THEN** the coordinate is an integer pair, never a float

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

### Requirement: Island name metadata

Every `Island` in the world SHALL carry a `name: String` derived deterministically at world-gen from a seeded pick over a constant 64-entry name table indexed by the island's center tile coordinate and the world seed. The same `(seed, layout)` MUST produce the same set of names assigned to islands in the same order. Names MUST persist across save/load via the existing Codable conformance.

#### Scenario: Island name is deterministic per seed

- **WHEN** two `archipelago` worlds are generated with the same seed
- **THEN** their island lists contain the same names in the same `IslandID` order

#### Scenario: Same name persists across save/load

- **WHEN** a world is saved and loaded
- **THEN** every `Island.name` in the loaded world equals the name at save time

#### Scenario: Different seeds yield different name distributions

- **WHEN** two worlds are generated with different seeds (same `archipelago` layout)
- **THEN** their island-name lists are not element-wise equal (across the 64-entry pool the collision probability is negligible for the 1–8 islands a typical archipelago produces)

#### Scenario: Single-island world has a single name

- **WHEN** a `single-island` world is generated
- **THEN** its one island carries a deterministic name from the same table
