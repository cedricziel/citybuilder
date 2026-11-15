# M1: generated maps, shippable on their own

Every test is written first and seen to fail. Test names are `@Test("scenario: <scenario title>")` for each scenario in this change's specs. Run CityCore tests with `xcrun swift test --package-path Packages/CityCore --filter <Suite>`, never bare `swift`. "Design Dn" refers to `design.md`.

## 1. Pin the classic maps before touching anything

- [ ] 1.1 On a fresh branch from `main`, add `Packages/CityCore/Tests/CityCoreTests/MapHashSupport.swift` with `terrainHash(_ grid: [TerrainType]) -> UInt64`: FNV-1a 64 (offset `0xcbf29ce484222325`, prime `0x100000001b3`) over the UTF-8 bytes of the raw values joined with `\n`.
- [ ] 1.2 Add `ClassicMapPinTests.swift`: record the terrain hash and the island list (ids, tile counts, bounds) of `World.newGame()`, `World.newGame(layout: .archipelago, seed: 0)` and `World.newGame(layout: .archipelago, seed: 0xC17B)` on `main` as constants. Scenarios "A new game without map settings is classic" and "The classic island list is unchanged". Commit this before any production change, so it is green on `main`.

## 2. Map settings

- [ ] 2.1 Tests first: "Generated map sides follow the size" (it fails until 3.x lands; mark it `.disabled` until then if needed to keep commits green), "Map settings persist across save/load".
- [ ] 2.2 Add `Packages/CityCore/Sources/CityCore/MapSettings.swift` with `MapStyle`, `MapSize` and `MapSettings` as in design D1, and `side(for:)` per the D2 table.
- [ ] 2.3 In `World.swift`, add `map: MapSettings` (default `.classic`) and `mapAttempt: Int?`, decoded with `decodeIfPresent` following the file's existing pattern for new fields. Don't bump `SaveFile.currentVersion`.
- [ ] 2.4 Don't add a profile hook; profiles belong to `add-island-specialization` (design D9). If that change is already on `main`, add the generated-archipelago profile test from D9 under task 5.
- [ ] 2.5 Add `map: MapSettings = .classic` as the last parameter of `World.newGame(layout:seed:…)`. The classic branch stays exactly as it is today and sets `world.map = .classic`.

## 3. Generator

- [ ] 3.1 Tests first in `SeededMapGeneratorTests.swift`: "Different seeds give different outlines", "Outlines are not ellipses", "Generated islands have no lakes and no islets", "The home island covers the map's centre", "Island count follows the settings", "The sea is one body", "Islands keep a channel between them", "Shares are counted", "Mountains stay inland", "Single-island layout deterministic per seed" and "Archipelago layout deterministic per seed" (update both to pass map settings) and "Generated islands carry a climate". Scenario tests that inspect generator terrain call `SeededMapGenerator.terrain(…)` directly. Add `SeededMapGenerator.blueprints(…)` as `internal` for the ellipse test.
- [ ] 3.2 `Packages/CityCore/Sources/CityCore/SeededIslands/MapHash.swift` and `ValueNoise.swift` (design D3), with unit tests for known lattice values and that `fbm` stays in 0…4095.
- [ ] 3.3 `SeededIslands/IslandShaper.swift`: raw mask, two majority passes, spurs and notches, largest component, lake fill, minimum size (design D4); then beach, mountain and forest by count (design D6). Return nil on a failed minimum size.
- [ ] 3.4 `SeededIslands/ArchipelagoPlanner.swift`: the single-island blueprint and the archipelago placement with the radius table, 200 tries per island and the RNG draw order (design D5). Return nil when an island can't be placed.
- [ ] 3.5 `SeededIslands/SeededMapGenerator.swift`: `static func terrain(layout:map:seed:attempt:) -> (grid: [TerrainType], width: Int, height: Int)?` built from the planner and shaper, with `attemptSeed` as in design D3.
- [ ] 3.6 Measure in release on the dev Mac: worst-case and mean `World.newGame` time over seeds 0 ..< 200 for the Medium single island and the Medium and Large archipelago with 5 and 7 islands. Put the numbers in the PR. Over 1.5 s worst case → open the M2 follow-up for an off-main-actor commit (design, Risks).
- [ ] 3.7 Extend the `tick_float_ban` rule's `included` in `.swiftlint.yml` to `Packages/CityCore/Sources/CityCore/(Systems|SeededIslands)/.*\.swift`. Run `make lint`.

