## ADDED Requirements

### Requirement: Construction lifecycle events

`WorldEvent` SHALL gain two cases describing the materials-driven construction lifecycle:

- `constructionWaitingForMaterials(building: EntityID, missing: [Good: Int])` — emitted by `applyPlace` when a placed building's materials are not fully delivered.
- `constructionStarted(building: EntityID)` — emitted when a waiting building's `materialsDelivered` first satisfies its `materialCost`, flipping `constructionState` from `.waitingForMaterials` to `.actively`.

Both events MUST follow the existing stable sort by primary `EntityID` and case ordinal. Replay determinism MUST be preserved.

#### Scenario: constructionWaitingForMaterials emitted on partial placement

- **WHEN** a sawmill is placed on an island whose warehouses cannot fully cover its material cost
- **THEN** the tick's events include exactly one `constructionWaitingForMaterials` for that building with `missing` set to the per-good shortfall

#### Scenario: constructionStarted emitted on the flip tick

- **WHEN** the last required material arrives at a waiting building on tick T
- **THEN** tick T's events include exactly one `constructionStarted` for that building

#### Scenario: Neither event emitted for instant-deduct placement

- **WHEN** a building is placed and the island's warehouses fully cover its material cost in one deduction
- **THEN** the tick's events include `materialsDeducted` (from `add-build-materials-cost`) but neither `constructionWaitingForMaterials` nor `constructionStarted`
