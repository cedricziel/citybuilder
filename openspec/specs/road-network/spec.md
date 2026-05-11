# road-network Specification

## Purpose
TBD - created by archiving change add-mvp-foundation. Update Purpose after archive.

## Requirements
### Requirement: Road tile placement
The player SHALL be able to place road tiles on any build-eligible land tile. Roads MUST occupy a single tile each and MUST stack with no other building on the same tile.

#### Scenario: Road placement on grass
- **WHEN** the player places a road tile on grass
- **THEN** the tile becomes a road and is part of the road network

#### Scenario: Road placement on water rejected
- **WHEN** the player attempts to place a road on a water tile
- **THEN** the placement is rejected

### Requirement: Road graph derivation
The simulation SHALL maintain a graph of all road tiles where edges connect orthogonally-adjacent road tiles. The graph MUST be incrementally updated when roads are added or removed.

#### Scenario: New road extends graph
- **WHEN** a road tile is placed adjacent to an existing road
- **THEN** the two tiles share an edge in the road graph

#### Scenario: Removing road removes edges
- **WHEN** a road tile is demolished
- **THEN** all graph edges incident to that tile are removed within the same tick

### Requirement: Building road connectivity
A building SHALL be considered "road-connected" if at least one tile orthogonally adjacent to its footprint is a road tile.

#### Scenario: Adjacent road connects building
- **WHEN** a road is placed adjacent to a warehouse
- **THEN** the warehouse reports `roadConnected == true`

#### Scenario: Diagonal road does not connect
- **WHEN** the only nearby road is diagonally adjacent to a building
- **THEN** the building reports `roadConnected == false`

### Requirement: Pathfinding over road graph
The simulation SHALL provide an A* pathfinding query that returns the shortest road-path between two road-connected buildings, or no path if disconnected. Pathfinding MUST be deterministic given identical inputs.

#### Scenario: Path found between connected buildings
- **WHEN** two warehouses are both road-connected and the road network forms a continuous path
- **THEN** pathfinding returns an ordered list of road tiles from source to destination

#### Scenario: Disconnected buildings return no path
- **WHEN** two buildings are road-connected but their connected road components are separate
- **THEN** pathfinding returns nil/no-path

### Requirement: Pathfinding cache invalidation
Path results MAY be cached for reuse, but the cache MUST be invalidated whenever a road is placed or removed.

#### Scenario: Cache invalidated on road change
- **WHEN** a road tile is placed or removed
- **THEN** any previously cached pathfinding results that traverse the affected component are evicted before the next pathfinding query
