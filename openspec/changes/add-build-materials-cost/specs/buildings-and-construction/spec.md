## ADDED Requirements

### Requirement: Building material cost

Every `BuildingSpec` SHALL declare an optional `materialCost: [Good: Int]` describing the goods consumed at placement. The map MAY be empty (default), meaning the building is free of materials and only constrained by money cost. Roads and the town center MUST have empty material cost.

#### Scenario: BuildingSpec carries a material cost per good

- **WHEN** `BuildingCatalog.spec(for: .sawmill).materialCost` is queried
- **THEN** the returned map contains entries for `.wood` and `.planks` with positive integer amounts

#### Scenario: Default material cost is empty

- **WHEN** a `BuildingSpec` is constructed without specifying a `materialCost`
- **THEN** its `materialCost` reads as the empty dictionary `[:]`

#### Scenario: Road and town center have no material cost

- **WHEN** `BuildingCatalog.spec(for: .road).materialCost` is queried
- **THEN** it returns `[:]`

- **WHEN** `BuildingCatalog.spec(for: .townCenter).materialCost` is queried
- **THEN** it returns `[:]`

### Requirement: Placement rejected when island materials are short

`World.canPlace(_:at:)` SHALL reject placement when the island containing the anchor cannot supply the building's `materialCost` from its warehouses and ports. The rejection reason MUST carry the per-good shortfall (the difference between what was needed and what the island has). Buildings with empty `materialCost` MUST skip this check.

#### Scenario: Placement allowed when island has enough materials

- **WHEN** the player attempts to place a sawmill (cost: 4 wood + 1 plank) on an island whose warehouses hold 5 wood + 2 planks
- **THEN** `canPlace` returns `.allowed`

#### Scenario: Placement rejected when island is short

- **WHEN** the player attempts to place a sawmill (cost: 4 wood + 1 plank) on an island whose warehouses hold 2 wood + 1 plank
- **THEN** `canPlace` returns `.rejected(.insufficientMaterials([.wood: 2]))` (the shortfall is 2 wood; planks are sufficient and absent from the shortfall map)

#### Scenario: Free-of-materials building (road) ignores material check

- **WHEN** the player attempts to place a road on an island with zero stocks
- **THEN** `canPlace` does not reject for insufficient materials (it may still reject for terrain or occupancy reasons)

#### Scenario: Materials on a different island do not count

- **WHEN** the player attempts to place a sawmill on Island #2 while Island #1 holds 10 wood and Island #2 holds 0 wood
- **THEN** `canPlace` returns `.rejected(.insufficientMaterials([.wood: 4]))`

### Requirement: Deterministic multi-warehouse deduction

`World.applyPlace` SHALL deduct the building's `materialCost` from goods-buffer buildings on the placement's island. The deduction order MUST be: shortest road-distance from the placement anchor first, breaking ties by ascending `EntityID`. Per-good iteration MUST follow the declared `Good` enum order. When no single warehouse has enough of a given good, the deduction MUST split across multiple warehouses until the requirement is met (which is always possible because `canPlace` allowed the placement).

#### Scenario: Deduction draws from single warehouse when sufficient

- **WHEN** placement requires 3 wood and the closest warehouse holds 5 wood
- **THEN** 3 wood is withdrawn from that warehouse and no other warehouse is touched

#### Scenario: Deduction splits across multiple warehouses when no single one has enough

- **WHEN** placement requires 5 wood and the closest two warehouses hold 3 wood and 4 wood respectively
- **THEN** the first warehouse contributes 3 wood and the second contributes 2 wood, totaling 5

#### Scenario: Deduction order is shortest road-distance first

- **WHEN** two equally-stocked warehouses sit at road-distances 3 and 7 from the placement anchor
- **THEN** the warehouse at distance 3 is debited first

#### Scenario: Deduction is deterministic across replays

- **WHEN** two simulations replay the same input sequence with placements that trigger material deduction
- **THEN** the resulting warehouse stockpiles are equal across both replays

### Requirement: Town center starter inventory

World-gen SHALL seed each island's initial town center `Stockpile` with **4 wood + 2 planks**. The starter inventory MUST contribute to the island's aggregate stockpile and MUST be available for deduction on the first placements.

#### Scenario: Fresh-world town center holds starter goods

- **WHEN** a fresh world is generated and the initial town center is inspected
- **THEN** its stockpile reads 4 wood and 2 planks

#### Scenario: Starter goods are part of the island stockpile aggregate

- **WHEN** the island's `IslandSummary.stockpile` is queried on a fresh world
- **THEN** it reflects the town center's 4 wood + 2 planks (plus any other goods-buffers on the island)

#### Scenario: First lumberjack placement consumes starter wood

- **WHEN** the player places a lumberjack hut (cost: 2 wood) on a fresh world
- **THEN** placement succeeds and the town center stockpile reads 2 wood + 2 planks
