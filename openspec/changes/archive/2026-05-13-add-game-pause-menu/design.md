## Context

`GameSession` owns the 10 Hz timer and calls `step()` each tick. `step()` calls `world.tick()`, applies the resulting snapshot to the HUD, and forwards `result.events` to the registered `audioEventConsumer`. There's no pause concept; the timer runs from `GameSession.init` until the timer is invalidated.

`platform-shells` already declares a "Pause hotkey" requirement on Mac but no implementation exists. There's no menu surface anywhere — the only existing in-game menus are the build palette and the inspector. The settings gear in the HUD opens a sheet but the world keeps ticking underneath.

`add-title-screen-and-new-game` introduces the boot flow that owns the **Title Screen ⇄ In-Game** transition. The Quit-to-Title action in this change rides that boot flow's `GameSessionFactory` seam to return the app to the title.

## Goals / Non-Goals

**Goals:**

- Hard pause: while paused, `World.tick()` is not called and no events fire. The simulation is frozen.
- Modal menu over the paused world. Player chooses Resume / Save / Settings / Quit-to-Title / Quit (Mac).
- ESC and Cmd-. open and close the menu universally.
- HUD pause button as the keyboard-free entry point on iPad / iPhone.
- Music continues during pause. Audio engine is untouched.
- Save Game and Quit-to-Title both use the existing `SaveStore.save(world:)`.

**Non-Goals:**

