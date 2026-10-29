# forestry Specification

## Purpose
Makes wood a renewable resource: a forester replants forest beside lumberjack huts, and huts and foresters report the trees and open ground they can reach so the player can keep a wood supply running.
## Requirements
### Requirement: Forester building

The building catalog SHALL include a `forester` kind with a 2×2 footprint, a cost of $60, no upkeep, a build time of 20 ticks and no material cost. It SHALL be land-only, need no research, and be buildable in every culture and age. It SHALL have no stockpile and no production recipe, and it SHALL NOT count as a goods buffer.

#### Scenario: Forester spec exposes its footprint and costs
- **WHEN** the building catalog is queried for `forester`
- **THEN** it reports a 2×2 footprint, a cost of 60, no upkeep, a build time of 20 ticks and an empty material cost

#### Scenario: Forester needs no research
- **WHEN** the player asks whether a forester can be placed on free grass in a new medieval game where nothing beyond the starting techs is researched
- **THEN** the answer is allowed

### Requirement: Forester plants forest

An operational forester SHALL plant one forest tile every 40 ticks. Planting SHALL turn the first open grass tile in its catchment into forest, scanning in row-major order. The catchment is every tile within 2 tiles (Chebyshev distance) of its footprint, the same as a lumberjack hut's. A tile is open when it is grass, no building occupies it, and it lies on an island the forester's owner owns. The forester SHALL need no road, no storage and no inputs. While its catchment holds no open grass, it SHALL plant nothing and its cycle progress SHALL NOT advance. Planting SHALL emit a `forestPlanted` event with the tile and the forester. Forest planted this way SHALL be harvested by lumberjack huts like any other forest.

#### Scenario: Forester plants the first open grass tile
- **WHEN** a forester with only grass around it has been operational for 40 ticks
- **THEN** the top-left open grass tile of its catchment is forest, and the tick emits `forestPlanted` for that tile

#### Scenario: Forester skips occupied and non-grass tiles
- **WHEN** a forester's catchment holds a road, a house, a beach tile and a mountain tile before its first grass tile in row-major order
- **THEN** its first planting turns that grass tile into forest and leaves the other tiles unchanged

#### Scenario: Forester without open grass plants nothing
- **WHEN** every tile in a forester's catchment is forest, water or occupied
- **THEN** after 80 ticks no tile has changed and no `forestPlanted` event was emitted

#### Scenario: Forester works without a road
- **WHEN** a forester with no road beside it has been operational for 40 ticks
- **THEN** it has planted one forest tile

#### Scenario: Forester and lumberjack hut sustain each other
- **WHEN** a lumberjack hut and a forester with overlapping catchments run for 2400 ticks on grass with no forest at the start, with the calendar inactive
- **THEN** the hut has completed at least 50 cycles, and after its first harvest its catchment is never without forest for longer than 40 ticks

#### Scenario: Forester never plants on a rival island
- **WHEN** a player forester's catchment reaches grass on a rival's island
- **THEN** it never plants there

### Requirement: Foresters plant at half pace in winter

While the calendar is active and the season is winter, a forester SHALL advance its cycle at half speed, as farms do.

#### Scenario: Forester takes twice as long in winter
- **WHEN** an operational forester starts a cycle at the beginning of winter with the calendar active
- **THEN** it plants its tile after 80 ticks

#### Scenario: Forester ignores winter with the calendar inactive
- **WHEN** a forester runs through winter with the calendar inactive
- **THEN** it plants a tile every 40 ticks

### Requirement: Trees and open ground in reach

The world SHALL report, for each lumberjack hut, the number of unoccupied forest tiles in its catchment, and for each forester, the number of open grass tiles in its catchment. The snapshot SHALL carry these counts by building. The world SHALL answer the same count for a building kind and anchor that is not built yet, so the player can see a site's value before placing it. These queries MUST NOT change the world.

#### Scenario: Snapshot carries trees in reach for a hut
- **WHEN** a lumberjack hut has 7 unoccupied forest tiles in its catchment
- **THEN** the snapshot reports 7 for that hut

#### Scenario: Snapshot carries open ground for a forester
- **WHEN** a forester has 12 open grass tiles in its catchment
- **THEN** the snapshot reports 12 for that forester

#### Scenario: Catchment preview for an unbuilt hut
- **WHEN** the world is asked how many trees a lumberjack hut at a free anchor would reach, and 9 unoccupied forest tiles lie within 2 tiles of that footprint
- **THEN** the answer is 9 and the world is unchanged

### Requirement: Catchment radius is game data

A building's catchment radius SHALL come from its `catchmentRadius` field in the game data: the Chebyshev distance from its footprint within which it works. The lumberjack hut and the forester SHALL declare a radius of 2, and every catchment rule (harvesting, planting, the counts in reach, building issues, rival site choice and start sites) SHALL read it from the building's kind. The generator SHALL reject a radius below 1, a building that plants (`plantTicks`) without a radius, and a lumberjack hut without one.

#### Scenario: Hut and forester declare their radius
- **WHEN** the generated building kinds are queried for their catchment radius
- **THEN** the lumberjack hut and the forester report 2, and the sawmill reports none

#### Scenario: A non-positive radius is rejected
- **WHEN** a pack declares a building with `catchmentRadius: 0`
- **THEN** the generator reports an error naming the building and `catchmentRadius`

#### Scenario: A planter or hut without a radius is rejected
- **WHEN** a pack declares a building with `plantTicks` but no `catchmentRadius`, or a lumberjack hut without one
- **THEN** the generator reports an error naming the building and `catchmentRadius`

#### Scenario: The catchment follows the declared radius
- **WHEN** a lumberjack hut at a free anchor has forest 2 tiles from its footprint and nothing nearer
- **THEN** it counts that forest in reach, and forest 3 tiles away is not counted
