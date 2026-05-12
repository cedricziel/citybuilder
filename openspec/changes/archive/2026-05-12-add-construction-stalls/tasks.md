## 1. M1 — Building.materialsDelivered + ConstructionState (CityCore)

- [x] 1.1 Tests-first: translate `#### Scenario: Fresh Building defaults to actively constructing`, `#### Scenario: ConstructionState round-trips through Codable`, and `#### Scenario: materialsDelivered round-trips through Codable` into failing tests in `CityCoreTests`. Confirm red.
- [x] 1.2 Implement to green: add `materialsDelivered: [Good: Int]` (default `[:]`) and `constructionState: ConstructionState` (default `.actively`) to `Building`. Introduce `enum ConstructionState: String, Codable, Sendable { case actively; case waitingForMaterials }`.
- [x] 1.3 Refactor under a green bar.

## 2. M2 — canPlace allow-when-production-exists rule (CityCore)

- [x] 2.1 Tests-first: translate `#### Scenario: Placement allowed when warehouses are short but producers can supply`, `#### Scenario: Placement rejected when neither warehouses nor producers can supply`, and `#### Scenario: Production check considers only operational producers on the placement island` into failing tests. Confirm red.
- [x] 2.2 Implement to green: extend `World.canPlace` with the per-good check from design D2. Use a `producesGood(island:good:)` helper that returns whether any operational producer on the island outputs the good.

## 3. M3 — applyPlace partial deduction + waiting state (CityCore)

- [x] 3.1 Tests-first: translate `#### Scenario: applyPlace deducts all available and seeds materialsDelivered`, `#### Scenario: applyPlace marks building waitingForMaterials when partially supplied`, `#### Scenario: applyPlace marks building actively when fully supplied`, and `#### Scenario: applyPlace emits constructionWaitingForMaterials when partial` into failing tests. Confirm red.
- [x] 3.2 Implement to green: in `applyPlace`, take available materials from island warehouses, set `materialsDelivered` to what was taken, and decide the substate by comparing delivered vs. required. Emit the appropriate event.

## 4. M4 — Construction-site delivery carrier mission (CityCore + warehouses)

- [x] 4.1 Tests-first: translate `#### Scenario: Carrier mission supports deliverToConstructionSite`, `#### Scenario: Producer prioritizes waiting construction site over warehouse`, and `#### Scenario: Construction-site delivery increments materialsDelivered on arrival` into failing tests. Confirm red.
- [x] 4.2 Implement to green: add `Carrier.Mission.deliverToConstructionSite(good:amount:fromProducer:toBuilding:)` — v0 routes producer→site directly, so the source role is `fromProducer` matching the existing `.deliver` mission shape. Extend `spawnCarriersFromProducers` to prefer waiting sites on the producer's island; extend `applyCarrierArrival` to bump `materialsDelivered` and flip the substate.

## 5. M5 — Waiting → actively transition on full delivery (CityCore)

- [x] 5.1 Tests-first: translate `#### Scenario: Building flips to actively when materialsDelivered satisfies materialCost`, `#### Scenario: constructionStarted event fires on the flip tick`, and `#### Scenario: Waiting building does not advance ticksSincePlacement` into failing tests. Confirm red.
- [x] 5.2 Implement to green: in `applyCarrierArrival` (for the new mission), after incrementing `materialsDelivered`, check if all costs are met. If so, flip `constructionState = .actively` and emit `constructionStarted`. In `advanceBuildings`, skip the increment for waiting buildings.

## 6. M6 — Ghost preview status (CityUI + CityRender2D)

- [x] 6.1 Tests-first: translate `#### Scenario: Cost status is ok when have >= need`, `#### Scenario: Cost status is queueable when have < need but producers supply`, `#### Scenario: Cost status is blocked when no path to supply`, and `#### Scenario: Placement allowed when at least one good is queueable and none are blocked` into failing tests in `CityUITests`.
- [x] 6.2 Implement to green: extend the `costBreakdown` payload from `add-build-materials-cost` with `CostStatus` per good. `CostBreakdownView` renders orange chips for `.queueable` and red chips for `.blocked`.

## 7. M7 — Save migration (CityCore + CityPersistence)

- [x] 7.1 Tests-first: translate `#### Scenario: v2 save with constructing buildings migrates to actively with full materialsDelivered`, `#### Scenario: v2 save with operational buildings ignores new fields`, and `#### Scenario: v3 save round-trips through Codable` into failing tests.
- [x] 7.2 Implement to green: bump save schema to v3. v2 → v3 migration seeds `materialsDelivered = materialCost` and `constructionState = .actively` for any building with `state == .constructing`. v3 → v2 is not supported (per usual rule).

## 8. M8 — Waiting badge sprite + render (CityRender2D)

- [x] 8.1 Tests-first: translate `#### Scenario: Waiting building shows the waiting badge`, `#### Scenario: Actively constructing building shows no badge`, and `#### Scenario: Operational building shows no badge` into failing tests in `CityRender2DTests`.
- [x] 8.2 Implement to green: extend `scripts/generate-sprites.swift` with `drawWaitingBadge()` emitting `Resources/Buildings.atlas/overlay-waiting-materials.png` (16×16, clock-face pixel art). `IsoWorldScene.makeBuildingNode` attaches the badge as a child node when `constructionState == .waitingForMaterials`.

## 9. M9 — Polish + docs

- [x] 9.1 README: extend with a "Construction stalls" section covering the queueable preview, the waiting badge, and the carrier prioritization rule.
- [x] 9.2 Final `make test && make lint && make format`.
- [ ] 9.3 Visual playtest: place a sawmill before the lumberjack has produced any wood; verify the waiting badge appears, then the building auto-starts when wood arrives. — DEFERRED (interactive).
- [x] 9.4 Audit `add-build-materials-cost`'s scenarios to confirm none regress (especially the "placement rejected when island is short" scenario, which now becomes specifically "rejected when island is short AND no producer supplies"). Confirmed via the still-green MaterialPlacementTests — the "Placement rejected when island is short" scenario keeps the `.insufficientMaterials` result because the test fixture has no producer.