## 4. Validation, retry and fallback

- [ ] 4.1 Tests first in `MapValidatorTests.swift`: "The validator catches an unfair start", "The validator catches a split sea", "The validator catches a missing port site", "A failing attempt retries with the next one", "Eight failing attempts fall back to the classic map". For the retry tests, give `World.newGame`'s generated path an internal seam: a `terrain` closure parameter on an internal overload, defaulting to `SeededMapGenerator.terrain`.
- [ ] 4.2 Extract `World.hasNearMineSite(besideTownCenterAt:island:tileToIsland:)` from the early-return guard of `raiseStarterMineSite` in `World+StartSites.swift`, and make `raiseStarterMineSite` call it. A pure refactor: `StarterMineSiteTests` and `ClassicMapPinTests` stay green unchanged.
- [ ] 4.3 `SeededIslands/MapValidator.swift` with `MapCheckFailure` and `failures(in:)`, checks 1 to 7 of design D7. Port check: on a probe copy with every `Tech` marked researched, scan anchors on the town center's island in row-major order and stop at the first with `siteRejection(.port, …) == nil` within Chebyshev 40.
- [ ] 4.4 The generated branch of `World.newGame`: 8 attempts, validate, then the classic fallback, recording `map` and `mapAttempt` (design D7). Seasonal events and other `newGame` options apply to the returned world exactly as on the classic path.
- [ ] 4.5 Tests: "Fewer islands seat fewer rivals", "Generated starts do not depend on difficulty".
- [ ] 4.6 Check by hand once, then note it in the PR: build a generated save on this branch, check out `main`, and load it with `SaveStore`. It must load, because the unknown `map` key is ignored and terrain is stored (design, Migration Plan).

## 5. Property tests, determinism and rendering

- [ ] 5.1 `GeneratedFairStartPropertyTests.swift`: "Generated maps keep fair starts across 200 seeds" (`.serialized`, `arguments: Array(UInt64(0) ..< 200)`). It asserts each condition directly: `startArea(…).isFair`, `hasNearMineSite`, a port anchor scan, a water flood fill. It does not call `MapValidator`. Print one `MAPGEN_SWEEP` line per world (design D12). If the debug run takes over 120 s, apply the D13 split and say so in the PR. Also "Every size and island count passes" (seeds 0 ..< 20 × 3 sizes × {single island, 3, 4, 5, 6, 7}).
- [ ] 5.2 "Generated terrain is pinned": record the two golden hashes after the first green run.
- [ ] 5.3 `Packages/CityRender2D/Tests`: for 20 generated maps (both layouts, Medium), every non-nil `TerrainTransitionMap.transition(at:)`'s `assetName` and seasonal variants exist in the bundled atlas, the same way the existing atlas tests look names up.
- [ ] 5.4 Measure `GroundMacroField` build time and memory for the Large archipelago on the Mac. Put the numbers in the PR. No change is expected (design D10).
- [ ] 5.5 `DeterminismFixture/main.swift`: add `generated` to `Fixture` (design D13) and tick it like the others. Test "Determinism gate covers map generation": a CityCore test that builds the same world the fixture does and asserts it records a generated style and a non-nil attempt. The macOS and Linux CI jobs do the byte comparison.

## 6. New Game dialog

