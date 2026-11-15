## 1. M1 — Data: crop families, garden climates and profile numbers

- [ ] 1.1 Tests-first: in `Packages/GameDataGen/Tests`, add failing tests that a pack with `kind: IslandProfiles` loads its climates, `soilSteps`, `yieldRange`, `oreChancePercent`, `forest` and `luxuryImport`; that a `garden` building without `climate` and a non-garden with `climate` are rejected by the validator. Confirm red.
- [ ] 1.2 Implement to green: GameDataGen. Extend `pack.schema.json` (kind enum, `IslandProfiles` `if/then` block, building fields `cropFamily: field|grain|pasture|garden` and `climate: temperate|tropical`), `Loader.swift`, `Model.swift`, `Validator.swift` and `SwiftEmitter.swift`, following the `Logistics` singleton. Emit `Generated/IslandProfiles+Generated.swift` (`enum IslandProfilesCatalog`) and `BuildingKind.cropFamily: CropFamily?` / `BuildingKind.cropClimate: Climate?`.
- [ ] 1.3 Add the data (design D2): the `IslandProfiles` item in `packs/core.yaml`; `cropFamily` on farm, grain-farm, sheep-farm; `cropFamily: garden` plus `climate` on hop-garden (temperate), vineyard, tea-garden, coffee-grove (tropical). Run `make gamedata` and commit the regenerated files with the packs. `make gamedata-check` must be clean.

## 2. M1 — Simulation: profiles, yields, placement

- [ ] 2.1 Tests-first: in `Packages/CityCore/Tests/CityCoreTests/IslandProfileTests.swift`, translate every scenario of `specs/world-terrain/spec.md` (both requirements and the modified climate band), `specs/goods-and-production/spec.md` and `specs/rival-towns/spec.md` into `@Test("scenario: …")` tests with the scenario titles lowercased. Seed loops use `sweepSeeds(0 ..< 50)` where the scenario says 0 to 49. Confirm red.
- [ ] 2.2 Implement to green: `IslandProfile.swift` (D1): `CropFamily`, `ForestRichness`, `IslandProfile` with `complete`; `Island.profile` with `decodeIfPresent ?? .complete`; `World.soilYield(of:on:)`; `World.cropCycle(_:yield:)`.
- [ ] 2.3 Implement to green: `World.assignIslandProfiles()` (D3) in a new `World+IslandProfiles.swift`, called in `World.generate` after `world.culture = culture` and before `seedRivals`; `World.colonyIslandID`; the SplitMix hash over `(seed, islandID, salt)` with salts 1 grain, 2 pasture, 3 ore. Also `World.importsLuxury` (D6 condition).
- [ ] 2.4 Implement to green: the yield-scaled cycle in `Systems.swift` `runProductionSystem` (D4), fetching `tileToIslandMap()` once per pass only when a crop producer is operational.
- [ ] 2.5 Implement to green: `PlacementRejection.wrongClimate(Climate)` and `.noOre` in `Terrain.swift` with codes `wrong_climate` / `no_ore`, checked in `World+Placement.swift` after `wrongCulture` and before materials (D5).
- [ ] 2.6 Implement to green: `seedRivals` skips the colony island (D7).
- [ ] 2.7 Update every test that compares encoded saves or snapshots byte for byte and changes only because `Island` gained `profile`; name them in the commit body.
- [ ] 2.8 Refactor under a green bar: `xcrun swift test --package-path Packages/CityCore --filter IslandProfile`, then the `WorldLayout`, `FairStartSite`, `StarterMineSite`, `RivalTowns` and `Production` suites.

## 3. M1 — Market import and PlayerBot

- [ ] 3.1 Tests-first: translate every scenario of `specs/town-market/spec.md` into tests in `Packages/CityCore/Tests/CityCoreTests/LuxuryImportTests.swift`. Confirm red.
- [ ] 3.2 Implement to green: world-level `marketTerms(for:)` and `marketPrice(_:_:)` in `World+Market.swift` (D6), used by `marketQuotes`, `marketLeft` and the buy command; `MarketLedger.left` takes the limit. Rivals keep the pack terms. The existing "No trade loop makes money" test must stay green and cover the import.
- [ ] 3.3 Implement to green: snapshot fields `IslandSummary.climate`, `IslandSummary.profile`, `WorldSnapshot.importsLuxury` (D9), with a test that a new archipelago snapshot carries the home island's profile.
- [ ] 3.4 PlayerBot (D11) in `Tests/CityCoreTests/PlayerBot+MidGame.swift`: drop the luxury garden and producer steps when `importsLuxury`; with `tradesAtMarket`, buy `min(8, marketLeft(luxury, .bought))` when the island holds fewer than 6 of the luxury. Add a test that a market-arm bot on archipelago seed 0 owns at least one merchant house by year 10.
- [ ] 3.5 Refactor under a green bar.

