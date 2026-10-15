## MODIFIED Requirements

### Requirement: Rival build order

A rival SHALL build only houses, roads, lumberjack huts, foresters, sawmills, farms and warehouses. On its turn it SHALL take the first threshold rule that applies and that it can carry out, otherwise the next script step. The threshold rules, in order: food below 4 with fewer than (4 × houses + 4) / 5 farms → farm; once the opening is complete, planks below 6 with fewer sawmills than lumberjack huts → sawmill; wood below 4 with fewer than 1 + houses / 4 lumberjack huts, or less than 6 forest tiles left in the rival's hut catchments → lumberjack hut; fewer foresters than lumberjack huts, counting every hut → forester. Huts with fewer than 4 forest tiles left in their catchment SHALL not count as huts in these rules. The script SHALL be the opening (lumberjack hut, sawmill, farm, house, lumberjack hut, house, house, farm, house, house, lumberjack hut, warehouse) played once, then the growth loop (house, house, farm, house, house, lumberjack hut, house, sawmill) repeated. Stock SHALL be the rival's island stock. A step SHALL be issued only when the treasury covers the building cost, the road cost and $50, and the island stock covers the material cost or the rival's own huts (and, for planks, its sawmill) can still deliver the rest; otherwise the rival waits. While one of its sites waits for materials, a rival SHALL take no script step and only a lumberjack hut may join the waiting site. A rival's lumberjack hut and forester SHALL cost no materials. A script step waited on for 10 turns SHALL be skipped. House steps SHALL be skipped at 30 houses, and no step SHALL be taken at 50 non-road buildings.

#### Scenario: Opening step

- **WHEN** a fresh rival takes its first turn with 6 wood, 5 planks and 2 food
- **THEN** its commands end with a lumberjack hut placement and its script index becomes 1, although food is below 4 and there are no houses to feed

#### Scenario: Food threshold overrides the script

- **WHEN** a rival past its opening with 4 houses, 1 farm and 3 food in stock takes a turn while its script points at a house
- **THEN** it places a farm and its script index is unchanged

#### Scenario: Waiting for money

- **WHEN** a rival with $40 takes a turn on a house step
- **THEN** it issues no commands and its wait count goes up by 1

#### Scenario: Skipping a stuck step

- **WHEN** a rival has waited 10 turns on the same script step
- **THEN** its script index advances past that step and its wait count resets to 0

#### Scenario: House cap

- **WHEN** a rival with 30 houses reaches a house step
- **THEN** it skips the step and takes the next one

#### Scenario: Rival replants beside its hut

- **WHEN** a rival past its opening with 2 lumberjack huts, 1 forester, and enough food, planks and wood takes a turn while its script points at a house
- **THEN** it places a forester and its script index is unchanged

#### Scenario: Rival forester needs open ground beside a hut

- **WHEN** a rival with 1 lumberjack hut and no forester takes a turn, and no free slot's catchment shares at least 4 open grass tiles with the hut's catchment
- **THEN** it does not place a forester and takes its next script step instead

### Requirement: Rival town plan

A rival SHALL build on a road grid anchored to its town center: grid lines at `x ≡ ax − 1 (mod 5)` and `y ≡ ay − 1 (mod 5)` for town center anchor `(ax, ay)`, enclosing 4×4 blocks with four 2×2 corner slots each; a 3×3 building SHALL take a whole empty block. Blocks SHALL be searched by Chebyshev block distance from the town center's block up to 4, then row, then column, and only blocks sharing an edge with an opened block SHALL be opened. A lumberjack hut SHALL instead take the slot with the most forest tiles in its catchment (at least 6) among the blocks reachable through at most one unopened block, each opened block counting as 8 tiles less. A forester SHALL take the slot, among the same blocks and with the same block penalty, whose catchment holds the most open grass tiles that also lie in the catchment of one of the rival's lumberjack huts (at least 4); without such a slot the forester rule SHALL NOT apply. A step SHALL enqueue the missing ring roads of each block it opens (the town center's block first while it is unopened, then the blocks on the way to the chosen block), each ring in row-major order and each tile once, then the building. The town center's block has no free slot.

#### Scenario: First building opens the home block

- **WHEN** a fresh rival with town center anchor (ax, ay) places its first building
- **THEN** its commands start with the 20 road tiles of the ring from (ax − 1, ay − 1) to (ax + 4, ay + 4) in row-major order, end with the building, and the building lies in a block next to the town center's block

#### Scenario: Rival buildings touch a road

- **WHEN** a rival has played 20 steps
- **THEN** every rival building other than a road is adjacent to a rival road tile connected to its town center

#### Scenario: Rival forester overlaps a hut

- **WHEN** a rival places a forester
- **THEN** at least 4 open grass tiles lie in both the forester's catchment and the catchment of one of the rival's lumberjack huts
