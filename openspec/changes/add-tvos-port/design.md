## Context

See proposal.md for why. The current state that shapes the approach:

- **Packages.** All six packages declare only `.iOS(.v18)` and `.macOS(.v15)`. CityCore is Foundation-only and builds on Linux.
- **Platform guards.** CityUI, CityRender2D and CityAudio use two styles:
  - `#if os(iOS)` for touch placement, tool-strip wording and the `confirmsBuildingPlacement` default (`CityUI.swift:291`).
  - `#if canImport(UIKit)` for the scene's touch handling (`IsoWorldScene.swift:103`, `:119`, `IsoWorldScene+LongPress.swift:3`) and for image loading. `canImport(UIKit)` is true on tvOS, so the touch code would compile into the TV build.
  - `PlatformAudioSession` already guards with `os(iOS) || os(tvOS) || os(visionOS)`.
- **tvOS-unavailable APIs in use:**
  - `DragGesture` and `MagnificationGesture` (`CityRootView+Gestures.swift`, attached at `CityUI.swift:53-54`)
  - `.textFieldStyle(.roundedBorder)` (`NewGameDialogView.swift:193`)
  - `Stepper` (manifest editor)
  - four `Slider`s (`AudioSettingsView.swift`: music, SFX, spatial reference, max distance)
  - `keyboardShortcut` (`BuildRailView`, `NewGameDialogView`, `PauseMenuView`, `StatusPillView`)
- **Camera.** `GameSession.handlePanDelta` and `handlePinch` mutate `world.camera`, which is stored in `World` and saved with the game as view state (`World.swift:96`). `Camera.pan` does not clamp; only zoom is clamped, to 0.25–4.0.
- **Pending placement** (`PendingPlacement.swift`) is platform-neutral session state. CityUI depends only on CityCore, so it uses its own `NudgeDirection` rather than CityRender2D's `IsoDirection`.
- **HUD layout** is computed by `HUDLayout.make(size:isPhone:isTouch:)` (`HUDDock.swift`). The hover tooltip delay is 0.5 s (`HoverTooltipController`).
- **Saves.** `SaveStore` takes an injectable `baseDirectory` and defaults to Application Support. The production CloudKit client and `listGames()` come from `add-cloudkit-client`.
- **Release pipeline.** The Fastfile `TARGETS` table uses `target:`, `match_platform:`, `upload_platform:` and `destination:` keys. The `release-please.yml` matrix calls `fastlane <lane_platform> release`.

## Goals / Non-Goals

**Goals:**

- Full play with the Siri Remote alone. A controller is optional.
- Every remote rule is decided by platform-neutral code that the macOS test run covers. `#if os(tvOS)` code only forwards system events.
- The tvOS build is compiled in CI from the first milestone on.

**Non-Goals:**

- Dynamic Top Shelf content, iPhone-as-remote, and multiplayer.
- A line tool for roads. This is a likely follow-up, but it would be a new interaction on every platform.
- iCloud sync on iOS and Mac, including the current-device banner and the "sync pending" indicator. That needs its own change.
- A TV-specific art style.

## Decisions

### D1. Reticle at screen center, camera center clamped to the map

The map moves under a fixed reticle. The reticle tile is always `Camera.centerTile()`. After every camera change on tvOS, `GameSession` clamps the center to `[0, mapWidth) × [0, mapHeight)`, so corner tiles stay reachable and the reticle never leaves the map. The clamp lives in the session, not in `Camera`, so CityCore is unchanged.

- _Alternative: a free cursor over a still map._ It needs edge panning and a second movement mode. Rejected.
- _Alternative: focusable tiles._ That means thousands of views, and focus search does not follow the iso grid. Rejected.
- _Alternative: clamp the viewport, not the center._ Corner tiles would then be unreachable. Rejected.

### D2. Directional clicks step along iso axes

The mapping is up → NE `(0, −1)`, right → SE `(+1, 0)`, down → SW `(0, +1)` and left → NW `(−1, 0)`, using CityUI's `NudgeDirection`. The reticle shows four hints naming the target tiles, so the 45° turn is visible.

- _Alternative: screen-aligned steps._ A step straight up the screen is a diagonal in tile space, `(−1, −1)` or `(+1, −1)`, and keeps the parity of x+y. Half the tiles could never be reached with clicks alone. Rejected.

### D3. One input owner per mode

