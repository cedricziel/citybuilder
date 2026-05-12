## ADDED Requirements

### Requirement: Construction substate

`Building` SHALL carry a `constructionState: ConstructionState` field with values `.actively` and `.waitingForMaterials`. The field is meaningful only when `Building.state == .constructing`; on `.operational` buildings its value is ignored. While `.waitingForMaterials`, the building's `ticksSincePlacement` MUST NOT advance — construction time only accrues while `.actively`.

#### Scenario: Fresh Building defaults to actively constructing

- **WHEN** a fully-supplied building is placed
- **THEN** its `constructionState` is `.actively`

#### Scenario: ConstructionState round-trips through Codable

- **WHEN** a `Building` is encoded and decoded
- **THEN** the decoded `constructionState` equals the encoded value

#### Scenario: Waiting building does not advance ticksSincePlacement

- **WHEN** a `.waitingForMaterials` building exists at the start of tick T and the next tick advances
- **THEN** the building's `ticksSincePlacement` at end-of-tick T is unchanged

### Requirement: Materials-delivered tracking

`Building` SHALL carry a `materialsDelivered: [Good: Int]` field tracking the per-good amount of construction materials already at the site. Construction MAY only transition to `.actively` once `materialsDelivered[good] >= materialCost[good]` for every good in the recipe.

#### Scenario: materialsDelivered round-trips through Codable

- **WHEN** a `Building` is encoded and decoded
- **THEN** the decoded `materialsDelivered` equals the encoded map

#### Scenario: Building flips to actively when materialsDelivered satisfies materialCost

- **WHEN** a carrier delivers the last unit of a required good and `materialsDelivered` then meets `materialCost` for every good
- **THEN** the building's `constructionState` flips to `.actively` on that tick

### Requirement: canPlace allowed when production exists

`World.canPlace(_:at:)` SHALL allow placement when, for every required good, either (a) the island's warehouses currently hold enough, OR (b) at least one operational producer on the island outputs that good. If neither holds for any required good, placement MUST be rejected with `.insufficientMaterials([Good: Int])` listing the per-good shortfall.

#### Scenario: Placement allowed when warehouses are short but producers can supply

- **WHEN** the player attempts to place a sawmill (cost: 4 wood + 1 plank) on an island whose warehouses hold 0 wood + 0 planks, but has a lumberjack hut producing wood and an existing sawmill producing planks
- **THEN** `canPlace` returns `.allowed`

#### Scenario: Placement rejected when neither warehouses nor producers can supply

- **WHEN** the player attempts to place a sawmill on an island with no wood, no planks, and no producer that makes wood or planks
- **THEN** `canPlace` returns `.rejected(.insufficientMaterials(...))`

#### Scenario: Production check considers only operational producers on the placement island

- **WHEN** the player attempts to place a sawmill on Island #1, and Island #2 has the only operational lumberjack
- **THEN** `canPlace` rejects (Island #2's producer doesn't count for an Island #1 placement)

### Requirement: applyPlace partial deduction and substate seeding

`World.applyPlace` SHALL deduct as much of the required materials as the island's warehouses can supply at placement time, seeding `Building.materialsDelivered` with what was actually withdrawn. If the deduction is incomplete (any good's delivered < cost), the building's `constructionState` MUST be set to `.waitingForMaterials` and `World` MUST emit `WorldEvent.constructionWaitingForMaterials(building:, missing:)` describing the per-good shortfall. If the deduction is complete, the building's `constructionState` MUST be `.actively` and the existing `WorldEvent.materialsDeducted` MUST fire.

#### Scenario: applyPlace deducts all available and seeds materialsDelivered

- **WHEN** a sawmill (cost: 4 wood + 1 plank) is placed and the island warehouses hold 2 wood + 1 plank
- **THEN** the placed building has `materialsDelivered = [.wood: 2, .planks: 1]`

#### Scenario: applyPlace marks building waitingForMaterials when partially supplied

- **WHEN** the same placement above completes
- **THEN** the placed building's `constructionState` is `.waitingForMaterials`

#### Scenario: applyPlace marks building actively when fully supplied

- **WHEN** the warehouses hold 5 wood + 2 planks at placement time
- **THEN** the placed building's `constructionState` is `.actively` and `materialsDelivered` matches the recipe exactly
