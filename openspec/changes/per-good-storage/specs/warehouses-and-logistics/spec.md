## MODIFIED Requirements

### Requirement: Goods buffer storage
A goods buffer SHALL hold each catalog good separately, up to a per-good limit its building kind declares in the content pack (`storagePerGood`). One good filling its limit SHALL NOT reduce the room for any other good. Storage MUST be queryable per good, as stock and as room, and in aggregate. The `Warehouse`, `Port`, and `TownCenter` building kinds are goods buffers; any future building kind that wishes to act as one MUST opt in by declaring a per-good limit. The shipped packs SHALL give the town center a limit of 40 per good, and the warehouse and the port 80 per good. Producer and house stockpiles keep one capacity shared by every good.

#### Scenario: Warehouse accepts deposits
- **WHEN** a carrier delivers wood to a warehouse with room for wood
- **THEN** the warehouse's stored wood count increases by the delivered amount

#### Scenario: Port accepts carrier deposits
- **WHEN** a carrier delivers wood to a road-connected port with room for wood
- **THEN** the port's stored wood count increases by the delivered amount

#### Scenario: Town center accepts carrier deposits
- **WHEN** a road-connected producer has output and the only road-connected goods buffer is the town center
- **THEN** a carrier delivers the output to the town center and its stored count increases by the delivered amount

#### Scenario: Full buffer rejects deposits
- **WHEN** a carrier attempts to deliver wood to any goods buffer (warehouse, port, or town center) holding its limit of wood
- **THEN** the delivery is rejected and the carrier returns or routes to another goods buffer

#### Scenario: Bread never crowds out iron
- **WHEN** a smelter holding 1 iron shares a road with a warehouse holding its limit of bread and no iron
- **THEN** a carrier takes the iron to that warehouse

### Requirement: Warehouse range and selection
When multiple road-connected goods buffers are reachable, producers SHALL prefer the buffer with the shortest path that has room for the good. A buffer has room for a good while the units of it that it holds, plus the units of it already on their way to it, stay below its limit for that good. Tie-breaking MUST be deterministic: among equally short paths, the buffer with the lowest entity ID wins.

#### Scenario: Closer warehouse wins
- **WHEN** two warehouses with room for the good are reachable at path lengths 5 and 10
- **THEN** the producer routes to the length-5 warehouse

#### Scenario: Equidistant buffers tie-break on entity ID
- **WHEN** two goods buffers with room for the good are reachable at the same path length
- **THEN** the producer routes to the buffer with the lower entity ID, on every run

#### Scenario: A store's room for a good is not promised twice
- **WHEN** two bakeries each hold 1 bread and the only warehouse has room for 1 more bread
- **THEN** one carrier takes bread to the warehouse and the other bakery keeps its bread

### Requirement: Per-island stockpile aggregate in snapshot

`WorldSnapshot` SHALL expose `islandSummaries: [IslandID: IslandSummary]` where each `IslandSummary` carries the island's name, bounding box, and the sum-by-good of every warehouse, port, and shipyard stockpile that anchors on the island. Producer-internal stockpiles (sawmill / lumberjack hut output buffers) MUST NOT contribute to the aggregate — they are in-transit and don't count toward "what's available to spend." Capacity is aggregated per good: the sum, across every goods-buffer building on the island, of its limit for that good, or of its whole shared capacity for a stockpile shared by every good.

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

- **WHEN** an island has one warehouse and one port, each with a limit of 80 per good
- **THEN** the island's `IslandSummary.capacity[.wood]` is 160

## ADDED Requirements

### Requirement: Buildings report what stops them

The world SHALL report, for each operational player house, producer and forester, the first issue that stops it. A forester's only issue SHALL be no open grass in its catchment; it needs no road and no route to storage. For houses and producers, issues SHALL be checked in this order: no road beside it; for a lumberjack hut, no unoccupied forest in its catchment; its road does not reach a road beside an operational warehouse, port or town center; for a producer whose own stockpile has no room for a cycle's output, output stuck, naming the good it makes that it holds most of (the first in catalog order on a tie), since inputs could not help it; for a producer, inputs short of its recipe (listing the short goods). A building with none of these SHALL have no issue. The query MUST NOT change the world, and the snapshot SHALL carry its result.

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

