## Why

The app currently boots directly into a fresh single-island world via `World.newGame()` — no menu, no player choice, no resume of a previous session. That was fine for the MVP because there was nothing to choose, but `add-archipelago-and-sea` introduced a second world layout (`.archipelago`) whose `newGame(layout:seed:)` factory is currently reachable only from tests and the determinism fixture. There is no surface where the player can pick which world they want to play.

The pragmatic next step is a small title screen + new-game dialog. This is the smallest UI that makes the existing simulation work choice-driven without painting ourselves into a corner for the bigger flows that will follow (save list, profile menu, options for `add-island-specialization`'s climate-gated content).

## What Changes

- Add a **title-screen** capability that owns the pre-simulation app flow on iOS and macOS.
- The app launches into the title screen instead of the live `IsoWorldView`. The screen shows the game name, the most recent save (if any), and three primary actions: `Continue`, `New Game…`, `Settings`. macOS adds a `Quit` button.
- `Continue` loads the most recent save via `CityPersistence.SaveStore` and hands the resulting `World` to `GameSession`. It is shown only when a save exists; otherwise the row is hidden.
- `New Game…` opens a modal **new-game dialog** that lets the player:
  - Choose a `WorldLayout` (Single Island or Archipelago).
  - Choose a seed: either the default (zero) or a randomized 64-bit integer; a tertiary affordance lets the player type a custom seed.
  - Confirm with `Start`, which constructs the world via `World.newGame(layout:seed:)` and transitions to the live game.
- `Settings` opens the existing settings surface (audio sliders + credits) without entering the simulation.
- Introduce a `GameSessionFactory` seam so the app shell can defer `GameSession` construction until the player commits a world. Today the shell builds `GameSession` eagerly in the app's `init`; the title screen needs to delay that until the player picks.
- Saves are owned by a per-game `UUID` (already in `SaveStore`). The title screen reads the "most recent" save by scanning the save directory for the newest write time.

## Capabilities

### New Capabilities

- `title-screen`: Boot flow with the title view, the new-game dialog, the layout + seed picker, and the continue path. View-models testable in isolation; SwiftUI views delegate all state to them.

### Modified Capabilities

- `persistence-save-load`: Add a `mostRecentSave() -> SaveMetadata?` query (gameID + write date + display label) so the title screen can populate the `Continue` row without loading the whole world.

## Impact

- **App shell**: `CitybuilderiOSApp` / `CitybuilderMacApp` switch their `WindowGroup` root from `CityRootView(session:)` to `TitleScreenView(...)`. Once the player picks, the title screen pushes / replaces with `CityRootView`. macOS uses a single window; iOS uses a stack-style transition.
- **CityUI**: new `TitleScreenViewModel`, `NewGameDialogViewModel`, and their views. No changes to `CityRootView` or `GameSession` internals beyond an injectable factory closure (the shell already does this for audio).
- **CityPersistence**: one new query method, no schema change. The existing `SaveStore.list()` (if present) or a new directory-scan is the source of truth.
- **No save-format change.** A `seed: UInt64` and `layout: WorldLayout` already persist on `World` as of `add-archipelago-and-sea`. The title screen reads them via the loaded `World`.
- **No new third-party dependencies.** Pure SwiftUI on the view side, Foundation on the view-model side.
- **Default behavior**: if the player hits `Start` without changing anything in the new-game dialog, they get the same world today's `World.newGame()` produces — `.singleIsland`, seed `0`. The MVP play experience is preserved.
- **Out of scope, intentionally deferred**:
  - Save slot management UI (rename, delete, list). v0 surfaces only "most recent".
  - In-game pause menu / return-to-title navigation. The current app has no pause menu; adding one is a separate change.
  - Title-screen art / animation / music. v0 ships a minimal typographic title; theming is `add-title-screen-art` territory.
  - iCloud cross-device save selection. Existing iCloud sync covers settings; full game-save iCloud is a follow-up.
  - Tutorial / first-run onboarding.

## Dependencies

- **Requires (must precede this change)**: `add-archipelago-and-sea` to be archived. The new-game dialog directly exposes `WorldLayout.archipelago`; without that change there is no layout to choose.
- **Blocks (must precede those changes)**: `add-island-specialization`. Once climate-gated buildings ship, players will need a visible choice of world; this change is the chassis for that choice.

## Open questions

- **Seed entry**: numeric field, hex, or word-based ("BRINY HARBOR" → hash)? Recommendation: numeric for v0, word-based is a polish follow-up.
- **iPad split**: should the title screen on iPad fill the window or live in a sheet next to a preview? Recommendation: full-window for v0; preview is an aesthetic improvement, not a requirement.
- **Continue affordance on a fresh install**: hidden (current proposal) or shown disabled with a tooltip? Recommendation: hidden; a disabled control invites guesswork.
