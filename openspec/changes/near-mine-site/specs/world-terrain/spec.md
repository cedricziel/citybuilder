## MODIFIED Requirements

### Requirement: Starter mine site

After placing each town center and its starter grove, world generation SHALL make sure a mine site lies near the town center wherever a near outcrop fits: a 2×2 square where the player could place a mine once Mining is researched, whose side touches a tile at most 10 road tiles from the town center's road ring. Road tiles are counted by land steps on the town center's island over tiles no building occupies, from the ring tiles (0) outward; forest and mountain may be crossed. A mine site SHALL NOT overlap the town center's road ring, which the starter roads take later.

When no such site exists, world generation SHALL raise a near outcrop: the nine tiles of the first 3×3 square, among those whose tiles are all unoccupied grass on the island, outside the town center's start area and off its road ring, and whose side touches a tile at most 10 road tiles from the ring, ordered by that road distance, then by the square's `y`, then its `x`, that holds a mine site once its tiles are mountain, SHALL become mountain. A 3×3 keeps rock in its middle; a 2×2 would be all edge. When no grass square qualifies, squares of grass and forest SHALL be tried the same way.

When no near outcrop fits, the town center MAY keep a mine site farther than 10 road tiles: the near-site guarantee then does not hold, and the island-wide rule below applies instead. When no near outcrop fits and the island holds no mine site at all, one land tile SHALL become mountain. The candidates are each grass or forest tile on the island, unoccupied and outside the town center's start area, that is the right, lower, left or upper neighbour of one of the island's mountain tiles. Grass candidates SHALL be tried before forest ones; within each, in order of the squared distance from the mountain tile to the town center's anchor, then by the mountain tile's `y`, then its `x`, then right, lower, left, upper. The first candidate that makes a mine site when it becomes mountain SHALL become mountain. An island that still has no candidate that makes one SHALL keep its terrain. No raise SHALL change the island list.

#### Scenario: Every town center's island has a mine site

- **WHEN** new games are created for archipelago and single-island seeds 0 to 49
- **THEN** the island of every town center, the player's and each rival's, holds a mine site for that town center's owner

#### Scenario: A mine site lies near every town center

- **WHEN** new games without rivals are created for archipelago and single-island seeds 0 to 29, so every town center stays as generation left it
- **THEN** every town center, on the home island and every other, has a mine site at most 10 road tiles from its road ring

#### Scenario: A far mine site raises a near outcrop

- **WHEN** the new game for archipelago seed 1 is created, whose home island's nearest mine site lies 23 road tiles from the ring
- **THEN** exactly nine tiles of the home island became mountain, forming a 3×3 square, and a mine site lies 6 road tiles from the ring

#### Scenario: Only a missing mine site raises a tile

- **WHEN** the new game for archipelago seed 9 is created, whose home town center has a mine site 1 road tile from the ring
- **THEN** no tile of the home island became mountain; a near mine site raises nothing

#### Scenario: The outcrop takes the nearest grass square outside the start area

- **WHEN** a mine site is made for a town center at (2, 2) on a 30 by 30 grass island with no mountain
- **THEN** the square from (13, 0) to (15, 2) becomes mountain, and no other tile does