- Per-tile freeze of carrier animations during pause. The renderer reconciles against snapshots; while paused, no new snapshot is taken, so the visible carriers stop where they are. SpriteKit may continue animations on the existing sprites (water shimmer, smoke) — that's fine and gives the menu a "live but stopped" feel.
- A "Pause" button in the title screen. The title screen doesn't have a simulation running; pause is meaningless there.
- Confirming Quit-to-Title with "Save before quitting?" — we silently auto-save. Players who actively don't want to save can use the OS-level force-quit; this is rare and not worth a UI confirmation.
- Pausing the music. v0 keeps music playing. If playtest says it's distracting, a Phase 2 follow-up can duck or pause the music bus.
- Auto-pause on app backgrounding. iOS apps already keep our timer running in foreground; backgrounding is a separate concern (and SwiftUI's `.scenePhase` would handle it). Out of scope.

## Decisions

### D1. Pause is a UI-layer concept, not a CityCore concept

`World` has no idea it's paused. The pause state lives on `GameSession`:

```swift
@MainActor
@Observable
public final class GameSession {
    public var isPaused: Bool = false
    // ... existing fields ...

    public func step() {
        guard !isPaused else { return }
        let result = world.tick()
        hud.apply(world.snapshot())
        audioEventConsumer?(result.events)
    }
}
```

The `guard` is the entire pause mechanism on the sim side. No CityCore changes; replay determinism is trivially preserved because nothing happens.

**Alternatives considered:**

- *`World.isPaused: Bool` field.* Rejected — pushes presentation concern into the simulation. Pause is "the UI doesn't call tick"; the world is unchanged.
- *Two timers (one for tick, one for animations).* Pause needs only the tick timer to stop. The animation timer (SpriteKit's internal one) keeps running, which gives the desired "world is alive but stopped" feel.

### D2. Music continues; audio engine is untouched

Because pause is a `step()` guard, the audio engine is never told about pause. The music loop's `AVAudioPlayerNode` keeps playing whatever it has scheduled — the `.dataPlayedBack` re-schedule loop continues independently of the world tick. SFX cues simply don't fire because `audioEventConsumer` isn't called.

This is exactly the behavior we want — keep the mood, stop the action.

**Alternatives considered:**

- *Pause the audio engine.* Rejected — music dropping out feels jarring. The whole point of music in city-builders is to be the ambient bed; cutting it during a pause menu screams "broken game."
- *Duck the music while paused.* Could be a polish follow-up. The four-bus mixer makes a -6 dB pause-duck a one-liner; ship without it for v0.

### D3. Modal menu via SwiftUI sheet

The pause menu is a SwiftUI `.sheet(isPresented: $session.isPaused)` over `CityRootView`. SwiftUI handles dismissal (drag-down on iPad, ESC on Mac with the right keybinding wiring); we also wire the menu's "Resume" button to toggle `isPaused = false`.

```swift
CityRootView(session: session) { ... settings content ... }
    .sheet(isPresented: $session.isPaused) {
        PauseMenuView(
            session: session,
            onSaveGame: { try? saveStore.save(world: session.world) },
            onQuitToTitle: { boot.returnToTitle() },
            onQuit: { NSApplication.shared.terminate(nil) }  // Mac only
        )
    }
```

**Alternatives considered:**

- *Custom overlay (`.overlay`) instead of `.sheet`.* Workable, but `.sheet` gets us iPad's native dismissal gesture and Mac's window-style modal handling for free. The visual is a panel; SwiftUI's sheet styling is what most modern Mac/iPad apps use for pause menus.
- *Fullscreen cover (`.fullScreenCover`).* Rejected — covers the underlying world entirely, which we want to keep visible behind a translucent sheet so the player can see what they're returning to.

### D4. ESC keybinding

SwiftUI `.keyboardShortcut(.escape, modifiers: [])` on the pause button (and on a hidden Resume button while the menu is showing) handles every platform with a hardware keyboard. iPad with Smart Keyboard, Mac, iPhone with Bluetooth keyboard — all uniform.

```swift
Button {
    session.isPaused.toggle()
} label: { Image(systemName: session.isPaused ? "play.fill" : "pause.fill") }
    .keyboardShortcut(.escape, modifiers: [])
    .keyboardShortcut(".", modifiers: .command)  // alias
```

The menu's "Resume" button carries the same shortcuts so ESC closes the menu when it's open.

**Alternatives considered:**

- *Spacebar.* Cities: Skylines and Anno 1404 both use Space. Tempting, but Space is conflicted with map panning in some games. ESC is unambiguous.
- *Tap outside the menu to resume.* SwiftUI sheet drag-dismissal already gives this on iPad; on Mac the dismiss gesture is the sheet's close-button or ESC. Good enough.

### D5. Pause button glyph indicates state

The HUD button's SF Symbol swaps based on `isPaused`:

- Running: `pause.fill` (player sees this when they want to pause)
- Paused: `play.fill` (player sees this from inside the menu — though the menu itself has a clearer Resume row)

The button stays visible in both states so it's still a state indicator at a glance. Tapping it from inside the menu would also resume (it carries the same toggle action).

### D6. Save Game in pause menu

Wraps `SaveStore.save(world: session.world)`. Returns a success / failure result the menu surfaces inline ("Saved" / "Couldn't save: <error>"). No confirmation prompt — the player asked to save, we save.

The same SaveStore instance is shared by the title screen's "Continue" path. The auto-save on Quit-to-Title writes to the same slot.

**Alternatives considered:**

- *Named save slots.* Out of scope. The Title Screen change deferred slot management to a follow-up; this change inherits that constraint.
- *Save & quit as one button.* Quit-to-Title already auto-saves; "Save Game" is the intermediate-save variant. Two buttons make the difference explicit.

### D7. Quit to Title auto-saves silently

When the player taps Quit to Title:

1. `try? saveStore.save(world: session.world)` — silent save, best-effort. A failed save logs but doesn't block the transition; the player explicitly asked to leave.
2. `boot.returnToTitle()` — calls back into the app shell, which tears down the WindowGroup root's session and presents the title screen.

The `boot` reference is the app shell's `BootFlow` / `GameSessionFactory` (provided by `add-title-screen-and-new-game`). If that change hasn't landed yet, the menu can stub `onQuitToTitle` to a no-op or `exit(0)` for development; the pause menu still ships its UI.

**Alternatives considered:**

- *"Save first?" confirmation prompt.* Rejected per scope decision. Quit is rare; auto-save is the safe default.
- *No save on Quit to Title.* Rejected — players forget to save, lose progress, and rage-quit the app for real. Auto-save is the obvious protective UX.

### D8. Quit (Mac only)

`NSApplication.shared.terminate(nil)`. The button is hidden on iOS — iOS doesn't have a "quit" convention; users background apps and the system manages termination.

### D9. Determinism

Pause is presentation-only. Two players save at the same in-game moment (one paused, one not) get byte-identical World saves. Replay tests are unaffected — they call `world.tick()` directly, not via `GameSession`.

### D10. Audio engine lifecycle is unaffected

The audio engine started at `AudioStack.init` and runs continuously. Pause doesn't touch it. Music keeps playing. The audio coordinator's `consume(events:)` doesn't get called for paused frames (because `step()` short-circuits before forwarding) — no events, no SFX, no audible "tick of silence."

## Risks / Trade-offs

- **[Player expects ALL audio to stop when paused]** → Mitigation: music continues feels mature for an Anno-like, but if playtest disagrees the four-bus mixer makes a music-bus mute-or-duck on pause trivial. Phase 2 candidate.
- **[ESC on iPad without a keyboard is unreachable]** → Mitigation: the HUD pause button covers this fully. ESC is the power-user shortcut.
- **[Auto-save failure on Quit-to-Title silently loses progress]** → Mitigation: log the failure; the most-recent save remains valid (we didn't overwrite it because the save *failed*). The player loses any unsaved work since their last manual save. Documented behavior; alternative (block Quit-to-Title on save failure) is worse UX.
- **[Pause button placement in HUD]** → Mitigation: visual design — place it adjacent to the gear icon in the top-right cluster. Both buttons are `.thinMaterial` circles, consistent.
- **[Save slot conflict with title screen]** → Both write to the same SaveStore. If the title screen lists "most recent save" and the pause menu just saved, the title screen's Continue uses the just-written save. Expected and correct.
- **[Menu shown during construction transitions]** → If the player pauses mid-construction (a building was at `ticksSincePlacement = 18 / 20`), the building stays mid-construction visually. Resume continues from where it left off. Save/load preserves the tick count. No bug.

## Migration Plan

No save-format change. `GameSession.isPaused` is non-persistent (default `false` on every session construction).

If `add-title-screen-and-new-game` hasn't landed yet, the pause menu can be built and tested in isolation — `onQuitToTitle` defaults to `{ /* no-op */ }` until the title-screen boot flow is wired up. The button row hides "Quit to Title" when `onQuitToTitle == nil`.

Rollback is a clean revert. No data, no migration.

## Open Questions

- **Should the pause menu also be reachable while the build palette has a tool armed?** Yes — ESC works regardless of armed state. The toggled tool stays armed across pause/resume.
- **Should taps on the HUD pause button while a tool is armed disarm the tool?** Probably not — the tool state is orthogonal to pause. Disarming on pause would surprise a player who paused to "look at the budget" mid-placement.
- **Does the pause menu disable carrier animations?** No — they freeze naturally because no new snapshot is taken. SpriteKit's internal animations (water shimmer, sawmill smoke) continue. Visually communicates "world is still here, just stopped."
- **Phase 2: a "Pause music while paused" toggle in Settings.** If anyone asks for it, it's a one-liner. Not in v0.
- **Phase 2: "auto-pause when app backgrounds on iOS."** The game ticks today even when backgrounded; some players will want it to pause. Easy to add via `.onChange(of: scenePhase)`. Not in v0.