## 4. M1 — Saves

- [ ] 4.1 Tests-first: translate every scenario of `specs/persistence-save-load/spec.md` into tests in `Packages/CityPersistence/Tests/CityPersistenceTests/IslandProfileMigrationTests.swift`, using `Fixtures/saves/v12_houses_before_porters.json` for the version-12 fixture and a hand-edited copy with a hop garden on a tropical island for the second scenario (`Fixtures/saves/v12_hop_garden_tropical.json`). Confirm red.
- [ ] 4.2 Implement to green: no version bump; the `Island` decoder default from 2.2 makes them pass. Fix whatever else the fixtures expose.

## 5. M1 — UI text on existing surfaces

- [ ] 5.1 Tests-first: translate every scenario of `specs/platform-shells/spec.md` into tests in `Packages/CityUI/Tests/CityUITests/IslandProfileTextTests.swift`. Confirm red.
- [ ] 5.2 Add the keys of design D8 to `Packages/CityUI/Sources/CityUI/Resources/Localizable.xcstrings` with English and German marked `translated`, each with a comment. `make l10n-check` must pass.
- [ ] 5.3 Implement to green: the pill caption (`StatusPillView.islandButton` reads a caption from `HUDViewModel.currentIslandCaption`, falling back to `hud.island` when no summary is shown).
- [ ] 5.4 Implement to green: the tray line (`IslandProfileText.line(profile:culture:)` in a new `IslandProfileText.swift`; one `Text` under the header in `StocksTrayView`, `.caption2`, `.secondary`).
- [ ] 5.5 Implement to green: the soil capsule (`GameSession.areaCountCapsule` gets a branch for kinds with a `cropFamily`, text `aoe.soil`, tone neutral ≥ 100, `.low` below) and the inspector line `inspector.soil` for crop buildings.
- [ ] 5.6 Implement to green: `PlacementRejectionText` cases for `.wrongClimate` (building name via `SessionBanner.sentenceCase`, climate via `climate.needs.*`) and `.noOre`.
- [ ] 5.7 Update `design/web` only if a component shows the pill caption or the tray (check `design/web/src/components/`); otherwise write "none: text only" under `## Design system` in the PR.
- [ ] 5.8 Refactor under a green bar.

## 6. M1 — Verify and sweeps

- [ ] 6.1 `make lint`, `make gamedata-check`, `make l10n-check` and `make test-scenarios` clean for `world-terrain`, `goods-and-production`, `town-market`, `rival-towns`, `persistence-save-load` and `platform-shells`.
- [ ] 6.2 Smoke the sweeps with `SWEEP_SEEDS=1 scripts/sweeps/run-release-sweeps.sh` (no slot needed).
- [ ] 6.3 With the sweep slot from the orchestrator: run `solvency`, `pacing` and `rivals` on the merge base and on the branch, and compare by the table in design D12. Put the comparison in the PR body.
- [ ] 6.4 Verify make test-scenarios clean for this milestone's capabilities.
- [ ] 6.5 In-game check of the pill caption, tray line, soil capsule and the two rejection banners on iPhone and iPad — DEFERRED (requires the single simulator slot)

## 7. M2 — Campaign directives and a colonising PlayerBot

- [ ] 7.1 Tests-first: scenarios for `TerrainDirective.soil(IslandRef, CropFamily, Int)`, `.noOre(IslandRef)` and `.climate(IslandRef, Climate)`, applied after profile assignment, in a new delta of `campaigns`. Confirm red.
- [ ] 7.2 Implement to green: the three directives in `World+TerrainDirectives.swift`, their pack fields for chapters, and `make gamedata`.
- [ ] 7.3 PlayerBot colonises: a port on the colony, the luxury garden and producer there, a route home. Rerun `pacing`; archipelago `heldShare` must return to within 0.10 of the pre-change baseline.
- [ ] 7.4 Refactor under a green bar.
- [ ] 7.5 Verify make test-scenarios clean for this milestone's capabilities.

## 8. M3 — Per-tile soil and the profile overlay (design-gated)

- [ ] 8.1 Claude Design canvas: the island profile overlay, the per-tile soil tint (#261, on the #241 canvas) and a profile preview in the New Game dialog, with today's screens as the "before", 2–3 options and a recommendation; owner's go-ahead before code.
- [ ] 8.2 Tests-first: per-tile fertility scenarios (70–130% under a field's footprint, every start area holding a block at 100% or more for food and grain). Confirm red.
- [ ] 8.3 Implement to green: per-tile soil and the approved overlay; `design/web` counterparts.
- [ ] 8.4 Refactor under a green bar.
- [ ] 8.5 Verify make test-scenarios clean for this milestone's capabilities.
