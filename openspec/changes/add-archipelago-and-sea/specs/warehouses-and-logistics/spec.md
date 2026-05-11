## MODIFIED Requirements

### Requirement: Goods buffer storage
A goods buffer SHALL store goods of any catalog type up to a declared per-buffer capacity. Storage MUST be queryable per good and in aggregate. Both `Warehouse` and `Port` building kinds are goods buffers; any future building kind that wishes to act as one MUST opt in by declaring a buffer capacity.

#### Scenario: Warehouse accepts deposits
- **WHEN** a carrier delivers wood to a warehouse with available capacity
- **THEN** the warehouse's stored wood count increases by the delivered amount

#### Scenario: Port accepts carrier deposits
- **WHEN** a carrier delivers wood to a road-connected port with available capacity
- **THEN** the port's stored wood count increases by the delivered amount

#### Scenario: Full buffer rejects deposits
- **WHEN** a carrier attempts to deliver wood to any goods buffer (warehouse or port) at full capacity
- **THEN** the delivery is rejected and the carrier returns or routes to another goods buffer

### Requirement: Carrier entities
Each producer building SHALL emit carrier entities when it has output to ship and a destination goods buffer is reachable via roads. Each consumer building SHALL emit carrier entities to pull required goods from a goods buffer. Carriers MUST be discrete simulation entities, not abstract throughput. The choice of destination MUST be the nearest reachable goods buffer (warehouse or port) that satisfies the request, with deterministic tie-breaking by entity ID.

#### Scenario: Producer emits carrier to warehouse
- **WHEN** a producer has at least one good in its output stockpile and a road-connected warehouse with capacity exists
- **THEN** the producer spawns a carrier entity carrying one unit of that good targeted at that warehouse

#### Scenario: Producer emits carrier to port when port is nearest goods buffer
- **WHEN** a producer has at least one good in its output stockpile, no warehouse is road-connected within range, and a road-connected port with capacity exists
- **THEN** the producer spawns a carrier entity carrying one unit of that good targeted at that port

#### Scenario: Consumer pulls from port
- **WHEN** a consumer has unmet input needs and the nearest road-connected goods buffer holding the required good is a port
- **THEN** the consumer spawns a carrier entity tasked with retrieval from that port

#### Scenario: Deterministic tie-break by entity ID
- **WHEN** two goods buffers are equidistant from a producer and both have capacity for the offered good
- **THEN** the carrier targets the buffer with the lower `EntityID`

### Requirement: Carrier movement
Carriers SHALL traverse the road network at a configured speed in tiles-per-tick. They MUST follow the path returned by the road-network pathfinder. Carriers remain land-only entities and MUST NOT enter water tiles.

#### Scenario: Carrier follows path
- **WHEN** a carrier is spawned with a path of N tiles and speed S
- **THEN** after N/S ticks the carrier arrives at its destination tile

#### Scenario: Carrier rejects water-tile path
- **WHEN** the pathfinder is asked for a route that would require a carrier to enter a water tile
- **THEN** no such path is ever returned (water tiles are not in the road graph)
