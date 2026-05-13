## Context

Today the apps boot directly into a live `GameSession`:

```swift
@main
struct CitybuilderMacApp: App {
    @State private var session: GameSession   // built eagerly in init()
    var body: some Scene {
        WindowGroup { CityRootView(session: session) }
    }
}
```

`GameSession.init` constructs a `World` via `World.newGame()` (the zero-arg overload) and starts a 10 Hz tick timer immediately. There is no point at which the player makes a choice — and `add-archipelago-and-sea` just landed a second world layout that has no path to the player.

The smallest sensible UI is: title view → optional new-game dialog → live game. No save slots, no profiles, no in-game pause menu yet. This change ships exactly that and nothing more, so it stays bounded and the bigger flows (save management, profile, options-by-content) can layer on later without re-architecting the boot path.

## Goals / Non-Goals

**Goals**
- A SwiftUI title screen that owns the pre-simulation flow on both iOS and macOS.
- A new-game dialog where the player picks a `WorldLayout` and a seed and commits.
- A `Continue` affordance that loads the most-recent save when one exists.
- An injection seam for `GameSession` construction so the app shell no longer needs to build the session eagerly.
- View-models testable headlessly — the SwiftUI views are thin wrappers.

**Non-Goals**
- Save slot UI (list, rename, delete). Only "most recent" surfaces.
- Title-screen theming / art / music.
- Pause menu / return-to-title navigation from inside the game.
- iCloud save selection. (Audio settings sync remains as-is.)
- Tutorial / onboarding flow.

## Decisions

### D1. App shell switches root from `CityRootView` to `TitleScreenView`

`CitybuilderiOSApp` / `CitybuilderMacApp` swap their `WindowGroup` root. The session is no longer built in `App.init`. Instead, the shell injects a *factory closure*:

```swift
TitleScreenView(
    audio: audio,
    saveStore: saveStore,
    sessionFactory: { world in
        GameSession(world: world, audioEventConsumer: { audio.consume(events: $0) })
    }
)
```

When the player commits a layout/seed (or hits Continue), the title screen calls the factory with the chosen `World` and routes to `CityRootView(session: session)` via a SwiftUI navigation (`NavigationStack` on iOS, modal replacement on macOS).

**Why over alternatives**
- *Build session eagerly, hide game behind overlay*: the tick timer would already be ticking against a soon-to-be-discarded world. Wasted work, and the discard step is a subtle leak point.
- *Title screen in a separate app*: out of scope and gratuitously complex.

### D2. View-model split: title vs. new-game dialog

Two view-models, each `@Observable`:

- `TitleScreenViewModel` — owns the visible state on the title view (whether `Continue` is shown, latest-save metadata, navigation triggers).
- `NewGameDialogViewModel` — owns the dialog's selection state (layout, seed, custom-seed flag) and the validation that `Start` produces a constructible world.

The split lets the dialog be tested in isolation (no save store) and lets the title-screen view-model lean on a thin protocol for save metadata.

### D3. Most-recent-save lookup is a SaveStore extension

`CityPersistence.SaveStore` already keys games by `UUID`. The title screen needs to find the most-recent. Add:

```swift
public struct SaveMetadata {
    public let gameID: UUID
    public let writeDate: Date
    public let displayName: String   // formatted date for v0
}

public extension SaveStore {
    func listSaves() throws -> [SaveMetadata]
    func mostRecentSave() throws -> SaveMetadata?
}
```

`listSaves` scans the save directory; `mostRecentSave` returns the head sorted by `writeDate` descending. Both are pure file-system queries — no World decoding.

**Why over alternatives**
- *Index file*: too much machinery for one row of UI.
- *Load every save and pick newest*: O(N) decode work for a UI that may show one row.

### D4. Seed entry — numeric only in v0

The dialog offers three seed modes:

1. **Default** — `0`, matching today's `World.newGame()`.
2. **Random** — `SystemRandomNumberGenerator()` once at button-tap time; the chosen value is shown so the player can re-create the world later.
3. **Custom** — text field that accepts a `UInt64` literal (decimal). Invalid input disables `Start`.

Word-based seeds ("BRINY HARBOR" → SHA-256 → trunc UInt64) are an obvious follow-up but add an attack surface (consistent hashing across Swift versions, normalization rules) that v0 can do without.

### D5. macOS adds a `Quit` button; iOS does not

macOS title screens conventionally expose Quit; iOS apps don't have a quit affordance. Use `#if os(macOS)` to gate the button and call `NSApplication.shared.terminate(nil)` on tap.

### D6. Continue is hidden, not disabled, when no save exists

A first-run player should not see an inert button — it raises a question they shouldn't have to answer. The row disappears entirely when `mostRecentSave() == nil`.

### D7. Settings is reachable from the title screen

The existing settings surface (audio sliders + credits) is reachable from the title screen via a button that opens the same `Settings` Scene macOS already uses, and a sheet on iOS. No new settings UI.

## Risks / Trade-offs

- **Test isolation for the file-system query**: `mostRecentSave` reads from disk. Tests use a `SaveStore(rootDirectory:)` override pointing at a temp directory — same pattern as existing persistence tests.
- **No pause menu in v0**: a player who wants to abandon their game has to relaunch the app. Acceptable for v0; "in-game menu" is a separate change.
- **Title screen art**: this change deliberately ships a minimal typographic title. A subsequent `add-title-screen-art` change can drop in branded assets without disturbing the flow.
- **macOS window lifecycle**: replacing the window root mid-launch is well-supported by SwiftUI; the `App.body` returns a `NavigationStack` whose initial destination is the title and whose pushed destination is `CityRootView`.

## Migration Plan

There is no data migration. The current app boots into a fresh single-island world; after this change, it boots into the title screen with no save shown. A returning player on a freshly-installed build will see `Continue` only after their first session has auto-saved. The MVP play experience is preserved end-to-end: the default seed + layout in the dialog produces the same world today's zero-arg `newGame()` produces.

Rollback is a clean revert of the change's commits with no data implications.

## Open Questions

- **iPad split-view**: should the title screen fill the window or live in a sheet beside a faint preview of the underlying scene? v0 = full window. (Spec for follow-up.)
- **Auto-save trigger**: the spec assumes saves exist on disk. The actual auto-save cadence (every N ticks, on pause, on app-backgrounded) is owned by `add-autosave` — out of scope here. v0 surfaces "most recent" regardless of how it got there.
- **Seed display on the title screen**: do we ever show the player which seed their current game is using? Recommendation: nope, until a "share this world" feature exists. The dialog is the only place seeds surface.