Without a `GCEventViewController`, the Siri Remote's events reach both GameController and UIKit. A swipe would pan and also move focus, and one select would fire twice.

- **On the map:** the scene is hosted in a `GCEventViewController` (through a representable) with `controllerUserInteractionEnabled = false`. Everything is read from GameController:
  - the touch surface as an analog D-pad, for swipes
  - edge clicks as cardinal D-pad presses
  - the center press as select
  - Play/Pause
  - Back
- **In the HUD:** `controllerUserInteractionEnabled` switches to `true`, and the focus engine owns the remote.
- **Switching:** focus changes only on explicit actions: Play/Pause or Y, choosing a building, and Back from the HUD.

- _Alternative: SwiftUI `onMoveCommand`, `onExitCommand` and `onPlayPauseCommand` on the map._ `onMoveCommand` cannot tell an edge click from a swipe, and the focus engine would still move focus on swipes. Rejected.

How swipe and click values come through differs between remote generations. A simulator spike, with a hardware check, comes before the input milestone.

### D4. A platform-neutral `RemoteInputMapper` with an injected clock

`RemoteInputMapper` is a value type in CityUI, not inside `#if os(tvOS)`. Its input is a stream of normalised events:

- `swipe(dx, dy)`
- `click(direction)`
- `selectDown` / `selectUp`
- `playPauseDown` / `playPauseUp`
- `back`
- `menu`
- `zoomAxis(value)`
- `focusChanged`

Each event carries a timestamp from an injected clock. The mapper decides taps and holds (0.4 s), the steps in the Back order, painting, focus targets and reticle style, and calls `GameSession`.

`GameControllerAdapter` is also platform-neutral. It turns snapshots of controller and remote button states into the same events, so the controller mapping is tested on the host too. Only the `GCController` callbacks and the `GCEventViewController` host sit in `#if os(tvOS)`.

### D5. Placement follows the reticle and repeats

`confirmsBuildingPlacement` defaults on for iOS and tvOS. On tvOS, arming a building calls the existing pending-placement entry at `centerTile()`, and a new `pendingPlacementFollowsCamera` flag makes every camera change move the anchor through the existing clamped setter.

After a valid confirm, the mapper re-enters pending placement with the same kind, so building a row of houses costs one select each. Back cancels the placement and returns to inspect.

- _Alternative: show the iOS arrow HUD and move focus over it._ Four focus moves plus a click per tile. Rejected.

### D6. Road painting by toggle and clicks; demolish never paints

Select toggles `paintActive` for the road tool. While it is on, only `click` events paint, one place command per tile the reticle enters. Swipes pan without painting, because sampling a fast swipe once per frame skips tiles and leaves gaps in the road.

Demolish removes the player building under the reticle on select and nothing else, because a forgotten demolish toggle plus a swipe could level a district, and there is no undo. Each mode gets its own reticle style (idle, painting, demolish).

- _Alternative: paint while select is held._ Holding the clickpad while swiping on it is awkward, and a hold already opens the tile menu. Rejected.

### D7. Play/Pause is the HUD key; pausing goes through the pause menu

The remote has three app buttons: select, Back and Play/Pause. Select and Back are fully used on the map, so a short Play/Pause press toggles focus between the map and the HUD. Inside the HUD, focus sections (rail, top bar, inspector callout, route overlay) are linked with focus guides.

A long Play/Pause press on the map cycles three zoom levels. The simulation pauses through the pause menu (Back on an idle map) and the speed control.

- _Alternative: Play/Pause pauses the simulation, and focus enters the HUD by swiping past the map edge._ Swipes pan on the map, so that edge never comes. Rejected.

### D8. Back order and the Home screen

The order is fixed in `tv-remote-controls`, and the mapper walks it. The pause menu resumes on Back. The title screen attaches no exit handler, so Back reaches the system and the app returns to the Home screen, as Apple's tvOS guidance requires.

### D9. TV HUD layout in `HUDLayout.make`

`HUDLayout.make` gains an idiom parameter (`.phone`, `.pad`, `.mac`, `.tv`) that replaces `isPhone`/`isTouch`. The parameter is passed in, so the TV case is testable on macOS. The TV layout uses no extra margin because SwiftUI already applies the TV safe area (about 60/80 pt). The 66 pt minimum control height is a project choice for focus-highlight room, not an Apple rule.

- _Alternative: derive TV from a 1920-pt-wide view._ A large Mac window would get it. Rejected.

