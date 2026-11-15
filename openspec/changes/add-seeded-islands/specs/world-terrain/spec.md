## MODIFIED Requirements

### Requirement: World layout
The game SHALL support one of two named world layouts: `single-island` (one contiguous landmass) or `archipelago` (multiple disjoint landmasses separated by water). Each new game SHALL also have map settings (see Requirement: Map settings) that choose either the `classic` map of that layout or a `generated` map. The layout and the map settings are fixed at new-game creation. The terrain MUST be deterministic given the layout, the map settings and the seed: two worlds created with the same three MUST have byte-identical terrain.

#### Scenario: Single-island layout deterministic per seed
- **WHEN** two `single-island` worlds are created with the same seed and the same map settings
- **THEN** their terrain layouts are byte-for-byte identical

#### Scenario: Archipelago layout deterministic per seed
- **WHEN** two `archipelago` worlds are created with the same seed and the same map settings
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

### Requirement: Map settings
A new game SHALL take map settings made of a style (`classic` or `generated`), a size (`small`, `medium` or `large`) and an island count. The classic style SHALL build today's maps with today's generators and SHALL ignore size and island count: a 96×96 single island that is the same for every seed, and the 300×300 archipelago of five fixed islands whose forest and mountain dots follow the seed. A new game created without map settings SHALL be classic. The generated style SHALL use these map sides:

| Layout | Small | Medium | Large |
|---|---|---|---|
| single-island | 80 | 96 | 128 |
| archipelago | 240 | 300 | 360 |

A generated single island SHALL have an island count of 1. A generated archipelago SHALL have an island count from 3 to 7. The world SHALL record the map settings it was asked for, and the generation attempt that passed, or none when the map is classic.

#### Scenario: A new game without map settings is classic
- **WHEN** a single-island game and an archipelago game are created with seed 0 and no map settings
- **THEN** their terrain hashes equal the hashes recorded from `main` before this change, and both record the classic style and no attempt

#### Scenario: Generated map sides follow the size
- **WHEN** generated games are created for each layout and each size with seed 3
- **THEN** each world's width and height equal the side in the table for its layout and size

#### Scenario: Map settings persist across save/load
- **WHEN** a generated archipelago world with Large size and 6 islands is saved and loaded
- **THEN** the loaded world records a generated style, Large size, 6 islands and the same attempt

### Requirement: Seeded island outlines
A generated island's outline SHALL come from the seed through integer value noise laid over an ellipse, using only integer arithmetic. World generation MUST NOT use floating-point numbers, platform random sources or unordered collection iteration to make a generated map, so macOS and Linux produce byte-equal terrain. After the raw outline, generation SHALL smooth it twice by 3×3 majority, remove one-tile spurs and fill one-tile notches, keep only the island's largest connected landmass and fill every lake, so each generated island is one landmass with no water inside it.

#### Scenario: Different seeds give different outlines
- **WHEN** generated single-island games with Medium size are created for seeds 1 and 2
- **THEN** their land masks (land or water per tile) differ

#### Scenario: Outlines are not ellipses
- **WHEN** generated single-island games with Medium size are created for seeds 0 to 19
- **THEN** each island's coast has at least one bay and one headland: walking 32 evenly spaced directions from the island's center, the farthest land tile on some direction is at least 1.25 times as far as on some other direction, after scaling by the ellipse's radii

#### Scenario: Generated islands have no lakes and no islets
- **WHEN** generated games are created for both layouts at Medium size with seeds 0 to 19
- **THEN** every water tile is connected to the map's edge by water, and the island list has as many entries as the requested island count

#### Scenario: Generated terrain is pinned
- **WHEN** a generated single-island game at Medium size and a generated archipelago game at Medium size with 5 islands are created for seed 1
- **THEN** their terrain hashes equal the pinned golden values

### Requirement: Seeded archipelago placement
A generated archipelago SHALL put its home island at the map's centre, so the map's centre tile is land on it, and SHALL place the other islands at seeded positions with seeded radii. Each island's land SHALL lie inside a disc of 1.25 times its larger radius. Discs SHALL be at least 10 tiles apart and at least 6 tiles from the map's 3-tile water border, so the sea between all islands is one connected body. When an island cannot be placed in 200 tries, that generation attempt SHALL fail.

#### Scenario: The home island covers the map's centre
- **WHEN** generated archipelago games are created for seeds 0 to 19 at every size and island count
- **THEN** the map's centre tile lies on an island, and the player's home town center stands on that island

#### Scenario: Island count follows the settings
- **WHEN** generated archipelago games at Medium size are created with 3, 4, 5, 6 and 7 islands for seed 8
- **THEN** each world's island list has exactly the requested number of islands

#### Scenario: The sea is one body
- **WHEN** generated archipelago games are created for seeds 0 to 19 at Medium size with 7 islands
- **THEN** all water tiles form one 4-connected component and every island has a water tile beside it

