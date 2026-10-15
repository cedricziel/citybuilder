## ADDED Requirements

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
