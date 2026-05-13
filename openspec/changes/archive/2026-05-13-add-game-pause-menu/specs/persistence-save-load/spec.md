## ADDED Requirements

### Requirement: SaveStore reachable from the in-game pause menu

`SaveStore.save(world:)` SHALL be reachable from the pause menu via an injected `onSaveGame` callback in the app shell. The same SaveStore instance MUST also back the title screen's "Continue" most-recent-save query, so saves written from the pause menu surface immediately as the "Continue" target on the next title-screen visit.

#### Scenario: Save Game from pause menu writes via SaveStore

- **WHEN** the player taps Save Game in the pause menu
- **THEN** `SaveStore.save(world:)` is invoked with the session's current world

#### Scenario: Pause-menu save populates the title screen Continue row

- **WHEN** the player saves from the pause menu, exits to title, and the title screen queries `SaveStore.mostRecentSave()`
- **THEN** the returned metadata reflects the just-written save's `gameID` and modification date

### Requirement: Auto-save on Quit-to-Title

When the pause menu's **Quit to Title** action fires, the app shell SHALL invoke `SaveStore.save(world:)` once before transitioning back to the title screen. The save MUST be silent (no inline status row). Save failures MUST be logged but MUST NOT block the title transition — the player explicitly asked to leave the game and expects to return to the menu regardless.

#### Scenario: Quit to Title auto-saves before transitioning

- **WHEN** the player taps Quit to Title in the pause menu
- **THEN** the save is invoked before the title screen replaces the game view

#### Scenario: Quit to Title succeeds even when save fails

- **WHEN** the save during Quit to Title throws an error
- **THEN** the title screen is still presented; the failure is logged at the application level

#### Scenario: Most-recent save reflects the post-quit world state

- **WHEN** the player quits to title successfully and the title screen queries the most-recent save
- **THEN** the loaded world matches the state at the moment of Quit-to-Title