#### Scenario: A producer with a full store reports its output stuck
- **WHEN** a connected farm's store holds 16 food
- **THEN** its issue is output stuck, naming food

#### Scenario: A producer short of inputs reports the missing goods
- **WHEN** a connected sawmill holds no wood
- **THEN** its issue is missing inputs: wood

#### Scenario: A producer full of output reports it stuck, not short
- **WHEN** a connected sawmill holds 16 planks and no wood
- **THEN** its issue is output stuck, naming planks

#### Scenario: A house off the storage network reports no route to storage
- **WHEN** a house's road and a warehouse's road are not connected
- **THEN** the house's issue is no route to storage

#### Scenario: The snapshot carries building issues
- **WHEN** a farm without a road is in the world
- **THEN** the snapshot's building issues map the farm to no road

#### Scenario: A forester without open grass reports no room to plant
- **WHEN** every tile in an operational forester's catchment is forest or occupied
- **THEN** its issue is no room to plant

#### Scenario: A forester without a road reports no issue
- **WHEN** an operational forester has no road beside it and open grass in its catchment
- **THEN** it has no issue


### Requirement: Producers ship only where there is room

A producer's output SHALL leave its own stockpile only for a destination that takes it: a construction site waiting for that good, or a goods buffer its road reaches with room for that good. Otherwise the output SHALL stay in the producer's stockpile, nothing is lost, and the producer stops once that stockpile has no room for a cycle's output; it resumes as soon as a destination has room again. A carrier whose destination, still standing, has no room for what it carries on arrival SHALL keep what does not fit, so no good is destroyed by a full store, whatever else filled it meanwhile (a purchase, a ship, a harvest). A producer's carrier SHALL then go on to the nearest other store with room for the good, counting what is already on its way there, or else take the goods home to its producer, which frees its carrier slot; at home with no room it waits and looks again each tick. A supply carrier waits at its consumer until it has room. A supply carrier SHALL set out only for a consumer with room for one more unit beyond those already on their way to it. A store's room grows when its stock of the good is drawn down: by construction, by houses, by supply carriers, or by a market or trade sale.

#### Scenario: Output with nowhere to go stays with its producer
- **WHEN** a bakery holding 1 bread shares a road only with a warehouse holding its limit of bread
- **THEN** no carrier leaves the bakery and the bakery still holds 1 bread

#### Scenario: A producer whose output is stuck reports it
- **WHEN** a connected farm's store is full of food and every store on its road network holds its limit of food
- **THEN** its issue is output stuck, naming food, and it keeps every unit

#### Scenario: Output leaves once the store has room again
- **WHEN** a bakery holds 1 bread, the only warehouse holds its limit of bread, and 1 bread is then taken from the warehouse
- **THEN** on the next tick a carrier takes the bakery's bread to that warehouse

#### Scenario: A carrier whose store filled on the way goes on to one with room
- **WHEN** a bakery holding 10 bread has 2 carriers walking to a near warehouse that fills with bread before they arrive, and a far warehouse has room
- **THEN** all 10 bread reach the far warehouse and none is lost

#### Scenario: A carrier with no store to go to takes its goods home
- **WHEN** a carrier walks 1 bread to the only warehouse, which fills with bread before it arrives
- **THEN** it takes the bread back to its bakery, the bakery's carrier slot is free again, and the bread leaves once the warehouse has room

#### Scenario: A stuck producer gets no more inputs and nothing is lost
- **WHEN** a sawmill holds 15 planks in its 16-unit stockpile and the only warehouse holds its limit of planks and 60 wood
- **THEN** after 2,000 ticks the sawmill holds 15 planks and 1 wood, the warehouse 59 wood, and no wood or plank has been lost

## REMOVED Requirements

### Requirement: Buildings report why they are idle
**Reason**: A producer no longer rests (the rest rule is removed, see `goods-and-production`), and a full producer store now means its output has nowhere to go, so the issue names the good that is stuck. Both scenarios change name with it, which a MODIFIED block cannot do.
**Migration**: "Buildings report what stops them" carries the same checks in the same order, without resting, and reports output stuck, naming the good, where this one reported storage full.
