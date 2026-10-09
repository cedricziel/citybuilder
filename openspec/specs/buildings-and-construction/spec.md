# buildings-and-construction Specification

## Purpose
TBD - created by archiving change add-mvp-foundation. Update Purpose after archive.
## Requirements
### Requirement: Building catalog
The system SHALL define a catalog of building types available in MVP. The catalog MUST include at minimum: `warehouse`, `lumberjack_hut`, `sawmill`, `house`, `road`, and a base `town_center`. Each building type MUST declare its footprint, cost, terrain rules, and any production/storage behavior.

#### Scenario: Catalog is accessible
- **WHEN** any subsystem requests the building catalog
- **THEN** every MVP building type is enumerated with its full metadata

### Requirement: Footprint placement
Each building SHALL declare a rectangular footprint in tiles (e.g. 2×2, 3×3). Placement MUST validate that every tile under the footprint is build-eligible and unoccupied before construction starts.

#### Scenario: Multi-tile placement validates each tile
- **WHEN** a player attempts to place a 3×3 building where one of the nine tiles is water
- **THEN** placement is rejected and no tiles are claimed

### Requirement: Construction state
A placed building SHALL progress through `planned → constructing → operational` states. Construction MUST take a non-zero number of ticks defined per building. A constructing building MUST NOT produce, store, or satisfy needs.

#### Scenario: Construction completes after declared duration
- **WHEN** a building is placed at tick T with build duration N
- **THEN** at tick T+N the building transitions to `operational`

#### Scenario: Constructing building is non-functional
- **WHEN** a warehouse is in `constructing` state
- **THEN** it accepts no goods and reports zero capacity

### Requirement: Demolition
The player SHALL be able to demolish any operational or constructing building they own. Demolition MUST free all tiles under the footprint and partially refund construction cost per a policy defined in design (zero refund acceptable in v0).

#### Scenario: Demolish frees tiles
- **WHEN** a 2×2 building is demolished
- **THEN** all four tiles become unoccupied and available for new placement

### Requirement: Build cost validation
Placement SHALL be rejected if the player does not have sufficient money to pay the building's full construction cost. Cost MUST be deducted at placement time, not at completion.

#### Scenario: Insufficient funds prevents placement
- **WHEN** the player attempts to place a building costing 500 with a balance of 499
- **THEN** placement is rejected with reason `insufficient_funds` and no money is deducted

### Requirement: Shore-placement rule
The placement validator SHALL provide a `shorePlacement` rule, opt-in per building kind, that permits a building's footprint to cover both land tiles and water tiles. A building kind that opts into `shorePlacement` MUST declare a minimum number of land tiles and a minimum number of water tiles in its footprint; a placement attempt MUST satisfy both minima or be rejected.

#### Scenario: Building without shore-placement rule rejects mixed footprint
- **WHEN** the player attempts to place a building kind that does NOT opt into `shorePlacement` such that its footprint covers any water tile
- **THEN** placement is rejected with reason code `terrain_not_buildable` (existing reason from MVP)

#### Scenario: Shore building rejected when below land minimum
- **WHEN** the player attempts to place a shore-placement building requiring ≥1 land tile, where the footprint covers only water tiles
- **THEN** placement is rejected with reason code `shore_requires_land_tile`

#### Scenario: Shore building rejected when below water minimum
- **WHEN** the player attempts to place a shore-placement building requiring ≥1 water tile, where the footprint covers only land tiles
- **THEN** placement is rejected with reason code `shore_requires_water_tile`

#### Scenario: Shore building accepted when minima satisfied
- **WHEN** the player places a shore-placement building requiring ≥1 land and ≥1 water tile, where the footprint covers at least one of each
- **THEN** placement succeeds and the building records its land-side tiles and water-side tile(s) separately

### Requirement: Per-tile face designation
A shore-placement building SHALL classify each tile of its committed footprint as either a `landFace` tile or a `seaFace` tile, based on the underlying terrain at placement time. Downstream subsystems (road connectivity, ship anchor, goods buffer queries) MAY query the building's face designation.

#### Scenario: Land face used for road adjacency
- **WHEN** road-connectivity is computed for a shore-placement building
- **THEN** only that building's `landFace` tiles are considered for orthogonal road adjacency

#### Scenario: Sea face used for ship anchor
- **WHEN** a shore-placement building exposes a ship anchor (e.g. Port)
- **THEN** the anchor coordinate is drawn from one of the building's `seaFace` tiles