### D10. `SteppedValueControl` on tvOS only

A shared −/+ control with a tested `SteppedValue` type (value, step, range, label) replaces every `Slider` and `Stepper` on tvOS. Holding + or − repeats. iOS and Mac keep their native controls. It lands in M1, in place of throwaway placeholders.

### D11. tvOS saves on top of `add-cloudkit-client`

`SaveStore`'s default directory is Caches on tvOS. A `TVSaveSync` coordinator in CityPersistence:

- uploads after every save
- keeps a small pending-upload list in `UserDefaults`, under the 500 KB limit
- retries at the next save, at launch, and on becoming active
- at launch, lists records and downloads games that have no local copy before the title screen loads
- for a game that has both copies, uses the existing last-write-wins policy and its prompt

The title-screen notice reads account status through a `TitleScreenModel` seam in CityUI, so its scenario is a host test.

- _Alternative: the key-value store._ Its 1 MB total is too small. Rejected.
- _Alternative: iCloud Drive documents._ Not available on tvOS. Rejected.
- _Alternative: block play without iCloud._ Hostile. Rejected.

### D12. Release pipeline additions

- **Fastfile:** a `tv` entry in `TARGETS`:
  - `target: "CitybuilderTV"`
  - match platform `tvos`
  - upload platform `appletvos`
  - `generic/platform=tvOS`
  - an `.ipa` artifact

  The lanes go under fastlane's supported `platform :appletvos`, with `build` and `release` lanes like ios and mac.

- **Release matrix:** a `tvos` row in `release-please.yml` with lane platform `appletvos`.
- **CI:** `ci.yml` builds `CitybuilderTV` against `generic/platform=tvOS Simulator`, after making sure the tvOS simulator runtime is installed on the runner (`xcodebuild -downloadPlatform tvOS` when missing). The job is added to `ci-ok`'s `needs`.
- **Icon:** the generator writes `.brandassets` with 2–5-layer image stacks. Only the back layer is opaque; the front layers keep transparency for the parallax effect. Sizes:
  - App Icon 400×240 at @1x and @2x
  - App Store icon 1280×768
  - Top Shelf 1920×720 and Top Shelf Wide 2320×720, at @1x and @2x

### Determinism

No simulation code changes. Remote input ends in the same `GameSession` calls as touch and mouse input, and those enqueue the same `Command`s for the next tick boundary. Camera moves, including the new center clamp, change `World.camera` outside the tick, exactly as touch pan and pinch already do. `World.camera` is view state: it is saved but never read by any system, so replays of the same commands produce byte-identical simulation state. Reticle, painting, focus and mapper state live only in the session. They are never written into `World` and never saved.

### CityCore invariant

CityCore gains only the `.tvOS(.v18)` platform entry. No source file changes, and `scripts/check-no-apple-ui-imports.sh` keeps gating it. The camera clamp lives in CityUI's session, not in `Camera`.

## Risks / Trade-offs

- [Remote input differs between Siri Remote generations, and the simulator remote only approximates hardware] → An input spike before M2 confirms the event shapes. Tuning constants (swipe gain, dead zone) are isolated in the mapper. Hardware checks are deferred tasks.
- [Without an iCloud account, or while uploads keep failing, the system can purge Caches at any time and lose every city] → The notice states this plainly. Uploads happen right after each save and retry on three triggers. Exposure with a working account is the time between a save and its upload.
- [The focus engine and GameController ownership switch could leave the remote dead or doubled] → The handover is explicit and tested at mapper level (focus events). A tvOS-simulator walkthrough of every panel is a task.
- [Performance on Apple TV HD (A8), the tvOS 18 floor] → Measure fps on hardware (deferred).
- [The scenario-coverage gate is non-strict in CI, so uncovered scenarios slip through] → Each milestone ends with a strict local run of the coverage gate (`SCENARIO_COVERAGE_STRICT=1`). Making CI strict is out of scope for this change, because existing scenarios may fail it.

## Migration Plan

The change is additive: a new target and new platform branches. iOS and Mac behaviour is unchanged. The guard narrowing compiles the same on iOS, and the `HUDLayout.make` idiom parameter maps one-to-one onto today's flags. To roll back, remove the `tvos` row from the release matrix.

## Open Questions

- Exact swipe gain and dead-zone values. They are tuned on hardware and change no spec.
- Whether a static Top Shelf image is enough long-term. It does not affect this change.
