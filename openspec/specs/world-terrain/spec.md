# world-terrain Specification

## Purpose
TBD - created by archiving change add-mvp-foundation. Update Purpose after archive.

## Requirements
### Requirement: Fixed island map
The game SHALL provide one fixed island map for MVP. The map MUST be a rectangular tile grid of fixed dimensions chosen during design (target: at least 80×80 tiles), with deterministic terrain that is identical for every player and every save.

#### Scenario: Map is identical across launches
- **WHEN** the game launches a new game for any player
- **THEN** the island map's terrain layout is byte-for-byte identical to every other new game

#### Scenario: Map persists across save/load
- **WHEN** a save is loaded
- **THEN** the terrain of the island matches the terrain at the time the save was written

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
