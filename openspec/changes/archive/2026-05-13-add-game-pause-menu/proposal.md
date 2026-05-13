## Why

The simulation runs from app launch to app close with no way to pause and no menu surface for save / quit-to-title / settings while a game is in progress. The Mac `platform-shells` spec already declares a "Pause hotkey" requirement and a Pause scenario, but neither has been implemented — there is no `isPaused` state, no menu UI, and no keybinding wired up.

This change implements pause as a hard simulation halt (no ticks, no event emission) with a modal menu over the frozen world. Music continues so the moment doesn't feel jarringly silent. ESC is the primary keybinding on every platform with a hardware keyboard; a pause button in the HUD covers iPad / iPhone without a keyboard.

The menu shares Settings + Quit-to-Title flow with the title screen (`add-title-screen-and-new-game`), which is the explicit gate: this change depends on that one for the destination of the "Quit to Title" action and for the `Settings` sheet reuse.

## What Changes

- Introduce a new capability `pause-menu` covering the paused simulation state, the modal menu UI, and its keybindings. (`pause-menu` new.)
- `GameSession` gains `isPaused: Bool`. The 10 Hz `step()` short-circuits when `isPaused == true` — it does **not** call `world.tick()` and does **not** forward events to the audio consumer. The HUD's snapshot also doesn't refresh (no new snapshot is taken). The audio engine is untouched; the music loop continues. (`pause-menu` new; minor `simulation-core` adjacency, but no spec changes there — pause lives in the UI layer.)
- New `PauseMenuView` (SwiftUI) hosting the menu. Presented as a `.sheet` over `CityRootView` when `session.isPaused == true`. Actions: **Resume**, **Save Game**, **Settings**, **Quit to Title**, **Quit** (Mac only). (`pause-menu` new.)
- HUD gains a pause / play button next to the existing gear icon. Glyph swaps based on `session.isPaused` so the button doubles as a state indicator. (`rendering-2_5d` modified.)
- Keybindings: ESC opens the menu when the game is running; ESC also closes the menu when it's open (universal "back out" semantics). On Mac, Cmd-. (Cmd-Period) is an alias. The Mac existing "Pause hotkey" requirement is fulfilled by ESC. (`platform-shells` modified.)
- iPad / iPhone keyboard support: when a hardware keyboard is attached, ESC and Cmd-. work identically to Mac. Without a keyboard, the HUD button is the only entry. (`platform-shells` modified.)
- **Save Game** action wraps `SaveStore.save(world:)` (the existing API). Persists the current world to the same save slot the title screen's `Continue` will read. (`persistence-save-load` modified — a small addition, the spec scenario.)
- **Quit to Title** auto-saves first (silently, no confirmation prompt) and then transitions the app shell back to the title screen via a `GameSessionFactory`-style seam. Depends on the boot-flow architecture landing in `add-title-screen-and-new-game`. (`persistence-save-load` modified — auto-save-on-quit scenario.)
- **Quit** is Mac-only. Calls `NSApplication.shared.terminate(nil)`. iOS has no convention for app-self-quit; the row is hidden on iOS.

## Capabilities

### New Capabilities

- `pause-menu`: the `isPaused` state on `GameSession`, the modal SwiftUI menu, the keybinding semantics, the menu's action contract (Resume, Save Game, Settings, Quit to Title, Quit). The capability owns the pause user-experience end-to-end; it depends on `simulation-core`'s `World.tick()` being externally controlled (which it already is — `GameSession` decides when to tick).

### Modified Capabilities

- `rendering-2_5d`: HUD layout gains a pause button. Glyph reflects current `isPaused` state.
- `platform-shells`: ESC and Cmd-. keybindings on every platform with a hardware keyboard. The existing Mac "Pause hotkey" requirement is satisfied; the Pause scenario gains companion scenarios for iPad / iPhone.
- `persistence-save-load`: explicit "save game from menu" scenario; auto-save on Quit-to-Title scenario.

## Impact

- **CityUI** — `GameSession.isPaused: Bool` (default `false`). `step()` short-circuits when paused. New `PauseMenuView` and the wiring to present it as a sheet. `CityRootView` gains a pause button alongside the existing settings gear. Reuses the `settings: @ViewBuilder` slot pattern already in place for the title screen (so pause-menu's "Settings" action opens the same sheet that the gear opens).
- **CityCore** — no changes. World is unaware of pause; pause is purely a UI-layer "don't call tick" gate. Save/load round-trip is identical paused or not (no `isPaused` field on World).
- **CityAudio** — no changes. The music loop continues; SFX cues simply don't fire because no events are emitted while paused. The Audio Coordinator gets an empty events array (or no call at all) during paused frames.
- **CityPersistence** — no schema change. `SaveStore.save(world:)` is the existing entry point; the menu and the Quit-to-Title path both call it.
- **App shell wiring** — `CitybuilderiOSApp` / `CitybuilderMacApp` participate in the "Quit to Title" path by responding to a callback that swaps the WindowGroup's root from `CityRootView` back to `TitleScreenView`. Depends on the title-screen change landing first; in the meantime, the action can stub to a no-op or to `exit(0)` for testing.
- **Keybindings** — SwiftUI's `.keyboardShortcut(.escape, modifiers: [])` and `.keyboardShortcut(".", modifiers: .command)`. The buttons that present the menu carry these shortcuts. SwiftUI handles the platform routing (iPad/iPhone keyboards, Mac keyboards).
- **No new third-party dependencies.**
- **Out of scope, intentionally deferred**:
  - Pausing the music (or ducking it) while paused — Phase 2 candidate if playtest says "the music while a pause menu is open is distracting." For now, music plays.
  - "Don't ask again" auto-save confirmation. Quit-to-Title silently auto-saves.
  - Auto-pause on app backgrounding (iOS / iPad). A future change can add it; the current behavior is "app keeps running on background" (it already does today).
  - Pausing carrier animations. The presentation layer naturally freezes because no snapshots are taken; carriers stop visually mid-path. Good enough for v0.
