## 1. M1 — Island name (CityCore)

- [x] 1.1 Tests-first: translate `#### Scenario: Island name is deterministic per seed`, `#### Scenario: Same name persists across save/load`, and `#### Scenario: Different seeds yield different name distributions` into failing tests in `CityCoreTests`. Confirm red.
- [x] 1.2 Implement to green: add `name: String` to `Island`. World-gen seeds a name picker (constant 64-entry `nameTable` hashed by island center + seed). Codable round-trip preserves the name.
- [x] 1.3 Refactor under a green bar.

## 2. M2 — Per-island aggregate in WorldSnapshot (CityCore)

- [x] 2.1 Tests-first: translate `#### Scenario: IslandSummary aggregates warehouse and port stockpiles`, `#### Scenario: Producer internal stockpiles are excluded from the aggregate`, `#### Scenario: Empty island has zero stocks and zero capacity`, and `#### Scenario: tile-to-island lookup resolves containing island` into failing tests in `CityCoreTests`. Confirm red.
- [x] 2.2 Implement to green: introduce `IslandSummary { name, bounds, stockpile: [Good: Int], capacity: [Good: Int] }` and `WorldSnapshot.islandSummaries: [IslandID: IslandSummary]`. Add `WorldSnapshot.island(at: TileCoordinate) -> IslandID?` backed by a cached `tileToIsland` map built at snapshot construction.
- [x] 2.3 Refactor under a green bar.

## 3. M3 — Good icon generation (scripts)

- [x] 3.1 Extend `scripts/generate-sprites.swift` with `drawGoodIcon(_ good: Good)` helpers and main-script logic to emit `good-wood.png`, `good-planks.png`, `good-food.png` into `Resources/Icons.atlas/`. 24×24 PNGs, nearest-neighbor.
- [x] 3.2 Run the generator and commit the three PNGs.
- [x] 3.3 Tests-first (script harness): assert each emitted file exists, is 24×24, and is non-empty.

## 4. M4 — Sprite-asset-pipeline extension (CityRender2D)

- [x] 4.1 Tests-first: translate `#### Scenario: Sprite-name grammar accepts good- prefix` and `#### Scenario: SpriteAtlasRouting routes good- to Icons atlas` into failing tests.
- [x] 4.2 Implement to green: `SpriteAtlasRouting.iconsAtlasName = "Icons"`; routing function maps `good-*` to it. `SpriteName.validate` accepts the new prefix.

## 5. M5 — SwiftUI good-icon bridge (CityUI)

- [x] 5.1 Tests-first: translate `#### Scenario: Good icon loader resolves a known good`, `#### Scenario: Missing icon returns the SF Symbol fallback`, and `#### Scenario: Loaded image uses nearest-neighbor interpolation` into failing tests in `CityUITests`.
- [x] 5.2 Implement to green: `GoodIconLoader.image(for: Good) -> Image?` reads `Icons.atlas/good-*.png` from `Bundle.main`, returns SwiftUI `Image` with `.interpolation(.none)`. Fallback to `Image(systemName: "cube.fill")` on miss.

## 6. M6 — HUDViewModel currentIsland binding (CityUI)

- [x] 6.1 Tests-first: translate `#### Scenario: HUD reads current island from camera`, `#### Scenario: HUD is sticky over water`, `#### Scenario: HUD switches when camera enters another island`, and `#### Scenario: HUD is nil when camera has never been on an island` into failing tests in `CityUITests`.
- [x] 6.2 Implement to green: extend `HUDViewModel` with `currentIsland: IslandSummary?` (the sticky cache lives implicitly in this property — the apply loop refreshes it from the snapshot every tick and only swaps when the camera enters a new island). `apply(_:)` updates from `snapshot.island(at: camera.centerTile())`; falls back to the cached previous when over water.

## 7. M7 — HUD layout: island row + stocks chips (CityUI)

- [x] 7.1 Tests-first: translate `#### Scenario: Island name renders next to money and population`, `#### Scenario: Stocks row shows goods present on the island`, `#### Scenario: Empty island hides the stocks row`, and `#### Scenario: Goods with zero stock and zero capacity are omitted` into failing tests in `CityUITests` (view-model assertions; SwiftUI rendering goes through preview/snapshot tests where the existing pattern allows).
- [x] 7.2 Implement to green: extend `HUDFrameView` with an island-name badge and a horizontal stocks row. Each chip is `Image (good icon) + Text (count)`. Hide chip for goods with zero stock AND zero capacity. Hide the whole row when `currentIsland == nil`.

## 8. M8 — Camera centerTile() helper (CityCore)

- [x] 8.1 Tests-first: translate `#### Scenario: Camera centerTile rounds to integer coords` into a failing test in `CityCoreTests`.
- [x] 8.2 Implement to green: `Camera.centerTile() -> TileCoordinate` returns the rounded tile-space center.
- [x] 8.3 (May already exist if `add-spatial-audio` lands first — confirm and dedupe.) — confirmed not present in current tree; added here.

## 9. M9 — Project.yml wiring + asset bundling

- [x] 9.1 Register `Resources/Icons.atlas/` as a resource path on both `CitybuilderiOS` and `CitybuilderMac` targets in `project.yml`. Exclude `_candidates/` consistent with the existing audio pattern.
- [x] 9.2 Run `make generate`. Verify xcodebuild succeeds for both app targets on macOS and iOS Simulator.

## 10. M10 — Polish + docs

- [x] 10.1 README: extend with an "Island HUD" section covering the panel, the sticky-over-water behavior, the name table, and how to add a new good icon.
- [x] 10.2 Final `make test && make lint && make format`.
- [ ] 10.3 Visual smoke check on iPad Simulator: place a warehouse, deposit wood via spawn/test fixture, see the HUD update. — DEFERRED (no simulator access in this environment; `add-build-materials-cost` will naturally exercise it).
- [ ] 10.4 Hardware playtest on iPad + Mac. — DEFERRED (requires devices).
