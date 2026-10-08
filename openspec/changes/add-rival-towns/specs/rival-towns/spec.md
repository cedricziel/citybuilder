## ADDED Requirements

### Requirement: Rivals in archipelago games

A new archipelago game with rivals enabled (the default) SHALL have 1 rival town on Easy, 2 on Normal and 3 on Hard. The player's home island SHALL be the island containing the map center tile. Rival islands SHALL be the other islands in descending tile count, ties by lower island ID, assigned to rivals 1, 2 and 3 in that order. Islands without a rival SHALL stay the player's with their seeded town center. A single-island game, or a game with rivals disabled, SHALL have no rivals.

#### Scenario: Hard archipelago seats three rivals

- **WHEN** a new archipelago game is created on Hard
- **THEN** it has rivals 1, 2 and 3 on islands 5, 2 and 1, and islands 3 and 4 belong to the player

#### Scenario: Easy archipelago seats one rival

- **WHEN** a new archipelago game is created on Easy
- **THEN** it has one rival, on island 5

#### Scenario: Single island has no rivals

- **WHEN** a new single-island game is created on Hard
- **THEN** it has no rivals

#### Scenario: Rivals turned off

- **WHEN** a new archipelago game is created on Normal with rivals disabled
- **THEN** it has no rivals and the player owns all five islands

### Requirement: Rival identity

Each rival SHALL have the name of its island, a colour (rival 1 crimson, rival 2 azure, rival 3 emerald), a culture, a treasury and an age. Rival cultures SHALL be the cultures other than the player's in catalog order. The starting treasury SHALL be $600 on Easy, $1,000 on Normal and $1,400 on Hard. A rival SHALL start in the world's start age and own the town center seeded on its island, with the difficulty's starter stock.

#### Scenario: Rival cultures differ from the player's

- **WHEN** a Northern European archipelago game is created on Hard
- **THEN** rivals 1, 2 and 3 are Mediterranean, East Asian and Middle Eastern

#### Scenario: Rival starting state

- **WHEN** a Medieval archipelago game is created on Hard
- **THEN** rival 1 is named after island 5, is crimson, has $1,400, is in the Medieval age, and the town center on island 5 is owned by rival 1 and holds 4 wood, 3 planks and 1 food

### Requirement: Rival turns go through the command queue

On a rival's turn (every 80 ticks on Easy, 50 on Normal, 30 on Hard, on ticks where `tickCount % interval == rivalID − 1`), the rival AI SHALL decide at most one step and append its commands to the pending command queue as `rivalPlace` commands, to be applied at the next tick boundary with the rival as owner. A rival turn SHALL NOT draw from the world RNG. A rejected `rivalPlace` SHALL emit no event.

#### Scenario: Commands apply on the next tick

- **WHEN** rival 1 takes its first turn on Normal at tick 50
- **THEN** after tick 50 the pending queue holds its `rivalPlace` commands, and after tick 51 the lumberjack hut they place exists and is owned by rival 1

#### Scenario: Turn leaves the RNG alone

- **WHEN** a rival takes a turn
- **THEN** the world's RNG state is the same before and after the rival system runs

#### Scenario: Rejected rival command is silent

- **WHEN** a `rivalPlace` command is applied on an occupied tile
- **THEN** no building is placed and the tick's events contain no `placementRejected`

### Requirement: Rival build order

A rival SHALL build only houses, roads, lumberjack huts, sawmills, farms and warehouses. On its turn it SHALL take the first threshold rule that applies and that it can carry out, otherwise the next script step. The threshold rules, in order: food below 4 with fewer than (4 × houses + 4) / 5 farms → farm; once the opening is complete, planks below 6 with fewer sawmills than lumberjack huts → sawmill; wood below 4 with fewer than 1 + houses / 4 lumberjack huts, or less than 6 forest tiles left in the rival's hut catchments → lumberjack hut. Huts with fewer than 4 forest tiles left in their catchment SHALL not count as huts in these rules. The script SHALL be the opening (lumberjack hut, sawmill, farm, house, lumberjack hut, house, house, farm, house, house, lumberjack hut, warehouse) played once, then the growth loop (house, house, farm, house, house, lumberjack hut, house, sawmill) repeated. Stock SHALL be the rival's island stock. A step SHALL be issued only when the treasury covers the building cost, the road cost and $50, and the island stock covers the material cost or the rival's own huts (and, for planks, its sawmill) can still deliver the rest; otherwise the rival waits. While one of its sites waits for materials, a rival SHALL take no script step and only a lumberjack hut may join the waiting site. A rival's lumberjack hut SHALL cost no materials. A script step waited on for 10 turns SHALL be skipped. House steps SHALL be skipped at 30 houses, and no step SHALL be taken at 50 non-road buildings.

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

