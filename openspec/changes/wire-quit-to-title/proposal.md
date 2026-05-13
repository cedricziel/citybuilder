## Why

Two shipped changes left a known loose end. `add-game-pause-menu` introduced a `Quit to Title` action whose `onQuitToTitle: (() -> Void)?` closure is injected by the app shells — but both shells pass `nil` because the pause menu landed before the title screen existed. With `nil`, the pause-menu view-model hides the row entirely. So even after `add-title-screen-and-new-game` shipped a real `TitleScreenHost` that watches `committedSession`, the in-game `Quit to Title` button is still invisible.

This change closes the loop. It does not introduce new UI; it wires existing surfaces.

## What Changes

- Add `TitleScreenViewModel.returnToTitle()` that resets `committedSession = nil`. The host's existing reactive view already swaps `CityRootView` back to `TitleScreenView` when that field clears.
- `TitleScreenHost` injects an `onQuitToTitle` closure into the `PauseMenuConfig` produced by the app shell's `pauseMenuFactory`, threading the view-model reference through the seam the apps already use. The shell no longer has to know about the view-model.
- After returning, the title view re-queries `mostRecentSave` so the just-auto-saved game appears under `Continue` immediately.
- Both app shells stop passing `onQuitToTitle: nil` — they pass the host-injected closure through the `pauseMenuFactory` they already build.

## Capabilities

### Modified Capabilities

- `pause-menu`: the `Quit to Title` row is no longer hidden in the shipped apps. The existing spec language ("Quit to Title auto-saves silently and then the title screen is presented") becomes observable end-to-end rather than aspirational.
- `title-screen`: `TitleScreenViewModel` gains a `returnToTitle()` method so callers (the pause menu) can transition the host back from game to title without going through SwiftUI navigation.

## Impact

- **CityUI**: one new public method on `TitleScreenViewModel`; one `pauseMenuFactory` wrapper inside `TitleScreenHost`. No new public types.
- **Apps**: both shells stop passing `onQuitToTitle: nil`. No structural change — same `pauseMenuFactory` closure.
- **No save-format change.** Quit-to-Title's auto-save is already covered by the pause-menu spec; we don't touch the persistence layer.
- **No new dependencies.**
- **Out of scope, intentionally deferred**:
  - Confirmation dialog ("are you sure?") before Quit-to-Title. The auto-save makes the action non-destructive; a confirm would be friction.
  - In-game restart-from-checkpoint. Quit-to-Title is the only "return to a clean state" affordance.
  - Returning to the title screen and then re-entering: the host keeps the same `TitleScreenViewModel`, so re-entering builds a fresh `GameSession` through the existing factory closure. No special handling needed.

## Dependencies

- **Requires (must precede this change)**: `add-game-pause-menu` and `add-title-screen-and-new-game`, both archived.
- **Blocks**: nothing — this is a polish change.

## Open questions

- **Auto-save target slot**: pause-menu Save and Continue both target the same `defaultGameID` UUID literal in each app shell. That's the contract the title screen reads via `mostRecentSave()`. No question here, just calling it out so a future "multi-save" change knows where to fork.