- [ ] 6.1 Tests first in `Packages/CityUI/Tests/CityUITests/NewGameDialogTests.swift`: "Map choice reaches the world", "Classic starts the classic map", "Islands picker only for a generated archipelago", "Scenario mode locks the map to Classic", "The dialog opens with a random seed", "Map labels are translated" (read the catalog strings through `GameText` with the German locale, the way the existing localization tests do). Update existing dialog tests that assumed the Default seed on open.
- [ ] 6.2 `NewGameDialogViewModel`: `MapChoice`, `mapChoice = .medium`, `islandCount = 5`, `isMapLocked`, `showsIslandPicker`, `mapSettings`, the random seed in `init` (when no `seedMode` is passed) and in `cancel()`, and sandbox `commit()` passing `map:` (design D8).
- [ ] 6.3 `NewGameDialogView.layoutSection`: Map `.menu` picker (`newGame.map`), Islands `.menu` picker (`newGame.islands`) and the hint footnote. Use only the components the section already uses.
- [ ] 6.4 Add the eight keys of design D8 to `Packages/CityUI/Sources/CityUI/Resources/Localizable.xcstrings` with `de` marked `translated`. Run `make l10n-check`.
- [ ] 6.5 Confirm that `design/web` has no New Game dialog component. If it does, update it to match and keep `npm run typecheck` and `npm run build` green.

## 7. Wrap up M1

- [ ] 7.1 Run the touched suites (`ClassicMapPinTests`, `SeededMapGeneratorTests`, `MapValidatorTests`, `GeneratedFairStartPropertyTests`, `FairStartSiteTests`, `StarterMineSiteTests`, `WorldLayoutTests`, `IslandNameTests`, `TerrainDirectiveTests`, CityUI `NewGameDialogTests`), `make lint`, `make l10n-check`, and `openspec validate add-seeded-islands --strict`.
- [ ] 7.2 Ask the orchestrator for the sweep slot, and run the classic release sweeps (`scripts/sweeps/run-release-sweeps.sh`). Their lines must be byte-identical to the last baseline (design D12). If no slot is free before merge, run the `SWEEP_SEEDS=1` smoke run and say in the PR that the full classic run is still owed.
- [ ] 7.3 PR against `main`: `## Design` "none: no significant visual change; two pickers and a hint in an existing dialog section"; `## Design system` "none" with the reason from 6.5. Include the 3.6 and 5.4 numbers and the `MAPGEN_SWEEP` summary (attempt histogram, minimum grass, minimum trees, maximum mine steps). `Refs #427`.

# M2: balance on generated maps

- [ ] 8.1 Add `MAP_STYLE=generated` to `PlayerBotTestSupport.swift`: when set, sweep worlds use `.generated(size: .medium, islandCount: 5)` for the archipelago and `.generated(size: .medium, islandCount: 1)` for the single island.
- [ ] 8.2 With the sweep slot, run `pacing`, `solvency` and `rivals` with `MAP_STYLE=generated`, then on classic maps in the same run, and compare by the regression rules in design D12.
- [ ] 8.3 If a rule fails, tune only the design D6 shares, the D4 coast constants or the D5 radius table. Rerun 5.1 and 5.2 (update the golden hashes with a reason), then 8.2.
- [ ] 8.4 If 3.6 measured over 1.5 s, move `NewGameDialogViewModel.commit()` work off the main actor, keeping the Start button disabled while it runs (no new UI). Add a test that Start stays disabled until the world is ready.
- [ ] 8.5 Update `scripts/sweeps/README.md` with `MAP_STYLE` and the generated baseline.

# M3: follow-ups (separate changes)

- [ ] 9.1 Chapter packs and scenarios may name map settings (`map:` in the chapter data, `ChapterEmitter`, `Validator+Chapters`). Terrain directives must be retuned per chapter, so this is its own change.
- [ ] 9.2 Coordinate with `add-island-specialization`: its colony rule needs at least three islands; check the 3-island archipelago once both are on `main` (design D9).
- [ ] 9.3 Optional: show the player when a generated request fell back to the classic map.