#### Scenario: Face designation persists across save/load
- **WHEN** a world containing a shore-placement building is saved and loaded
- **THEN** the loaded building's land-face and sea-face tile classifications match the saved values

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

World-gen SHALL seed each island's initial town center `Stockpile` with **6 wood + 5 planks + 2 food**. The starter inventory MUST contribute to the island's aggregate stockpile and MUST be available for deduction on the first placements.

#### Scenario: Fresh-world town center holds starter goods

- **WHEN** a fresh world is generated and the initial town center is inspected
- **THEN** its stockpile reads 6 wood, 5 planks, and 2 food

#### Scenario: Starter goods are part of the island stockpile aggregate

- **WHEN** the island's `IslandSummary.stockpile` is queried on a fresh world
- **THEN** it reflects the town center's 6 wood + 5 planks + 2 food (plus any other goods-buffers on the island)

#### Scenario: First lumberjack placement consumes starter wood

- **WHEN** the player places a lumberjack hut (cost: 2 wood) on a fresh world
- **THEN** placement succeeds and the town center stockpile reads 4 wood + 5 planks + 2 food

#### Scenario: Starter goods afford a lumberjack, a farm, and a house

- **WHEN** on a fresh world the player places a lumberjack hut, then a farm, then a house on buildable land
- **THEN** all three placements are allowed

#### Scenario: Starter goods never strand the sawmill

- **WHEN** on a fresh world the player places a house and a lumberjack hut, and then tries to place a sawmill
- **THEN** the sawmill placement is allowed, because the town center still holds the one plank it needs

### Requirement: Farm building

The building catalog SHALL include a `farm` kind with a 2×2 footprint, a cost of $60, a material cost of 2 wood, and land-only placement (no shore placement).

#### Scenario: Farm spec exposes its footprint and costs

- **WHEN** the building catalog is queried for `farm`
- **THEN** it reports a 2×2 footprint, a cost of 60, and a material cost of 2 wood

### Requirement: Bakery building

The building catalog SHALL include a `bakery` kind with a 2×2 footprint, a cost of $90, a material cost of 2 wood and 2 planks, and land-only placement.

#### Scenario: Bakery spec exposes its footprint and costs

- **WHEN** the building catalog is queried for `bakery`
- **THEN** it reports a 2×2 footprint, a cost of 90, and a material cost of 2 wood and 2 planks

### Requirement: Chain buildings

The building catalog SHALL include these land buildings, each with a 2×2 footprint:

| Kind | Cost | Material cost |
|---|---|---|
| grain farm | $60 | 2 wood |
| windmill | $110 | 3 wood, 3 planks |
| mine | $120 | 4 wood, 2 planks |
| charcoal burner | $70 | 3 wood |
| smelter | $150 | 4 wood, 4 planks |
| toolsmith | $140 | 2 wood, 4 planks |

#### Scenario: Chain building specs are catalogued

- **WHEN** the building catalog is queried for the windmill
- **THEN** it reports a 2×2 footprint, a cost of 110 and a material cost of 3 wood and 3 planks

### Requirement: Terrain requirement for placement

A building kind MAY declare a required terrain and a minimum number of footprint tiles of that terrain. Placement MUST be rejected with reason `needsTerrain(kind)` when the footprint has fewer tiles of the required terrain. The mine requires at least 2 mountain tiles.

#### Scenario: Mine on grass is rejected

- **WHEN** the player attempts to place a mine whose footprint covers only grass
- **THEN** placement is rejected with `needsTerrain(.mountain)`

#### Scenario: Mine on the mountainside is allowed

- **WHEN** the player attempts to place a mine whose footprint covers 2 mountain tiles and 2 grass tiles, with materials available
- **THEN** placement is allowed

### Requirement: Library building

The building catalog SHALL include a `library` kind with a 2×2 footprint, a cost of $100, a material cost of 2 wood and 4 planks, and land-only placement.

#### Scenario: Library spec exposes its footprint and costs

- **WHEN** the building catalog is queried for `library`
- **THEN** it reports a 2×2 footprint, a cost of 100, and a material cost of 2 wood and 4 planks

### Requirement: Quern house

The building catalog SHALL include a quern house: 2×2 footprint, $60 with 2 wood and 2 planks, recipe 2 grain → 1 flour every 80 ticks, made obsolete by Milling.

