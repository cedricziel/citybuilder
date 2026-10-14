## ADDED Requirements

### Requirement: Buildings report why they are idle

The world SHALL report, for each operational player house and producer, the first issue that stops it, checked in this order: no road beside it; for a lumberjack hut, no unoccupied forest in its catchment; its road does not reach a road beside an operational warehouse, port or town center; for a producer, inputs short of its recipe (listing the short goods); for a producer, a store with no room for a cycle's output. A building with none of these SHALL have no issue. The query MUST NOT change the world, and the snapshot SHALL carry its result.

#### Scenario: A producer without a road reports no road
- **WHEN** a farm has no road beside it
- **THEN** its issue is no road

#### Scenario: A producer off the storage network reports no route to storage
- **WHEN** a farm's road and a warehouse's road are not connected
- **THEN** the farm's issue is no route to storage

#### Scenario: A producer on the storage network reports no issue
- **WHEN** a farm and a warehouse share a road
- **THEN** the farm has no issue

#### Scenario: A lumberjack without forest reports no trees in reach
- **WHEN** a road-connected lumberjack hut has no forest within its catchment
- **THEN** its issue is no trees in reach

#### Scenario: A producer with a full store reports storage full
- **WHEN** a connected farm's store holds 16 food
- **THEN** its issue is storage full

#### Scenario: A producer short of inputs reports the missing goods
- **WHEN** a connected sawmill holds no wood
- **THEN** its issue is missing inputs: wood

#### Scenario: A house off the storage network reports no route to storage
- **WHEN** a house's road and a warehouse's road are not connected
- **THEN** the house's issue is no route to storage

#### Scenario: The snapshot carries building issues
- **WHEN** a farm without a road is in the world
- **THEN** the snapshot's building issues map the farm to no road
