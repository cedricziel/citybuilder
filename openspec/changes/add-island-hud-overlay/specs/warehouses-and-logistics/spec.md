## ADDED Requirements

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
