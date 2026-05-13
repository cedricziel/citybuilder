## ADDED Requirements

### Requirement: App boot path

The iOS and macOS app shells SHALL boot into a `TitleScreenView` instead of constructing a `GameSession` eagerly. `GameSession` MUST be constructed only after the player commits a world from the title screen (via the new-game dialog or via the `Continue` action).

#### Scenario: Fresh-install launch shows the title screen
- **WHEN** the app launches with no save data present
- **THEN** the title screen is visible and no `GameSession` has been instantiated

#### Scenario: Subsequent-launch shows the title screen
- **WHEN** the app launches after a previous game session ended
- **THEN** the title screen is visible and the live `IsoWorldView` is not yet drawn

#### Scenario: Game view replaces title screen on commit
- **WHEN** the player commits a world from the title screen
- **THEN** the title screen is dismissed and `CityRootView` becomes the visible root within the same window

### Requirement: Title screen view-model surface

A `TitleScreenViewModel` SHALL own the visible state of the title screen. It MUST be `@Observable`, `@MainActor`-isolated, and testable without SwiftUI. The view-model MUST expose:

- A `mostRecentSave: SaveMetadata?` value that drives the `Continue` row's visibility.
- A `presentingNewGameDialog: Bool` flag.
- A `presentingSettings: Bool` flag.
- A `continueRequested()` action that the view calls when the player taps `Continue`.
- A `newGameRequested()` action that the view calls when the player taps `New Game…`.
- A `settingsRequested()` action that the view calls when the player taps `Settings`.
- A `commit(world:)` action invoked by either the dialog or the continue path that runs the session factory.

#### Scenario: Continue row hidden when no save exists
- **WHEN** the title screen view-model is constructed with a save store containing no saves
- **THEN** `mostRecentSave` is nil and the title view does NOT render a Continue row

#### Scenario: Continue row populated from the newest save
- **WHEN** the save store contains three saves with different write dates
- **THEN** `mostRecentSave` matches the save with the latest `writeDate`

#### Scenario: Tapping Continue loads the save and commits
- **WHEN** the player taps Continue and the underlying save loads successfully
- **THEN** the view-model invokes the session factory with the loaded `World` and the title screen is dismissed

#### Scenario: Tapping New Game shows the dialog
- **WHEN** the player taps New Game
- **THEN** `presentingNewGameDialog` becomes true

### Requirement: New-game dialog

The title screen SHALL present a `NewGameDialogView` that lets the player pick a `WorldLayout` and a seed, and then commits a freshly-constructed `World` to the session factory. The dialog MUST be cancellable without side effect.

#### Scenario: Default values produce the MVP world
- **WHEN** the dialog opens and the player immediately taps `Start`
- **THEN** the resulting world equals `World.newGame(layout: .singleIsland, seed: 0)`

#### Scenario: Layout selection
- **WHEN** the player selects `Archipelago` and taps `Start`
- **THEN** the resulting world's `layout` is `.archipelago` and `islands.count >= 2`

#### Scenario: Random seed selection
- **WHEN** the player chooses the random-seed option and taps `Start`
- **THEN** the resulting world's `seed` matches the value displayed in the dialog at the moment Start was tapped (i.e. the random value is captured deterministically rather than re-rolled by `Start`)

#### Scenario: Custom seed input accepted
- **WHEN** the player enters `12345` in the custom-seed field and taps `Start`
- **THEN** the resulting world's `seed` is `12345`

#### Scenario: Custom seed input rejected
- **WHEN** the player types non-numeric text in the custom-seed field
- **THEN** `Start` is disabled and the dialog stays open

#### Scenario: Cancel discards selection
- **WHEN** the player opens the dialog, changes the layout, and taps `Cancel`
- **THEN** no session is created and the next time the dialog opens its selection state returns to defaults

### Requirement: Settings reachable without entering the game

The title screen SHALL expose a `Settings` action that opens the same audio + credits surface today's running app exposes, without constructing a `GameSession`.

#### Scenario: Settings opens from the title screen
- **WHEN** the player taps `Settings` on the title screen
- **THEN** the settings surface is presented and no live game is started

#### Scenario: Dismissing settings returns to the title screen
- **WHEN** the player dismisses the settings surface
- **THEN** the title screen is re-visible and `presentingSettings` is false

### Requirement: macOS quit action

On macOS the title screen SHALL expose a `Quit` action that terminates the application. iOS MUST NOT show a Quit affordance.

#### Scenario: Quit on macOS terminates the app
- **WHEN** the player taps `Quit` on macOS
- **THEN** the app terminates via `NSApplication.shared.terminate(nil)`

#### Scenario: iOS has no Quit affordance
- **WHEN** the title screen renders on iOS
- **THEN** no Quit button is present in the view hierarchy
