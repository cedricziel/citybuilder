## 1. M1 — `returnToTitle()` on `TitleScreenViewModel`

- [x] 1.1 Tests-first: translate every `#### Scenario:` under `Requirement: Return-to-title transition` from `specs/title-screen/spec.md` into failing tests in `CityUITests/ReturnToTitleTests.swift`. Confirm red.
- [x] 1.2 Implement to green: add `public func returnToTitle()` that clears `committedSession` and calls `refreshMostRecentSave()`.
- [x] 1.3 Verify idempotency: calling `returnToTitle()` while `committedSession` is already nil is a no-op.

## 2. M2 — `TitleScreenHost` bridges `onQuitToTitle`

- [x] 2.1 Tests-first: translate every `#### Scenario:` under `Requirement: Host bridges pause-menu Quit to Title back to the title` into failing tests in `CityUITests/TitleScreenHostQuitToTitleTests.swift`. Confirm red.
- [x] 2.2 Implement to green: inside `TitleScreenHost.gameView(session:)`, wrap the `pauseMenuFactory(session)` result so the produced `PauseMenuConfig.onQuitToTitle` calls `viewModel.returnToTitle()`. Preserve every other field as-is.
- [x] 2.3 Verify the host's wrapper does NOT call `returnToTitle()` itself — only the injected closure does, and only when the pause menu invokes it.

## 3. M3 — App shell cleanup

- [x] 3.1 `CitybuilderiOSApp.swift`: remove the now-redundant `onQuitToTitle: nil` argument from the `PauseMenuConfig` literal (or keep it `nil` since the host overwrites — either is fine, but pick one and document).
- [x] 3.2 `CitybuilderMacApp.swift`: same.
- [x] 3.3 Build both shells in Xcode; verify the `Quit to Title` row appears in the live pause menu and a tap returns the app to `TitleScreenView`. — `xcodebuild` BUILD SUCCEEDED for both targets; interactive verification deferred (task 4.1).

## 4. M4 — Verification & sign-off

- [ ] 4.1 Smoke test on iPhone, iPad, and Mac simulators: open a game, pause, tap Quit to Title, verify the save shows up under Continue on the title screen, and tapping Continue resumes the saved game. — DEFERRED (requires interactive Xcode + simulators).
- [x] 4.2 `make test-scenarios` clean for the `title-screen` and `pause-menu` scenarios added by this change.
- [x] 4.3 `make lint && make format` clean.
- [x] 4.4 Confirm the existing pause-menu auto-save spec scenarios (`Quit to Title auto-saves silently`, `Auto-save failure does not block the title transition`) still pass — this change does not alter the auto-save path.
