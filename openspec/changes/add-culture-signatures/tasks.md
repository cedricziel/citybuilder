## 1. M1 — Catalog, culture rule and served luxury

- [x] 1.1 Tests-first: translate the buildings-and-construction and goods-and-production scenarios, and the culture-signatures scenarios "Forum in an Antiquity start", "No caravanserai in the north", "Forum served wine" and "Older building loads", into failing `CityCoreTests`. Confirm red.
- [x] 1.2 Implement to green: four `BuildingKind`s with catalog specs, `culture` and `fuel`, stockpile capacities, `Good.basePrice` for the culture goods (the whole table if `add-rival-trade` hasn't landed), `Building.exportGood` with tolerant decoding (design D1–D3, D8, D11).

## 2. M2 — Mead hall, forum and temple garden

- [x] 2.1 Tests-first: translate "Two forums count once", the mead hall, forum and temple garden scenarios, and the economy scenario "Forum and monument" and the research scenario. Confirm red.
- [x] 2.2 Implement to green: owner-scoped coverage at the best rate, mead hall upkeep sharing before difficulty scaling, forum tax inside the house tax (before the monument bonus), temple knowledge on the resident knowledge interval (D3–D6).

## 3. M3 — Caravanserai

- [x] 3.1 Tests-first: translate the export and caravan scenarios and "Caravan income is not tax". Confirm red.
- [x] 3.2 Implement to green: `Command.setExport`, export supply with the 8-unit cap and the 10-unit island reserve, caravans in `runSignatureSystem` after fuel burns, sale order, revenue to the owner, `WorldEvent.caravanSold` (D7).

## 4. M4 — Art

- [x] 4.1 Draw the four buildings in their culture styles with idle, construction and operational frames in `buildings.py`; add catalog entries; `make sprites-procedural`, `make sprites-verify` (D10).

## 5. M5 — Rendering and UI

- [x] 5.1 Tests-first: translate the rendering-2_5d and sprite-style-catalog scenarios into failing `CityRender2DTests` and the platform-shells scenarios into failing `CityUITests`. Confirm red.
- [x] 5.2 Implement to green: ring radii for the three ranged kinds, served-state animation, inspector sections, export picker, last-caravan line and the fuel-good banner text (D9).

## 6. M6 — Verification

- [ ] 6.1 Runtime check: in a Middle Eastern sandbox, build a caravanserai, export bread, and watch caravans sell and the balance rise; add a coffee chain and see caravans double. In a Mediterranean sandbox, place a forum and see its ring and the tax rise. Run a Middle Eastern game exporting tools with coffee for 6,000 ticks and record the caravan income.
- [ ] 6.2 Run lint, format, `make test`, `make test-scenarios` and `openspec validate add-culture-signatures --strict`.