#### Scenario: Islands keep a channel between them
- **WHEN** generated archipelago games are created for seeds 0 to 19 at Small size with 7 islands
- **THEN** no land tile of one island lies within 10 tiles, Chebyshev distance, of a land tile of another island

### Requirement: Terrain on generated islands
Inside each generated island, land at most 2 tiles from water, by Chebyshev distance, SHALL be beach. Then, by counting rather than by threshold, the island's tiles at least 5 from water with the highest mountain noise SHALL become mountain, 8% of the island's land tiles, and of the remaining non-beach tiles those with the highest forest noise SHALL become forest, 22% of the island's land tiles. Ties go by `y`, then `x`. The rest SHALL be grass.

#### Scenario: Shares are counted
- **WHEN** a generated archipelago game at Medium size with 5 islands is created for seed 4, and its terrain is inspected before town centers, groves and mine sites are placed
- **THEN** on every island the mountain tiles are 8% of its land tiles, rounded down, or every tile at least 5 from water when there are fewer, and the forest tiles are 22%, rounded down

#### Scenario: Mountains stay inland
- **WHEN** the same generator terrain is inspected
- **THEN** no mountain tile lies within 4 tiles of water, and every land tile within 2 tiles of water is beach

### Requirement: Generated maps are validated
After world generation on a generated map, including town centers, starter groves, mine sites and rivals, the world SHALL be checked: the island list has the requested number of islands; in an archipelago the map's centre tile is land; every island has exactly one town center; every town center's start is fair (see Requirement: Fair start sites); every town center has a mine site at most 10 road tiles from its road ring (see Requirement: Starter mine site); every town center has a port site on its island within 40 tiles, Chebyshev distance, of its anchor, where a port could be placed once every tech is researched; and all water tiles form one connected sea. When a check fails, or the attempt failed while placing islands or shaping an outline, generation SHALL retry with the next attempt, whose noise seed is derived from the player's seed, the layout, the size, the island count and the attempt number. At most 8 attempts SHALL be made. When all 8 fail, the game SHALL use the classic map of that layout and record the generated settings with no attempt. The world's own seed SHALL stay the player's seed on every attempt.

#### Scenario: Generated maps keep fair starts across 200 seeds
- **WHEN** generated single-island games at Medium size and generated archipelago games at Medium size with 5 islands are created for seeds 0 to 199
- **THEN** every world passed on one of its 8 attempts, and for every town center, the player's and each rival's, the start is fair, a mine site lies at most 10 road tiles from its ring, a port site lies within 40 tiles of its anchor, and the sea is one connected body

#### Scenario: Every size and island count passes
- **WHEN** generated games are created for seeds 0 to 19 at every size, for the single island and for every archipelago island count from 3 to 7
- **THEN** no world falls back to the classic map

#### Scenario: A failing attempt retries with the next one
- **WHEN** the generator's first two attempts for a seed produce terrain that fails a check and the third passes
- **THEN** the world uses the third attempt's terrain and records attempt 2

#### Scenario: Eight failing attempts fall back to the classic map
- **WHEN** all 8 attempts for a generated archipelago game fail a check
- **THEN** the world's terrain is byte-identical to the classic archipelago for the same seed, and it records the generated settings with no attempt

#### Scenario: The validator catches an unfair start
- **WHEN** the validator checks a world whose only town center has 120 grass tiles in its start area
- **THEN** it reports an unfair start for that town center

#### Scenario: The validator catches a split sea
- **WHEN** the validator checks a world with a pond of water that no water path joins to the rest of the sea
- **THEN** it reports that the sea is not one body

#### Scenario: The validator catches a missing port site
- **WHEN** the validator checks a world whose island has no shore within 40 tiles of its town center
- **THEN** it reports a missing port site for that town center

#### Scenario: Fewer islands seat fewer rivals
- **WHEN** a generated archipelago game at Medium size with 3 islands is created at Hard
- **THEN** it has 2 rivals, one on each island other than home

#### Scenario: Generated starts do not depend on difficulty
- **WHEN** generated archipelago games with the same seed and map settings are created at Easy, Normal and Hard
- **THEN** their terrain is byte-identical, their town centers stand on the same anchors, and they record the same attempt

### Requirement: Island profile hook
World generation SHALL call one island-profile step after the island list is detected and before town centers are placed, on classic and generated maps alike. This change SHALL leave the step empty. A later change MAY use it to give islands resource profiles based on their climate, and MAY change terrain on an island there, but MUST NOT add or remove land. On a generated map the validation SHALL run after that step. Generated islands SHALL get their climate from the existing climate band rule.

#### Scenario: The empty profile step changes nothing
- **WHEN** a classic archipelago game is created for seed 0xC17B
- **THEN** its terrain hash and island list equal those recorded from `main` before this change

#### Scenario: Generated islands carry a climate
- **WHEN** a generated archipelago game at Medium size with 5 islands is created for seed 6
- **THEN** every island is temperate when its bounding box's centre lies in the north half of the map and tropical otherwise
