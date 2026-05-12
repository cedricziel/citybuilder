## ADDED Requirements

### Requirement: Paused session does not tick the world

`GameSession` SHALL expose `isPaused: Bool` (default `false`). When `isPaused == true`, the per-tick `step()` function MUST NOT call `World.tick()`, MUST NOT take a new snapshot, and MUST NOT forward events to the registered `audioEventConsumer`. Toggling `isPaused` from `true` to `false` resumes ticking on the next 10 Hz timer fire.

#### Scenario: Paused step does not advance the world

- **WHEN** `session.isPaused == true` and the 10 Hz timer calls `step()`
- **THEN** the world's `tickCount` does not change

#### Scenario: Paused step does not forward events

- **WHEN** `session.isPaused == true` and the timer calls `step()`, and the registered `audioEventConsumer` is a recorder
- **THEN** the recorder receives no calls for paused frames

#### Scenario: Toggling isPaused resumes ticking

- **WHEN** `session.isPaused` is set from `true` to `false` and the next timer fires
- **THEN** `World.tick()` is called and events propagate normally

#### Scenario: Pause defaults to false on fresh session

- **WHEN** a `GameSession` is constructed
- **THEN** `session.isPaused` reads `false`

### Requirement: Modal pause menu over the running game

The pause menu SHALL be presented as a SwiftUI `.sheet` over `CityRootView` and visible whenever `session.isPaused == true`. The menu MUST contain (in order): **Resume**, **Save Game**, **Settings**, **Quit to Title**, and (Mac only) **Quit**. Dismissing the menu (via Resume, ESC, or any sheet-dismissal gesture) MUST set `session.isPaused = false`.

#### Scenario: Pause menu surfaces five actions on Mac

- **WHEN** the pause menu is shown on macOS
- **THEN** the action list contains exactly: Resume, Save Game, Settings, Quit to Title, Quit (in that order)

#### Scenario: Pause menu hides Quit on iOS

- **WHEN** the pause menu is shown on iOS / iPadOS
- **THEN** the action list contains exactly: Resume, Save Game, Settings, Quit to Title (Quit is omitted because iOS apps don't conventionally self-terminate)

#### Scenario: Resume toggles isPaused off

- **WHEN** the player taps Resume in the pause menu
- **THEN** `session.isPaused` reads `false` and the menu dismisses

### Requirement: Music continues while paused

The audio engine SHALL NOT be paused, stopped, or otherwise touched when `session.isPaused == true`. The music loop continues playing because the per-tick event forwarder is what's gated, not the engine itself. SFX cues bound to per-tick events naturally stop firing while paused because no events are emitted.

#### Scenario: Music continues while paused

- **WHEN** `session.isPaused == true` for at least one second of wall-clock time
- **THEN** the audio engine's `isRunning` remains `true` and the music bus continues rendering output

#### Scenario: SFX events do not fire while paused

- **WHEN** the player is paused for 3 seconds (which would normally cross a tax-interval boundary)
- **THEN** the audio coordinator receives no event dispatches during the pause

#### Scenario: Audio engine is not stopped on pause

- **WHEN** `session.isPaused` is toggled
- **THEN** the underlying `AVAudioEngine.isRunning` stays `true` across the transition

### Requirement: Save Game action

The pause menu's **Save Game** action SHALL invoke the injected `onSaveGame` closure exactly once per tap. The closure is expected to wrap `SaveStore.save(world:)`. The menu MUST surface a transient status row ("Saved" on success, "Couldn't save: <error>" on failure) for approximately 2 seconds after the tap.

#### Scenario: Save Game invokes SaveStore

- **WHEN** the player taps Save Game in the pause menu
- **THEN** the injected `onSaveGame` closure is called once with the current world snapshot

#### Scenario: Save Game surfaces success or failure inline

- **WHEN** the save closure succeeds
- **THEN** the menu shows "Saved" in a status row for ~2 seconds

- **WHEN** the save closure throws an error
- **THEN** the menu shows "Couldn't save: <error>" in a status row for ~2 seconds

### Requirement: Quit to Title auto-saves

The pause menu's **Quit to Title** action SHALL auto-save the current world via the same `onSaveGame`-equivalent path before transitioning to the title screen. Save failures MUST be logged but MUST NOT block the title transition — the player explicitly asked to leave the game.

#### Scenario: Quit to Title auto-saves silently

- **WHEN** the player taps Quit to Title
- **THEN** the save runs (silently — no inline status row) and then the title screen is presented

#### Scenario: Auto-save failure does not block the title transition

- **WHEN** the save closure throws an error during Quit to Title
- **THEN** the title screen is still presented; the failure is recorded in the app's log
