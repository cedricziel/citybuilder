## ADDED Requirements

### Requirement: Starter mine site

After placing each town center and its starter grove, world generation SHALL make sure the town center's island holds a mine site: a 2×2 square where the player could place a mine once Mining is researched. When the island holds none, one land tile SHALL become mountain. The candidates are each grass or forest tile on the island, unoccupied and outside the town center's start area, that is the right, lower, left or upper neighbour of one of the island's mountain tiles. They SHALL be tried in order of the squared distance from that mountain tile to the town center's anchor, then by the mountain tile's `y`, then its `x`, then right, lower, left, upper. The first candidate that makes a mine site when it becomes mountain SHALL become mountain. An island that already holds a mine site, or has no candidate that makes one, SHALL keep its terrain. The raise SHALL NOT change the island list.

#### Scenario: Every home island has a mine site

- **WHEN** new games are created for archipelago and single-island seeds 0 to 49
- **THEN** the player's island holds a mine site in each

#### Scenario: Only a missing mine site raises a tile

- **WHEN** the new game for archipelago seed 5, whose home island has mountains but no mine site, and the new game for archipelago seed 0, whose home island has one, are created
- **THEN** exactly one tile of seed 5's home island became mountain, and seed 0's terrain is as world generation made it
