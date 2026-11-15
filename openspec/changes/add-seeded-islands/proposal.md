## Why

Every single-island game is played on the same 96×96 map, and the archipelago is five hand-placed ellipses on 300×300 whose shapes never change; the seed only moves forest and mountain dots. A second game looks and plays like the first, which hurts replay value (issue #427, epic #398).

## What Changes

- **Generated maps.** A new integer-only generator shapes island outlines from the seed: value-noise coasts with bays and headlands, smoothed and cleaned, then beach, mountain ranges and forest by noise. In an archipelago the seed also decides island count, positions and sizes. macOS and Linux produce byte-equal terrain.
- **Construct, validate, retry.** Every generated world is checked after world generation: the expected island count, a fair start on every island (the existing `StartArea.isFair` rule, no fallback placement), a mine site within 10 road tiles of every town center, a port site near every town center, and one connected sea. A failed attempt retries with the next derived seed, at most 8 attempts; if all 8 fail, the game falls back to the classic map of that layout. Generation always ends, and every start is fair.
- **Classic maps stay.** Today's two maps become the `classic` map style and keep their generators byte-for-byte. `World.newGame(layout:seed:)` without a map argument still builds them, so scenarios, campaign chapters, UI-test seeds, the title backdrop, the determinism fixture and every existing test keep their maps.
- **New Game options.** In Sandbox mode the New Game dialog gets a **Map** menu picker (Classic, Small, Medium, Large) and, for an archipelago with a generated map, an **Islands** menu picker (3 to 7). Both use the dialog's existing `Picker` controls; no new screen. Scenario mode locks the map to Classic. The dialog now opens with a Medium map and a random seed, so a new game gets a new map. All new text has a German translation.
- **Saves.** The world's terrain is already stored in the save, not regenerated, so existing saves load unchanged. A new `map` field records the settings; saves without it decode as Classic. No save version bump.
- **Seam for island profiles.** Islands keep their climate from the existing default rule. World generation gets one named hook, called after islands are detected and before town centers are placed, where the separate `add-island-specialization` change attaches per-island resource profiles. Validation runs after that hook.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `world-terrain`: map style and size join the layout; seeded outlines and archipelago placement; validation with bounded retries and the classic fallback; the island-profile hook.
- `platform-shells`: New Game offers map size and island count.
- `persistence-save-load`: saves before seeded maps decode as Classic.
- `fixed-point-math`: the determinism gate also covers a generated archipelago.

## Impact

- **Code:** `Packages/CityCore/Sources/CityCore/MapSettings.swift` and `SeededIslands/` (new); `World+Fixture.swift` (`newGame` gains `map:`); `World.swift` (new `map`, `mapAttempt` fields); `World+StartSites.swift` (extract the near-mine-site check so the validator reuses it); `DeterminismFixture/main.swift`; `.swiftlint.yml` (float ban covers `SeededIslands/`); `Packages/CityUI/Sources/CityUI/NewGameDialogView.swift`, `NewGameDialogViewModel.swift`; `Localizable.xcstrings`.
- **Not changed:** `IslandGenerator`, `ArchipelagoGenerator`, scenarios, campaign chapters, `UITestSeed`, `TitleBackdrop`, the renderer. The renderer already reads map size from the snapshot; design D10 lists what was checked.
- **Saves:** the Large archipelago (360×360) stores 44% more terrain than today's 300×300.
- **Balance:** classic-map sweeps must not change at all. Generated maps need their own pacing, solvency and rival sweeps before a release (design D12).
- **Design:** no significant visual change. Two pickers and one hint line in an existing dialog section; terrain uses the existing tiles.
