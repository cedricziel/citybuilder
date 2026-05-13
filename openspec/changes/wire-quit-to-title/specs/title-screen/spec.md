## ADDED Requirements

### Requirement: Return-to-title transition

`TitleScreenViewModel` SHALL expose a `returnToTitle()` method that clears `committedSession` and re-queries the save store so the just-written save appears in the `Continue` row. The method MUST be safe to call multiple times. The method MUST NOT construct a new `GameSession`.

#### Scenario: returnToTitle clears the committed session

- **WHEN** the view-model has a non-nil `committedSession` and `returnToTitle()` is called
- **THEN** `committedSession` reads `nil`

#### Scenario: returnToTitle refreshes the Continue row

- **WHEN** a save has been written between the previous `commit(world:)` and `returnToTitle()`
- **THEN** `mostRecentSave` reflects the newest save without the caller having to do anything else

#### Scenario: returnToTitle is idempotent

- **WHEN** `returnToTitle()` is called twice in succession
- **THEN** the second call is a no-op (committedSession stays nil and no new session is built)

### Requirement: Host bridges pause-menu Quit to Title back to the title

`TitleScreenHost` SHALL inject an `onQuitToTitle` closure into the `PauseMenuConfig` it forwards to `CityRootView`. The closure MUST call the view-model's `returnToTitle()`. App shells MUST NOT need to supply an `onQuitToTitle` of their own.

#### Scenario: Host injects onQuitToTitle into the pause-menu config

- **WHEN** the host builds the in-game `CityRootView` from a `pauseMenuFactory` that returns a config with `onQuitToTitle == nil`
- **THEN** the resulting `PauseMenuConfig` passed to `CityRootView` has a non-nil `onQuitToTitle` that, when invoked, clears `committedSession`

#### Scenario: Pause-menu Quit to Title returns to title

- **WHEN** the player taps Quit to Title in the pause menu
- **THEN** the pause-menu auto-save runs first (per pause-menu Requirement: Quit to Title auto-saves), then `TitleScreenView` becomes visible inside the same window

#### Scenario: Returning to title and starting a new game uses a fresh session

- **WHEN** the player returns to title and then taps New Game… and commits a world
- **THEN** a new `GameSession` is constructed via the existing factory closure (not the previous session)
