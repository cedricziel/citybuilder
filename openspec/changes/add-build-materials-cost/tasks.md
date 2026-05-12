## 1. M1 — BuildingSpec.materialCost (CityCore)

- [ ] 1.1 Tests-first: translate `#### Scenario: BuildingSpec carries a material cost per good`, `#### Scenario: Default material cost is empty`, and `#### Scenario: Road and town center have no material cost` into failing tests in `CityCoreTests`. Confirm red.
- [ ] 1.2 Implement to green: add `materialCost: [Good: Int]` to `BuildingSpec` with default `[:]`. Update the catalog entries per the recipe table in design D2.
- [ ] 1.3 Refactor under a green bar.

## 2. M2 — canPlace gates on material availability (CityCore)

- [ ] 2.1 Tests-first: translate `#### Scenario: Placement allowed when island has enough materials`, `#### Scenario: Placement rejected when island is short`, `#### Scenario: Rejection reason names the shortfall per good`, and `#### Scenario: Free-of-materials building (road) ignores material check` into failing tests. Confirm red.
- [ ] 2.2 Implement to green: extend `World.canPlace` with a third pass that consults `WorldSnapshot.islandSummaries[islandID].stockpile` (or equivalent on-`World` lookup at placement time). Add `PlacementResult.RejectionReason.insufficientMaterials([Good: Int])` carrying per-good shortfall.

## 3. M3 — Deterministic multi-warehouse deduction (CityCore)

- [ ] 3.1 Tests-first: translate `#### Scenario: Deduction draws from single warehouse when sufficient`, `#### Scenario: Deduction splits across multiple warehouses when no single one has enough`, `#### Scenario: Deduction is deterministic across replays`, and `#### Scenario: Deduction order is shortest road-distance first` into failing tests.
- [ ] 3.2 Implement to green: `World.applyPlace` calls a new private `deductMaterials(cost:forBuildingAt:onIsland:)` that iterates the island's goods-buffer buildings sorted by road-distance ascending (tiebreak EntityID ascending) and withdraws per-good with the greedy rule described in design D3.

## 4. M4 — Materials-deducted event (CityCore, world-events delta)

- [ ] 4.1 Tests-first: translate `#### Scenario: Successful placement emits materialsDeducted` and `#### Scenario: materialsDeducted carries the per-good amounts` into failing tests.
- [ ] 4.2 Implement to green: add `WorldEvent.materialsDeducted(building: EntityID, cost: [Good: Int])` and emit it from `applyPlace` after deduction. Sort key uses the building's `EntityID` (primary) and the event's case ordinal (secondary) per the existing stable-sort rule.

## 5. M5 — Town center starter inventory (CityCore)

- [ ] 5.1 Tests-first: translate `#### Scenario: Fresh-world town center holds starter goods`, `#### Scenario: Starter goods are part of the island stockpile aggregate`, and `#### Scenario: First lumberjack placement consumes starter wood` into failing tests.
- [ ] 5.2 Implement to green: when world-gen places the initial town center (or `IslandGenerator` produces it), seed its `Stockpile` with **4 wood + 2 planks**. The town center is a goods-buffer for placement deduction.

## 6. M6 — Ghost preview cost breakdown (CityUI + CityRender2D)

- [ ] 6.1 Tests-first: translate `#### Scenario: Ghost preview surfaces material cost when build tool is armed`, `#### Scenario: Cost breakdown reads available stock from current island`, `#### Scenario: Shortfall good highlights red`, and `#### Scenario: Free-of-materials tool has no cost row` into failing tests in `CityUITests`.
- [ ] 6.2 Implement to green: extend `GameSession.ghostState()` to attach `costBreakdown: [Good: (need: Int, have: Int)]?`. Add a `CostBreakdownView` below the build palette that renders one chip per required good, with red text when `have < need`.

## 7. M7 — Per-island stockpile read path for canPlace (CityCore)

- [ ] 7.1 Tests-first: translate `#### Scenario: canPlace consults the same island as the placement anchor` and `#### Scenario: Materials on a different island do not count` into failing tests.
- [ ] 7.2 Implement to green: ensure `canPlace` derives the island from the anchor (`World.islandID(at:)` — exists post-archipelago) and consults only that island's warehouses + ports for material availability.

## 8. M8 — Update existing tests for cost-gated placement

- [ ] 8.1 Audit existing placement tests in `CityCoreTests`, `CityUITests`. Tests that rely on placing buildings without materials must either: (a) seed warehouses with the needed goods first, or (b) use the road/town center kinds (free of materials), or (c) update to assert the new rejection path.
- [ ] 8.2 Confirm `make test` passes across every package.

## 9. M9 — Polish + docs

- [ ] 9.1 README: add a "Material costs" section pointing at the catalog table and explaining the bootstrap loop.
- [ ] 9.2 Final `make test && make lint && make format`.
- [ ] 9.3 Visual playtest on iPad simulator: place a lumberjack hut, watch wood accumulate, place a sawmill, etc. — DEFERRED (interactive).
- [ ] 9.4 Tune the recipe numbers based on first-hour play feel. — DEFERRED (gated on playtest).