### Requirement: Rival town plan

A rival SHALL build on a road grid anchored to its town center: grid lines at `x ≡ ax − 1 (mod 5)` and `y ≡ ay − 1 (mod 5)` for town center anchor `(ax, ay)`, enclosing 4×4 blocks with four 2×2 corner slots each; a 3×3 building SHALL take a whole empty block. Blocks SHALL be searched by Chebyshev block distance from the town center's block up to 4, then row, then column, and only blocks sharing an edge with an opened block SHALL be opened. A lumberjack hut SHALL instead take the slot with the most forest tiles in its catchment (at least 6) among the blocks reachable through at most one unopened block, each opened block counting as 8 tiles less. A step SHALL enqueue the missing ring roads of each block it opens (the town center's block first while it is unopened, then the blocks on the way to the chosen block), each ring in row-major order and each tile once, then the building. The town center's block has no free slot.

#### Scenario: First building opens the home block

- **WHEN** a fresh rival with town center anchor (ax, ay) places its first building
- **THEN** its commands start with the 20 road tiles of the ring from (ax − 1, ay − 1) to (ax + 4, ay + 4) in row-major order, end with the building, and the building lies in a block next to the town center's block

#### Scenario: Rival buildings touch a road

- **WHEN** a rival has played 20 steps
- **THEN** every rival building other than a road is adjacent to a rival road tile connected to its town center

### Requirement: Rival purse

Tax from a rival's houses SHALL be credited to the rival's treasury and upkeep of a rival's buildings SHALL be deducted from it, without difficulty scaling. A rival SHALL never go bankrupt; a rival with a negative treasury SHALL wait.

#### Scenario: Rival tax goes to the rival

- **WHEN** taxes are collected while rival 1 has houses with 10 peasant residents and the player has none
- **THEN** rival 1's treasury rises by $10 and the player's balance does not change

#### Scenario: Rival in debt

- **WHEN** a rival's treasury is −$20 for 500 ticks
- **THEN** the game is not over and the rival places nothing

### Requirement: Rivals don't share the player's effects

History events, research knowledge, goal progress and the city population SHALL use only player-owned buildings and houses.

#### Scenario: Rats spare the rivals

- **WHEN** rats in the granary fires while rival 1's town center holds 10 food
- **THEN** rival 1's town center still holds 10 food

#### Scenario: Stock goal ignores rival stores

- **WHEN** a scenario has the goal "20 bread" and only a rival's buffers hold bread
- **THEN** the goal's progress is 0/20

### Requirement: Rival ages

After its turn, a rival whose residents reach the next age's threshold (Medieval 24, Renaissance 60, Industrial 108, Modern 150) SHALL advance one age and emit `rivalAgeAdvanced` with its ID and the new age.

#### Scenario: Rival enters the Middle Ages

- **WHEN** an Antiquity rival with 24 residents finishes its turn
- **THEN** its age is Medieval and the tick's events include `rivalAgeAdvanced(1, medieval)`

#### Scenario: One age per turn

- **WHEN** an Antiquity rival with 70 residents finishes its turn
- **THEN** its age is Medieval, not Renaissance

### Requirement: Standings

The world SHALL report standings with one row per town (the player as "You" in gold, and each rival in its colour): population, age and wealth (the player's balance or the rival's treasury), sorted by population descending, ties with the player first, then by rival ID.

#### Scenario: Standings order

- **WHEN** the player has 40 residents, rival 1 has 52 and rival 2 has 40
- **THEN** the standings read rival 1, You, rival 2

### Requirement: Outgrow every rival

The goal "outgrow every rival" SHALL be met when the player's population is greater than every rival's population. Its progress SHALL read as the player's population against the largest rival population plus one. In a world without rivals it SHALL be met once the player has a resident.

#### Scenario: Tied is not enough

- **WHEN** the player has 52 residents and the largest rival has 52
- **THEN** the goal is not met and its progress is 52/53

#### Scenario: Outgrown

- **WHEN** the player has 53 residents and the largest rival has 52
- **THEN** the goal is met

### Requirement: Island Rivalry scenario

The game SHALL offer a fourth built-in scenario, Island Rivalry: Medieval, Normal, archipelago layout required, with the goals "outgrow every rival" and 80 residents.

#### Scenario: Island Rivalry setup

- **WHEN** a new game is created from Island Rivalry
- **THEN** it is an archipelago game in the Medieval age on Normal with two rivals and goals "outgrow every rival" and 80 residents
