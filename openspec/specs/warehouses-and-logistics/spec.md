# warehouses-and-logistics Specification

## Purpose
TBD - created by archiving change add-mvp-foundation. Update Purpose after archive.
## Requirements
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

### Requirement: Per-island stockpile aggregate in snapshot

`WorldSnapshot` SHALL expose `islandSummaries: [IslandID: IslandSummary]` where each `IslandSummary` carries the island's name, bounding box, and the sum-by-good of every warehouse, port, and shipyard stockpile that anchors on the island. Producer-internal stockpiles (sawmill / lumberjack hut output buffers) MUST NOT contribute to the aggregate — they are in-transit and don't count toward "what's available to spend." Capacity is similarly aggregated: the sum of per-good capacity across every goods-buffer building on the island.

#### Scenario: IslandSummary aggregates warehouse and port stockpiles

- **WHEN** an island has two warehouses each holding 6 wood and one port holding 3 wood
- **THEN** the island's `IslandSummary.stockpile[.wood]` is 15

#### Scenario: Producer internal stockpiles are excluded from the aggregate

- **WHEN** an island has a sawmill with 5 planks in its internal output buffer and no warehouses
- **THEN** the island's `IslandSummary.stockpile[.planks]` is 0

#### Scenario: Empty island has zero stocks and zero capacity

- **WHEN** an island has no buildings at all
- **THEN** the island's `IslandSummary.stockpile` and `IslandSummary.capacity` are both empty (or all zero)

#### Scenario: Capacity sums across all goods-buffers

- **WHEN** an island has one warehouse with capacity 200 and one port with capacity 100
- **THEN** the island's `IslandSummary.capacity[.wood]` is 300

### Requirement: Tile-to-island lookup in snapshot

`WorldSnapshot` SHALL expose `island(at: TileCoordinate) -> IslandID?`. The lookup MUST return the `IslandID` of the island whose buildable tile set contains the input coordinate, or nil if the tile is water (or outside any island's bounding box). The lookup MUST be O(1) — backed by an internally-cached `[TileCoordinate: IslandID]` map built at snapshot construction.

#### Scenario: Tile-to-island lookup resolves containing island

- **WHEN** `snapshot.island(at: tile)` is called with a tile inside Island #2's buildable area
- **THEN** the return value is Island #2's `IslandID`

#### Scenario: Water tile resolves to nil

- **WHEN** `snapshot.island(at: tile)` is called with a water tile not inside any island
- **THEN** the return value is nil

### Requirement: Cross-warehouse partial withdrawal API

`Stockpile` SHALL expose a withdrawal API that callers (notably `World.applyPlace`) can use to take a specific amount of a good. When a single warehouse lacks the full requested amount, the caller iterates additional warehouses to cover the shortfall. The withdrawal call itself MUST be atomic per-warehouse: it MUST NOT partially withdraw and report success — it withdraws exactly `amount` or returns the amount actually withdrawn so the caller can advance.

#### Scenario: Withdrawal returns actual amount taken

- **WHEN** a warehouse holds 3 wood and `withdraw(.wood, amount: 5)` is called
- **THEN** the warehouse's wood drops to 0 and the withdrawal returns `3` (the amount actually taken)

#### Scenario: Withdrawal from sufficient warehouse takes exactly the requested amount

- **WHEN** a warehouse holds 5 wood and `withdraw(.wood, amount: 3)` is called
- **THEN** the warehouse's wood drops to 2 and the withdrawal returns `3`

### Requirement: Island warehouse query

`World` SHALL expose a deterministic query for all goods-buffer buildings (warehouse + port + shipyard) anchored on a given island, sorted by ascending road-distance from a reference anchor. The query underlies `applyPlace`'s deduction loop and any future "find me wood" lookups.

#### Scenario: Query returns goods buffers on the named island only

- **WHEN** Island #1 has two warehouses and Island #2 has one warehouse, and the query asks for Island #1
- **THEN** the query returns exactly Island #1's two warehouses

#### Scenario: Query order is shortest road-distance first

- **WHEN** Island #1's two warehouses sit at road-distances 3 and 7 from the reference anchor
- **THEN** the warehouse at distance 3 appears first in the result
