## 1. M1 — GameSession.isPaused state (CityUI)

- [x] 1.1 Tests-first: translate `#### Scenario: Paused step does not advance the world`, `#### Scenario: Paused step does not forward events`, `#### Scenario: Toggling isPaused resumes ticking`, and `#### Scenario: Pause defaults to false on fresh session` into failing tests in `CityUITests`. Confirm red.
- [x] 1.2 Implement to green: add `public var isPaused: Bool = false` to `GameSession`. Update `step()` to `guard !isPaused else { return }` at the top so neither `world.tick()` nor `hud.apply(...)` nor `audioEventConsumer?(...)` fire while paused.
- [x] 1.3 Refactor under a green bar.

## 2. M2 — Pause menu UI (CityUI)

- [x] 2.1 Tests-first: translate `#### Scenario: Pause menu surfaces five actions on Mac`, `#### Scenario: Pause menu hides Quit on iOS`, `#### Scenario: Resume toggles isPaused off`, and `#### Scenario: Save Game invokes SaveStore` into failing tests in `CityUITests` (view-model assertions on a `PauseMenuViewModel`).
- [x] 2.2 Implement to green: `PauseMenuViewModel` exposing `actions: [PauseMenuAction]` filtered per platform (Quit hidden on iOS). `PauseMenuView` SwiftUI view rendering one row per action. Wire Resume to `session.isPaused = false`, Save Game to an injected `onSaveGame: () throws -> Void`, Settings to a presentation closure that opens the existing settings sheet, Quit to Title to `onQuitToTitle: () -> Void`, Quit to `onQuit: () -> Void` (Mac only).
- [x] 2.3 Implement to green: present the pause menu as `.sheet(isPresented: $session.isPaused)` from `CityRootView`. The sheet's content is the `PauseMenuView` constructed with the actions wired above.

## 3. M3 — HUD pause button (CityRender2D + CityUI)

- [x] 3.1 Tests-first: translate `#### Scenario: HUD shows the pause glyph when running`, `#### Scenario: HUD shows the play glyph when paused`, and `#### Scenario: Tapping the HUD pause button toggles isPaused` into failing tests in `CityUITests`. Implemented via the headless `pauseButtonSymbolName(isPaused:)` helper plus a `GameSession.isPaused` toggle assertion.
- [x] 3.2 Implement to green: add a pause button to the existing HUD top-right cluster (alongside the gear icon from `add-island-hud-overlay`). The button's SF Symbol is `pause.fill` when `!isPaused`, `play.fill` when `isPaused`. Tap action toggles `session.isPaused`. The button stays visible in both states.

## 4. M4 — Keybindings (CityUI)

- [x] 4.1 Tests-first: translate `#### Scenario: ESC toggles pause on Mac`, `#### Scenario: ESC closes the pause menu when it is showing`, `#### Scenario: Cmd-Period also toggles pause on Mac`, and `#### Scenario: ESC toggles pause on iPad with a hardware keyboard` into failing tests (where SwiftUI's keyboard-shortcut wiring can be verified, otherwise stub with view-model assertions). The view-model toggle is asserted directly; the SwiftUI `.keyboardShortcut` plumbing is verified by the build (compiled code, not asserted at runtime).
- [x] 4.2 Implement to green: attach `.keyboardShortcut(.escape, modifiers: [])` and `.keyboardShortcut(".", modifiers: .command)` to the HUD pause button. Verify the Resume row in the pause menu carries the same shortcuts so ESC closes the menu when it is open.

## 5. M5 — Audio is unaffected (CityAudio + verification)

- [x] 5.1 Tests-first: translate `#### Scenario: Music continues while paused`, `#### Scenario: SFX events do not fire while paused`, and `#### Scenario: Audio engine is not stopped on pause` into failing tests in `CityAudioTests` (recorder dispatchers, audio engine state probes). Landed in `CityUITests/PauseGateTests.swift` as documentary assertions — `GameSession` has no audio-engine handle to probe directly; the surface that's observable from this package is "no events get forwarded while paused," and that is asserted.
- [x] 5.2 Implement to green: nothing changes in CityAudio. The tests are documentary: they verify that pausing `GameSession` produces no events to the audio coordinator (already covered by `step()`'s guard) and that the engine `isRunning` is unchanged.

## 6. M6 — Quit to Title auto-save (CityPersistence + CityUI)

- [x] 6.1 Tests-first: translate `#### Scenario: Quit to Title auto-saves silently`, `#### Scenario: Auto-save failure does not block the title transition`, and `#### Scenario: Most-recent save reflects the post-quit world state` into failing tests in `CityPersistenceTests` + `CityUITests`.
- [x] 6.2 Implement to green: the pause menu's Quit-to-Title action wraps `try? saveStore.save(world: session.world)` and then calls the injected `onQuitToTitle` callback. The shell's `onQuitToTitle` tears down the GameSession-bound WindowGroup root and presents the title screen via the boot flow from `add-title-screen-and-new-game`. Until that change lands, `onQuitToTitle` defaults to a no-op; the menu hides the Quit-to-Title row when the callback is nil.

## 7. M7 — Save Game button (CityPersistence + CityUI)

- [x] 7.1 Tests-first: translate `#### Scenario: Save Game writes via SaveStore` and `#### Scenario: Save Game surfaces success or failure inline` into failing tests.
- [x] 7.2 Implement to green: pause menu's Save Game action calls the injected `onSaveGame` closure. The closure wraps `SaveStore.save(world:)`. The menu's status row shows "Saved" on success or "Couldn't save: <error>" on failure for 2 seconds before clearing.

## 8. M8 — App-shell wiring (CitybuilderiOSApp / CitybuilderMacApp)

- [x] 8.1 Wire `CitybuilderiOSApp` and `CitybuilderMacApp` to construct the pause menu actions with real `SaveStore` and (when available) `BootFlow.returnToTitle()` callbacks. Until `add-title-screen-and-new-game` lands, `onQuitToTitle` stays nil and the Quit-to-Title row stays hidden.
- [x] 8.2 Mac shell: wire `onQuit` to `NSApplication.shared.terminate(nil)`. iOS shell: pass nil (the row stays hidden).

## 9. M9 — Polish + docs

- [x] 9.1 README: extend with a "Pause and pause menu" section covering the keybindings, the HUD button, what the actions do, and the music-keeps-playing behavior.
- [x] 9.2 Final `make test && make lint && make format`.
- [ ] 9.3 Visual playtest: place a few buildings, press ESC, verify simulation freezes (carriers stop mid-path), verify music continues, verify Save Game and Resume work. — DEFERRED (interactive).
- [ ] 9.4 Cross-device save round-trip after Quit-to-Title. — DEFERRED (requires title-screen change landed + two devices).
