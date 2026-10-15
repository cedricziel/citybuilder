## Why

Nothing in the interface makes a sound: not the title menu, the build rail, picking a tool, inspecting a building or pausing. Without that small tactile feedback, the game feels unresponsive, especially on Apple TV, where the screen is across the room.

## What Changes

- CityUI names five interface sounds: `tap`, `select`, `toggle`, `open` and `close`. It plays them through `UISounds.sink`, a hook the app shell sets at launch, so CityUI still does not depend on CityAudio.
- Each sound has a trigger:
  - `tap`: the title menu's Continue, New Game and Settings; inspecting a tile.
  - `select`: picking a build tool.
  - `toggle`: pausing and resuming.
  - `open` and `close`: opening and closing a build drawer.
  - `reject`: a placement the rules reject. The UI rejects it before the simulation sees it, so the `placementRejected` binding from `add-event-sounds` never fires; `ui.reject` plays the same two knocks.
- `AudioStack.playInterfaceSound(_:)` plays the cue bound to `ui.<name>` in `bindings.json` on the `sfx` bus. A name without a binding plays nothing.
- There are five new generated sounds, all soft wooden and paper sounds, quieter than event sounds:
  - `tap`: a light wooden tick;
  - `select`: two quick, bright ticks;
  - `toggle`: a latch clicking over;
  - `open`: parchment unfurling;
  - `close`: parchment rolled up, with a soft thud.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `audio-playback`: a new requirement, "Interface sounds are bound by name".
- `platform-shells`: a new requirement, "Interface actions make a sound".

## Impact

- **CityUI:**
  - New `UISound` and `UISounds`.
  - Calls from `TitleScreenViewModel`, `BuildRailModel.toggle`, `GameSession.selectTool`, `GameSession.handleTap` and `GameSession.isPaused`.
- **CityAudio:** `AudioStack.playInterfaceSound(_:)`.
- **Apps:** each shell sets `UISounds.sink`.
- **Resources:** five files under `ui/`, their manifest entries and their bindings.
