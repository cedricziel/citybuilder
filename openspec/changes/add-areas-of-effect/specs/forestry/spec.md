## ADDED Requirements

### Requirement: Catchment radius is game data

A building's catchment radius SHALL come from its `catchmentRadius` field in the game data: the Chebyshev distance from its footprint within which it works. The lumberjack hut and the forester SHALL declare a radius of 2, and every catchment rule (harvesting, planting, the counts in reach, building issues, rival site choice and start sites) SHALL read it from the building's kind. The generator SHALL reject a radius below 1.

#### Scenario: Hut and forester declare their radius
- **WHEN** the generated building kinds are queried for their catchment radius
- **THEN** the lumberjack hut and the forester report 2, and the sawmill reports none

#### Scenario: A non-positive radius is rejected
- **WHEN** a pack declares a building with `catchmentRadius: 0`
- **THEN** the generator reports an error naming the building and `catchmentRadius`

#### Scenario: The catchment follows the declared radius
- **WHEN** a lumberjack hut at a free anchor has forest 2 tiles from its footprint and nothing nearer
- **THEN** it counts that forest in reach, and forest 3 tiles away is not counted
