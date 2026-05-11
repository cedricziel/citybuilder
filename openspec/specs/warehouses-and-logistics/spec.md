# warehouses-and-logistics Specification

## Purpose
TBD - created by archiving change add-mvp-foundation. Update Purpose after archive.

## Requirements
### Requirement: Warehouse storage
A warehouse SHALL store goods of any catalog type up to a declared per-warehouse capacity. Storage MUST be queryable per good and in aggregate.

#### Scenario: Warehouse accepts deposits
- **WHEN** a carrier delivers wood to a warehouse with available capacity
- **THEN** the warehouse's stored wood count increases by the delivered amount

#### Scenario: Full warehouse rejects deposits
- **WHEN** a carrier attempts to deliver wood to a warehouse at full capacity
- **THEN** the delivery is rejected and the carrier returns or routes to another warehouse

### Requirement: Carrier entities
Each producer building SHALL emit carrier entities when it has output to ship and a destination warehouse is reachable via roads. Each consumer building SHALL emit carrier entities to pull required goods from warehouses. Carriers MUST be discrete simulation entities, not abstract throughput.

#### Scenario: Producer emits carrier
- **WHEN** a producer has at least one good in its output stockpile and a road-connected warehouse with capacity exists
- **THEN** the producer spawns a carrier entity carrying one unit of that good

#### Scenario: Consumer emits carrier
- **WHEN** a consumer has unmet input needs and a road-connected warehouse holding the required good exists
- **THEN** the consumer spawns a carrier entity tasked with retrieval

### Requirement: Carrier movement
Carriers SHALL traverse the road network at a configured speed in tiles-per-tick. They MUST follow the path returned by the road-network pathfinder.

#### Scenario: Carrier follows path
- **WHEN** a carrier is spawned with a path of N tiles and speed S
- **THEN** after N/S ticks the carrier arrives at its destination tile

#### Scenario: Carrier despawns on arrival
- **WHEN** a carrier arrives at its destination and completes its delivery or pickup
- **THEN** the carrier entity is removed from the simulation

### Requirement: Carrier failure on broken path
If the road network changes such that a carrier's remaining path becomes invalid, the carrier MUST attempt a single re-path. If no path exists, the carrier MUST return to origin or despawn after dropping its cargo back at origin.

#### Scenario: Road removal recovers gracefully
- **WHEN** a road on a carrier's remaining path is demolished and no alternative path exists
- **THEN** the carrier returns to its origin and restores its cargo to the origin stockpile

### Requirement: Warehouse range and selection
When multiple road-connected warehouses are reachable, producers SHALL prefer the warehouse with the shortest path that has capacity. Tie-breaking MUST be deterministic.

#### Scenario: Closer warehouse wins
- **WHEN** two warehouses with capacity are reachable at path lengths 5 and 10
- **THEN** the producer routes to the length-5 warehouse

### Requirement: Concurrent carrier cap per producer
The number of in-flight carriers a single producer may have outstanding SHALL be bounded by a configurable cap to prevent runaway entity counts.

#### Scenario: Producer respects carrier cap
- **WHEN** a producer with cap K already has K carriers in flight
- **THEN** it does not spawn additional carriers until at least one returns
