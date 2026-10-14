## 0. Prerequisite

- [x] 0.1 Confirm `game-data-codegen` has landed through its M3 (catalog generation from packs) on `main`, and rebase this change on it. The forester and the hut's empty `materials` are pack edits, not Swift catalog edits.

## 1. M1 — Renewable wood in the simulation

- [x] 1.1 Tests-first: translate every scenario in `specs/forestry`, `specs/buildings-and-construction` and `specs/warehouses-and-logistics` into failing swift-testing tests in `CityCoreTests`. Update the existing "first lumberjack placement consumes starter wood" test to the new outcome. Audit the material-placement and construction-delivery tests for any that use a lumberjack hut to exercise wood deduction, and switch them to a farm. Add a test that a saved `waitingForMaterials` lumberjack hut starts construction on the next tick (design Migration Plan). Confirm red.
- [x] 1.2 Content: in the core pack, add the `forester` building (2×2, cost 60, no upkeep, `buildTicks: 20`, `plantTicks: 40`, no `materials`, `effect: code`, no recipe, no `storage`) and empty the lumberjack hut's `materials`. Run `make gamedata` and commit the regenerated Swift. Add `Resources/Sprites.style/catalog/building-forester.md` (a procedural entry) and generate its atlas with `make sprites-procedural`.
- [x] 1.3 Implement to green: `buildings-and-construction` / Wood producers cost no materials and Town center starter inventory. Drop the rival-only hut exemption in `materialCost(of:for:)`, and let `advanceBuildings` start a waiting site whose material cost is already covered (design Migration Plan).
- [x] 1.4 Implement to green: `forestry` / Forester plants forest. Add `runForestrySystem` between production and carriers (design D3), foresters in entity order, row-major scan of open grass on the owner's islands (design D2), cycle progress in `productions`, and a `forestPlanted` `WorldEvent` with its CLI JSON encoding.
- [x] 1.5 Implement to green: `forestry` / Foresters plant at half pace in winter. Add `.forester` to `World.seasonalCrops` and apply the same half-pace rule in the forestry system.
- [x] 1.6 Implement to green: `forestry` / Trees and open ground in reach. Add `World.catchmentCount(kind:anchor:owner:)` and `WorldSnapshot.catchments` (design D5).
- [x] 1.7 Implement to green: `warehouses-and-logistics` / Buildings report why they are idle. Add `BuildingIssue.noRoomToPlant`, check the forester first in `buildingIssues()`, and skip road and storage checks for it.
- [x] 1.8 Refactor under a green bar: share one catchment visitor between harvest, planting and counting; keep `Systems.swift` under the SwiftLint length limits by putting forestry in `Systems/ForestrySystem.swift`.
- [x] 1.9 Run `make test-scenarios` and confirm no uncovered scenario in `forestry`, `buildings-and-construction` or `warehouses-and-logistics` from this change. Run `scripts/check-no-apple-ui-imports.sh`.

## 2. M2 — Rivals replant

- [x] 2.1 Tests-first: translate the `rival-towns` scenarios "Rival replants beside its hut", "Rival forester needs open ground beside a hut" and "Rival forester overlaps a hut" into failing tests using `RivalTestSupport`. Re-run "Rival buildings touch a road" and the rival determinism tests. Confirm red.
- [x] 2.2 Implement to green: `rival-towns` / Rival build order. Add the forester threshold rule after the hut rule, count every hut for it, and make it cost no materials.
- [x] 2.3 Implement to green: `rival-towns` / Rival town plan. Add the forester slot score (open grass shared with a rival hut catchment, at least 4, the same block penalty as huts) on top of `hutSlot`'s block search (design D6).
- [x] 2.4 Re-run the headless playtest from design "Playtest evidence" (single island seed 0, archipelago seed 7, Guild Town; 36,000 ticks each) with a forester step after each hut. Record in this file the year each run first reaches 20 citizens, whether any run soft-locks or goes bankrupt, and both rivals' residents in 1215. If a run still runs out of wood, tune the forester cycle in the pack and re-run.
  - Result (36,000 ticks each, harness not committed, re-run after the per-hut forester fix with the same numbers). With a forester after each hut, all three runs go bankrupt in 1202. Single island seed 0 and Guild Town (the same map) peak at 4 residents in 1201; archipelago seed 7 never houses anyone. No run reaches 20 citizens. Huts never run bare: the forest in their reach stays stocked. The wood stock still stays at 0, because the sawmill consumes every log, and planks pile up to 40 on the single island and 31 on the archipelago because the bot cannot spend them. Rivals on archipelago seed 7 in 1215: Lowtide 0 residents ($-12) and Stoneholm 0 residents ($11). Both were broke by 1201, so their foresters did not help them.
  - Control run without the bot's forester step: single island seed 0 and Guild Town (the same map) survive at 7 to 10 residents with $5,923 by 1215, with every hut bare. Archipelago seed 7 still goes bankrupt in 1202.
  - Forests in reach no longer run out, so the forester cycle was not retuned. Money is now the binding constraint. The likely cause is that $60 per forester comes out of a thin first-year treasury, but the harness does not isolate it. `add-town-market` (PR #36) addresses the money and food side; the designer's emulation of forester plus market reached 70 residents.
- [x] 2.5 Refactor under a green bar.
- [x] 2.6 Run `make test-scenarios` and confirm no uncovered scenario in `rival-towns` from this change. Confirm the macOS and Linux `DeterminismFixture` outputs still match in CI. The forester acceptance check is `determinismFixtureWorldPlantsForest` in `RivalForestryTests`: the fixture world (archipelago, seed `0xC17B`) holds at least one forester and plants at least one tree within 6,000 ticks, so the cross-platform comparison exercises forestry.

## 3. M3 — Show the player where wood comes from

- [x] 3.1 Tests-first: translate the `platform-shells` scenarios "Hut key lines show trees in reach", "Forester key lines show open grass", "Problem text for every building issue" (new wording), "Tool strip hint shows trees at the candidate site" and "Tool strip hint without a candidate site" into failing `CityUITests`. Confirm red.
- [x] 3.2 Implement to green: `platform-shells` / Inspector callout. Update `InspectorViewModel.problemText` for both forestry issues.
- [x] 3.3 Implement to green: `platform-shells` / Forestry in the inspector and while placing. Add the "Trees in reach" and "Open grass in reach" key lines from `WorldSnapshot.catchments`, and the count suffix on the tool strip hint for the armed hut or forester at its candidate anchor (design D5).
- [x] 3.4 Add the forester to the build palette's gather category next to the lumberjack hut, with the short name "Forester".
- [ ] 3.5 Check in the iOS Simulator with the verify skill: place a hut and a forester, watch grass turn to forest beside the hut, and read the inspector and tool strip lines.
  - iPhone 17 Pro, single island seed 0: the forester sits after the lumberjack in the Gather drawer. A hut placed on grass beside it read "Trees in reach: 0" after "Road: none". The forester read "Open grass in reach: 10" and then 6 about 25 seconds later, and the hut then read "Trees in reach: 7". On iPhone the tool strip hides while a placement is pending and a tap sets no hover, so the hint never shows a count there; it reads "Tap or drag to place lumberjack".
- [x] 3.6 Refactor under a green bar.
- [x] 3.7 Run `make test-scenarios` and confirm no uncovered scenario in `platform-shells` from this change.
