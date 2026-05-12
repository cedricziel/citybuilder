## 1. M1 — Save metadata query in CityPersistence

- [ ] 1.1 Tests-first: translate every `#### Scenario:` under `Requirement: Save metadata query` and `Requirement: Save listing query` from `specs/persistence-save-load/spec.md` into failing tests in `CityPersistenceTests/SaveMetadataTests.swift`. Confirm red.
- [ ] 1.2 Implement to green: introduce `SaveMetadata` struct + `SaveStore.listSaves()` + `SaveStore.mostRecentSave()`. File-system scan only — no `JSONDecoder` invocation on the per-save path.
- [ ] 1.3 Verify the existing CityPersistence test suite still passes without modification.

## 2. M2 — `NewGameDialogViewModel` (CityUI, headless)

- [ ] 2.1 Tests-first: translate every `#### Scenario:` under `Requirement: New-game dialog` from `specs/title-screen/spec.md` into failing tests in `CityUITests/NewGameDialogTests.swift`. Confirm red.
- [ ] 2.2 Implement to green: `NewGameDialogViewModel` (`@Observable`, `@MainActor`) with `layout`, `seedMode` (`.default | .random(captured: UInt64) | .custom(text: String)`), `commit() -> World?` returning a freshly-constructed world or nil if validation fails.
- [ ] 2.3 Verify random-seed capture: the value displayed at the moment of tap is exactly the value the resulting world carries; tapping `Start` does not re-roll.

## 3. M3 — `TitleScreenViewModel` (CityUI, headless)

- [ ] 3.1 Tests-first: translate every `#### Scenario:` under `Requirement: Title screen view-model surface` into failing view-model tests in `CityUITests/TitleScreenViewModelTests.swift`. Confirm red.
- [ ] 3.2 Implement to green: `TitleScreenViewModel` (`@Observable`, `@MainActor`) with a `SaveStoreFacade` protocol injection for the `mostRecentSave()` query so view-model tests don't touch disk. Expose `presentingNewGameDialog`, `presentingSettings`, `continueRequested()`, `newGameRequested()`, `settingsRequested()`, `commit(world:)`.
- [ ] 3.3 Implement to green: a `GameSessionFactory = (World) -> GameSession` injectable closure threaded through to `commit(world:)`. Test that committing invokes the factory with the supplied world.

## 4. M4 — `TitleScreenView` + `NewGameDialogView` (CityUI, SwiftUI)

- [ ] 4.1 Implement `TitleScreenView` — typographic title, Continue row (conditional on `viewModel.mostRecentSave != nil`), New Game…, Settings, and Quit (macOS only via `#if os(macOS)`).
- [ ] 4.2 Implement `NewGameDialogView` — segmented picker for layout, segmented control for seed mode, custom-seed `TextField` enabled only in `.custom` mode, `Start` / `Cancel`.
- [ ] 4.3 Implement a settings sheet/Scene wiring on iOS (sheet from the title screen) and macOS (existing `Settings` Scene). Verify Settings opens without constructing a `GameSession`.

## 5. M5 — App shell integration (Apps/CitybuilderiOS, Apps/CitybuilderMac)

- [ ] 5.1 Tests-first: translate every `#### Scenario:` under `Requirement: App boot path` from `specs/title-screen/spec.md` into a build-time + headless check: the app shells construct `TitleScreenView` as the root (assert via a CityUI integration test that imports the app's root view), and the `GameSessionFactory` closure is the only path that builds a session. Confirm red.
- [ ] 5.2 Implement to green: rewire `CitybuilderiOSApp` and `CitybuilderMacApp` to host `TitleScreenView` as the `WindowGroup` root. The session factory closure captures `audio` and produces `GameSession(world:audioEventConsumer:)`.
- [ ] 5.3 Implement to green: route from title → game via `NavigationStack` on iOS (push `CityRootView` on commit) and modal replacement on macOS (swap the root via a `@State` enum of `.title(viewModel)` / `.game(session)`).
- [ ] 5.4 Verify Settings is reachable from the title screen on both platforms without instantiating `GameSession`. Verify Quit on macOS terminates the app.

## 6. M6 — Verification & sign-off

- [ ] 6.1 Smoke test on iPhone, iPad, and Mac simulators: launch → title screen → New Game (each layout) → game starts; relaunch → Continue → game resumes from the prior save. — DEFERRED (requires interactive Xcode + simulators).
- [ ] 6.2 `make test-scenarios` clean for all `title-screen` and `persistence-save-load` scenarios added by this change.
- [ ] 6.3 `make lint && make format` clean.
- [ ] 6.4 Confirm the default seed + layout path produces a world byte-identical to `World.newGame()` (the MVP play experience is preserved end-to-end).