#### Scenario: Quern house spec

- **WHEN** the quern house spec is read
- **THEN** it has a 2×2 footprint, costs $60 with 2 wood and 2 planks, and is obsoleted by Milling

### Requirement: Culture buildings

The catalog SHALL include the hop garden, vineyard, tea garden and coffee grove (2×2, $60, 2 wood) and the brewery, winery, tea house and roastery (2×2, $120, 3 wood and 3 planks), each tied to its culture.

#### Scenario: Tea house spec

- **WHEN** the tea house spec is read
- **THEN** it has a 2×2 footprint, costs $120 with 3 wood and 3 planks, and belongs to the East Asian culture

### Requirement: Age signature buildings

The catalog SHALL include the monument (3×3, $300, 6 wood and 6 planks, no upkeep), the guild hall (3×3, $250, 4 wood and 6 planks, upkeep 3), the gallery (2×2, $180, 2 wood and 4 planks, upkeep 2), the steam engine (2×2, $220, 2 wood, 4 planks and 2 iron, upkeep 3) and the power plant (3×3, $400, 6 planks and 4 iron, upkeep 6).

#### Scenario: Steam engine spec

- **WHEN** the steam engine spec is read
- **THEN** it has a 2×2 footprint, costs $220 with 2 wood, 4 planks and 2 iron, and has upkeep 3

### Requirement: One monument per city

Placing a monument SHALL be rejected with `alreadyBuilt` while its owner has a monument under construction or operational. After the monument is demolished a new one MAY be placed, starting at stage 0.

#### Scenario: Rebuilding after demolition

- **WHEN** the player demolishes a monument at stage 10 and places a new one
- **THEN** the placement is allowed and the new monument starts at stage 0

### Requirement: Culture signature buildings

The catalog SHALL include the mead hall (3×3, $180, 6 wood and 2 planks, upkeep 1, Northern European), the forum (3×3, $220, 2 wood and 6 planks, upkeep 2, Mediterranean), the temple garden (3×3, $160, 2 wood and 4 planks, upkeep 1, East Asian) and the caravanserai (3×3, $200, 4 wood and 4 planks, upkeep 2, Middle Eastern), each with a 16-unit stockpile.

#### Scenario: Caravanserai spec

- **WHEN** the caravanserai spec is read
- **THEN** it has a 3×3 footprint, costs $200 with 4 wood and 4 planks, has upkeep 2 and belongs to the Middle Eastern culture

### Requirement: Buildings have an owner

Every building SHALL have an owner: the player or a rival. A building placed by a player command SHALL be the player's; a building placed by a `rivalPlace` command SHALL be that rival's. A building decoded without an owner SHALL be the player's.

#### Scenario: Player placement

- **WHEN** the player places a house on the home island
- **THEN** the house's owner is the player

#### Scenario: Rival placement

- **WHEN** a `rivalPlace` command for rival 2 places a farm on rival 2's island
- **THEN** the farm's owner is rival 2 and its $60 cost is deducted from rival 2's treasury, not the player's balance

### Requirement: Placement on another owner's island is rejected

Placement SHALL be rejected with `foreignIsland(owner)`, naming the island's owner, when any land tile of the footprint lies on an island owned by someone other than the placing owner. Water tiles of a shore building SHALL NOT be checked. Rival placements SHALL skip the research lock and the obsolete check, and a rival's lumberjack hut SHALL cost no materials; terrain, occupancy, shore and material checks SHALL apply to every owner.

#### Scenario: Player builds on a rival island

- **WHEN** the player asks whether a house can be placed on rival 1's island
- **THEN** the answer is rejected with `foreignIsland(rival 1)`

#### Scenario: Rival builds without research

- **WHEN** rival 1 asks whether a sawmill can be placed on a free grass slot of its own island, with enough materials, in a world where the player has researched nothing
- **THEN** the answer is allowed

### Requirement: Rival buildings are protected from the player

A player `demolish` command on a rival building SHALL be ignored, and a player `harvestForest` command on a rival island SHALL be ignored.

#### Scenario: Demolishing a rival house

- **WHEN** the player demolishes a tile of a rival house
- **THEN** the house still exists and the tick emits no `buildingDemolished`

#### Scenario: Clearing a rival forest

- **WHEN** the player harvests a forest tile on a rival island
- **THEN** the tile is still forest
