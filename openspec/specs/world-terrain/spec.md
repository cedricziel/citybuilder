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

### Requirement: Fair start sites

World generation SHALL place each island's town center on the nearest qualifying anchor to the island's centre target. The centre target SHALL be `(cx − 1, cy − 1)`, where `(cx, cy)` is the midpoint of the island's bounding box with integer division. Candidates SHALL be ordered by squared Euclidean distance to the target, then by `y`, then by `x`.

The **start area** of a town center with anchor `(ax, ay)` SHALL be the tiles from `(ax − 8, ay − 8)` to `(ax + 10, ay + 10)` that lie inside the map. An anchor SHALL qualify when every tile from `(ax − 1, ay − 1)` to `(ax + 3, ay + 3)` is unoccupied grass on that island, and its start area, counted as it would be after that anchor's starter grove is planted, holds at least 150 grass tiles and at most one quarter mountain tiles.

When no anchor qualifies, the town center SHALL go on the anchor, among those whose 5×5 square is unoccupied grass on the island, with the most grass tiles in its start area, ties broken by the candidate order. When no such anchor exists, it SHALL go on the first anchor in candidate order whose 3×3 footprint is unoccupied non-water land on the island. An island with no such anchor SHALL get no town center.

A town center's start is **fair** when, after world generation, its start area holds at least 150 grass tiles, at most one quarter mountain tiles, and a lumberjack hut site: a 2×2 anchor on unoccupied grass inside the start area whose catchment holds at least 12 unoccupied forest tiles.

#### Scenario: Single-island town center avoids the mountain core
- **WHEN** a new single-island game is created
- **THEN** every tile of the town center's footprint and of the ring around it is grass, and its start area holds at least 150 grass tiles and at most one quarter mountain tiles

#### Scenario: Town center takes the nearest qualifying site
- **WHEN** a new game is generated on an island whose centre target is surrounded by mountain and two qualifying anchors lie at squared distances 25 and 36 from it
- **THEN** the town center's anchor is the one at squared distance 25

#### Scenario: Ties between equally near sites go to the upper row
- **WHEN** two qualifying anchors lie at the same squared distance from the centre target, one with a smaller `y`
- **THEN** the town center's anchor is the one with the smaller `y`

#### Scenario: Fallback takes the grassiest all-grass site
- **WHEN** a new game is generated on an island where no anchor's start area holds 150 grass tiles, but some 5×5 squares are all grass
- **THEN** the town center stands on the 5×5 all-grass square whose start area holds the most grass

#### Scenario: Fallback without any all-grass square keeps the old rule
- **WHEN** a new game is generated on an island with no 5×5 square of grass but with free land for a 3×3 footprint
- **THEN** the island still gets a town center, on the first free 3×3 land anchor in candidate order

#### Scenario: Island too narrow for a town center gets none
- **WHEN** a new game is generated on an island 2 tiles wide and 5 tiles long
- **THEN** generation completes and the island has no town center

#### Scenario: Grass is counted after the grove is planted
- **WHEN** the anchor nearest the centre target has at least 150 grass tiles in its start area before its grove is planted but fewer after, and a farther anchor keeps at least 150 after its grove
- **THEN** the town center stands on the farther anchor

#### Scenario: Every start is fair across seeds
- **WHEN** a single-island game and archipelago games with seeds 0 to 49 at Easy, Normal and Hard are generated
- **THEN** every town center's start, the player's and each rival's, is fair, and no town center was placed by a fallback

### Requirement: Starter grove

After placing a town center, world generation SHALL plant a starter grove: the 6×6 square nearest the town center whose tiles are all grass or forest, all on the town center's island, and none inside the 5×5 square from `(ax − 1, ay − 1)` to `(ax + 3, ay + 3)`. Candidate squares SHALL be ordered by the squared Euclidean distance of their top-left corner to `(ax − 2, ay − 2)`, then by `y`, then by `x`, up to 12 tiles away on each axis. Every tile of the grove SHALL become forest except the 2×2 at offsets (2, 2) to (3, 3) from its top-left corner, which SHALL become grass. When no square qualifies, no grove SHALL be planted. The grove SHALL NOT change the island list.

#### Scenario: Grove gives a hut site with 32 trees
- **WHEN** a new archipelago game is created
- **THEN** next to every town center a lumberjack hut placed on the grove's clearing reaches 32 trees

#### Scenario: Grove stays off the town center ring
- **WHEN** a new game is created
- **THEN** no grove tile lies on the town center's footprint or on the ring of tiles touching it

#### Scenario: Grove leaves the island list unchanged
- **WHEN** an archipelago world's island list is compared with the islands detected from the generator's terrain before town centers and groves were placed
- **THEN** the two lists have the same IDs, tile counts and bounding boxes

#### Scenario: No room for a grove plants none
- **WHEN** a new game is generated on an island with no 6×6 square of grass or forest outside the town center's 5×5 square
- **THEN** the island's terrain is unchanged apart from the town center and its ring

### Requirement: Start placement independent of difficulty

Town center positions, starter groves and the resulting terrain SHALL depend only on the layout and the seed. Difficulty and whether rivals are enabled SHALL change only who owns each town center, never where it or its grove is.

#### Scenario: Difficulty does not move town centers
- **WHEN** archipelago games with the same seed are created at Easy, Normal and Hard
- **THEN** their terrain is byte-identical and their town centers stand on the same anchors

#### Scenario: Rivals get the same start rule as the player
- **WHEN** an archipelago game with rivals and one without rivals are created with the same seed
- **THEN** every rival town center in the first stands on the anchor of the town center on the same island in the second, and its start is fair

### Requirement: New game camera starts on the home town center

A new game's camera SHALL be centred on the middle of the player's home town center footprint: the player town center on the island under the map's centre tile, or the player town center with the lowest entity ID when that island has none. Without a player town center the camera SHALL stay at the map's centre.

#### Scenario: Camera starts on the player's town center
- **WHEN** a new single-island game or a new archipelago game is created
- **THEN** the camera's centre tile lies on the player's home town center footprint

### Requirement: Starter mine site

After placing each town center and its starter grove, world generation SHALL make sure the town center's island holds a mine site: a 2×2 square where the player could place a mine once Mining is researched. When the island holds none, one land tile SHALL become mountain. A mine site SHALL NOT overlap the town center's road ring, which the starter roads take later. The candidates are each grass or forest tile on the island, unoccupied and outside the town center's start area, that is the right, lower, left or upper neighbour of one of the island's mountain tiles. Grass candidates SHALL be tried before forest ones; within each, in order of the squared distance from the mountain tile to the town center's anchor, then by the mountain tile's `y`, then its `x`, then right, lower, left, upper. The first candidate that makes a mine site when it becomes mountain SHALL become mountain. An island that already holds a mine site, or has no candidate that makes one, SHALL keep its terrain. The raise SHALL NOT change the island list.

#### Scenario: Every town center's island has a mine site

- **WHEN** new games are created for archipelago and single-island seeds 0 to 49
- **THEN** the island of every town center, the player's and each rival's, holds a mine site for that town center's owner

#### Scenario: Only a missing mine site raises a tile

- **WHEN** the new game for archipelago seed 5, whose island 1 holds a player town center and mountains but no mine site, and the new game for archipelago seed 0, whose town-center islands all hold one, are created
- **THEN** exactly one tile of seed 5's island 1 became mountain, and seed 0's mountains are as world generation made them
