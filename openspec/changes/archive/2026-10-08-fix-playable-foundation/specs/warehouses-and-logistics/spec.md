## MODIFIED Requirements

### Requirement: Goods buffer storage
A goods buffer SHALL store goods of any catalog type up to a declared per-buffer capacity. Storage MUST be queryable per good and in aggregate. The `Warehouse`, `Port`, and `TownCenter` building kinds are goods buffers; any future building kind that wishes to act as one MUST opt in by declaring a buffer capacity. The town center's buffer capacity is 40.

#### Scenario: Warehouse accepts deposits
- **WHEN** a carrier delivers wood to a warehouse with available capacity
- **THEN** the warehouse's stored wood count increases by the delivered amount

#### Scenario: Port accepts carrier deposits
- **WHEN** a carrier delivers wood to a road-connected port with available capacity
- **THEN** the port's stored wood count increases by the delivered amount

#### Scenario: Town center accepts carrier deposits
- **WHEN** a road-connected producer has output and the only road-connected goods buffer is the town center
- **THEN** a carrier delivers the output to the town center and its stored count increases by the delivered amount

#### Scenario: Full buffer rejects deposits
- **WHEN** a carrier attempts to deliver wood to any goods buffer (warehouse, port, or town center) at full capacity
- **THEN** the delivery is rejected and the carrier returns or routes to another goods buffer

### Requirement: Warehouse range and selection
When multiple road-connected goods buffers are reachable, producers SHALL prefer the buffer with the shortest path that has capacity. Tie-breaking MUST be deterministic: among equally short paths, the buffer with the lowest entity ID wins.

#### Scenario: Closer warehouse wins
- **WHEN** two warehouses with capacity are reachable at path lengths 5 and 10
- **THEN** the producer routes to the length-5 warehouse

#### Scenario: Equidistant buffers tie-break on entity ID
- **WHEN** two goods buffers with capacity are reachable at the same path length
- **THEN** the producer routes to the buffer with the lower entity ID, on every run
