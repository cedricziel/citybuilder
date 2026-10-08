## 1. M1 — Catalog, unlocks and ranges

- [x] 1.1 Tests-first: translate the research and buildings-and-construction scenarios, and the age-signatures scenarios "Renaissance start has three signatures", "Antiquity start has the monument", "Touching footprints", "Just out of range", "Smelters are workshops" and "Older building loads", into failing `CityCoreTests`. Confirm red.
- [x] 1.2 Implement to green: five `BuildingKind`s and catalog specs, stockpile capacities, `Tech.unlocks` for the era techs, `BuildingKind.isWorkshop`, `World.footprintDistance`, owner-scoped coverage queries, `PlacementRejection.alreadyBuilt` and the one-monument rule, `Building.projectStages` / `fuelled` / `commissionTicksLeft` with tolerant decoding (design D1–D3, D6, D12).

## 2. M2 — Workshops and fuel

- [x] 2.1 Tests-first: translate "Guild hall after Printing Press", "Farms are not workshops", the guild hall, fuel, steam engine, power plant and "Speed bonuses of different sources add up" scenarios, and the goods-and-production and economy scenarios. Confirm red.
- [x] 2.2 Implement to green: `FuelSpec` and `BuildingKind.fuel`, fuel supply through the supply carriers, `runSignatureSystem` (burns, `fuelRanOut`), per-tick active source list, workshop speed bonus in production (D4, D5).
- [x] 2.3 Add a tick budget test with 10 guild halls, 10 fuelled steam engines, 3 fuelled power plants, 40 sawmills and 40 houses; the mean tick stays inside the 100 ms budget of the 10 Hz simulation (CityCore had no tick performance test to extend).

## 3. M3 — Houses, monument and commissions

- [x] 3.1 Tests-first: translate "Houses above capacity shrink", the monument, tax and gallery scenarios, and the population-and-needs scenarios. Confirm red.
- [x] 3.2 Implement to green: `World.houseCapacity(of:)` with smoke and power, over-capacity shrinking, monument recipe and stage counting, `monumentCompleted`, supply and production skipping a finished monument, the tax bonus, `Command.commission`, commission countdown, `commissionStarted` / `commissionEnded`, inspired growth and tier timers (D6–D8).

## 4. M4 — Art

- [x] 4.1 Draw the five buildings with idle, construction and operational frames in `buildings.py`; add catalog entries; `make sprites-procedural`, `make sprites-verify` (D11).

## 5. M5 — Rendering and UI

- [x] 5.1 Tests-first: translate the rendering-2_5d and sprite-style-catalog scenarios into failing `CityRender2DTests` and the platform-shells scenarios into failing `CityUITests`. Confirm red.
- [x] 5.2 Implement to green: snapshot fields for stages, fuel, commission and house modifiers; monument stage frames; idle versus animated by state; smoky tint; range ring and highlight for placement and selection (D9).
- [x] 5.3 Implement to green: inspector sections, commission button, house notes and banners (D10).

## 6. M6 — Verification

- [ ] 6.1 Runtime check: start an Industrial sandbox, build a charcoal burner, a steam engine next to a sawmill and a house 3 tiles away; see the range rings while placing, the engine animate once fuelled, the sawmill's faster cycles in the inspector and the house's "Smoky" note and grey tint. Commission art at a gallery and watch the countdown. Build a monument and see its stage rise.
- [ ] 6.2 Run lint, format, `make test`, `make test-scenarios` and `openspec validate add-age-signatures --strict`.
