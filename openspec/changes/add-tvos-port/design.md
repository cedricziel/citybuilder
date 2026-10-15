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

Decided during M2: each hint is an arrow drawn on the tile a click steps to, pointing along the iso axis, rather than the tile's coordinates, which read as debug output. An arrow whose tile is off the map is dimmed.

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

Spike findings (task 2.1, tvOS 27 simulator, Xcode 27). Xcode 27 has no Simulator.app, so the remote was driven with `XCUIRemote` from the UI-test target. The spike hosted a `GCEventViewController` (`controllerUserInteractionEnabled = false`) over the map and logged both GameController handlers and `pressesBegan`/`pressesEnded`.

- **Not in the focus chain, nothing arrives.** As a plain overlay the controller never became first responder, and every press went to the SwiftUI focus engine. The host must own a focusable view, and focus must sit on that view while the map has focus.
- **Focused, presses arrive as `UIPress`.** With the host's view focused (reached by a right press from the rail), presses arrived as `UIPress` events: right, down and left arrows (types 3, 1, 2), select (4) and Play/Pause (6). The first up press after focus landed did not arrive. Holding select for one second gave `began` and `ended` one second apart, so hold timing can be read from `UIPress`.
- **Focus stays on the map.** While the map held focus, arrow presses did not move focus to the rail.
- **No GameController events from `XCUIRemote`.** A virtual controller connects (vendor "Gamepad", micro and extended profiles), but its handlers never fired. The simulator's `XCUIRemote` events are synthesised `UIPress`es.
- **Swipes cannot be simulated.** `XCUIRemote` has no touch-surface input, so swipe deltas, edge clicks and both remote generations stay with the hardware check (6.1).

Consequences for M2:

- The tvOS host feeds the mapper from two sources: `UIPress` events for clicks, select, Play/Pause and Back, and `GCController` for the remote's touch surface (swipes) and for extended controllers.
- On hardware, with `controllerUserInteractionEnabled = false`, the Siri Remote's buttons reach only GameController, so the GameController path must also produce clicks and select. The adapter drops a `UIPress` that duplicates a GameController event within 50 ms, so one press acts once on both the simulator and hardware.
- Back on a focused map arrives as a `UIPress` of type `.menu`. The host must handle it, or the system takes the app to the Home screen, which is the known gap against D8.

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

Decided during M2: the anchor follows the camera under the same session flag that keeps the camera center on the map (`clampsCameraToMap`), not a separate `pendingPlacementFollowsCamera` flag. Both rules exist only for the reticle, and a clamped camera with a free anchor, or the reverse, is never wanted.

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

The order is fixed in `tv-remote-controls`, and the mapper walks it.

Decided during M2: the mapper handles only the steps that live on the map. Sheets (Goals, Research, Standings, Routes, Settings, the manifest editor and the pause menu) take focus when they open, so the system closes them on Back and the mapper never sees that press; the host reports the focus move, and the next Back reaches the map. The build rail's drawer is part of the HUD, whose exit command closes it before it returns focus to the map. The tile menu is session state (`tileMenuRequest`), so the mapper closes it. The pause menu resumes on Back. The title screen attaches no exit handler, so Back reaches the system and the app returns to the Home screen, as Apple's tvOS guidance requires.

### D9. TV HUD layout in `HUDLayout.make`

`HUDLayout.make` gains an idiom parameter (`.phone`, `.pad`, `.mac`, `.tv`) that replaces `isPhone`/`isTouch`. The parameter is passed in, so the TV case is testable on macOS. The TV layout uses no extra margin because SwiftUI already applies the TV safe area (about 60/80 pt). The 66 pt minimum control height is a project choice for focus-highlight room, not an Apple rule.

- _Alternative: derive TV from a 1920-pt-wide view._ A large Mac window would get it. Rejected.

Decided during M3:

- **Idiom-derived properties.** `HUDLayout` keeps `isPhone`, derived from the idiom, because the views read it. `isTouch` moves to `HUDIdiom`. The rail's hotkey letters now depend on a new `showsHotkeys` (Mac only), so they do not appear on Apple TV. iOS and Mac values are unchanged.
- **Tool strip hints.** `ToolStripText.hint` takes the idiom and a `paintingRoad` flag. The flag only matters on Apple TV, and the painting state it reads arrives with M2.
- **Rail buttons.** The 66 pt minimum applies to the rail buttons through `HUDLayout.focusableHeight`. Other HUD controls already take `controlHeight`, which is 66 on TV.
- **Focus sections.** The top bar, the rail (or dock), the inspector callout and the route overlay each become one SwiftUI `focusSection()` on tvOS only. That stands in for UIKit focus guides.
- **Audio session test.** The platform-neutral test seam is `PlatformAudioSession.sessionSettings(for:)`, and the real session code applies those settings.

### D10. `SteppedValueControl` on tvOS only

A shared −/+ control with a tested `SteppedValue` type (value, step, range, label) replaces every `Slider` and `Stepper` on tvOS. Holding + or − repeats. iOS and Mac keep their native controls. It lands in M1, in place of throwaway placeholders.

Decided during M1:

- `SteppedValue` and `SteppedValueControl` live in CityUI, which the manifest editor already belongs to. CityAudio, which owns `AudioSettingsView`, now depends on CityUI so both screens share one control. CityUI does not depend on CityAudio, so there is no cycle.
- Hold-to-repeat uses SwiftUI's `buttonRepeatBehavior(.enabled)`, not a custom timer.
- The spatial distances step by 1 (reference, 1–16) and by 4 (max, 8–64).
- `DisclosureGroup` is unavailable on tvOS, so the two spatial distance controls show inline there instead of under "Advanced".

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

Decided during M4:

- **No existing prompt.** `ConflictPolicy` existed, but no prompt did. `TVSaveSync.launch()` therefore never overwrites a local save that is older than its remote copy; it reports that game as a conflict. The title screen then asks "A newer save is in iCloud", offering Load iCloud Save or Keep This Save, and `resolveConflict` replaces the other copy.
- **A newer local save is uploaded at launch** without a prompt. It is this device's own unsent save, which is what `ConflictPolicy` already decides.
- **Comparing local and remote saves.** The local save's date is its file modification date. After every upload or download, `TVSaveSync` sets that date to the record's `modificationDate`. Dates within one second count as equal, since file timestamps do not round-trip a `Date` exactly. Without this, every launch would report the device's own upload as a newer remote save.
- **Corrupt remote saves.** A downloaded save is decoded first and is skipped if it fails.
- **Seam name.** The seam is `TitleScreenCloudSync`, passed into the existing `TitleScreenViewModel`; there is no separate `TitleScreenModel`. The restore runs in a `.task` on the title view, and the Continue row is re-read after it.
- **Every Apple TV shares one game ID.** A pending upload can therefore be older than a save another Apple TV uploaded since. Before each pending upload, `TVSaveSync` lists the remote dates and runs `ConflictPolicy`; a newer remote copy is reported as a conflict, and the save stays pending until the player resolves it. `TVSaveSync` also stores the record of each game's last upload or download on this device. When the remote copy is still that record, the local save is newer even if its file date is earlier, which happens when the save was written while its upload was in flight. The record is identified by its CloudKit change tag, which `CloudRecord` and `CloudRecordSummary` now carry; the date, within one second, is only a fallback for records synced before tags were stored. All Apple TVs upload as "Apple TV", so the device name cannot tell their uploads apart. The upload is conditional on what was listed: `CloudKitClient.upload` takes an `UploadExpectation` (the listed change tag, or no record), and `CloudKitDatabaseClient` saves with `.ifServerRecordUnchanged`. A record another device saved between the listing and the upload makes CloudKit refuse the save (`serverRecordChanged`, mapped to `SyncError.recordChanged`); the save stays pending, and the next listing decides it.
- **One sync pass at a time.** Launch, becoming active and each save can each start a pass. Passes run one after another, in call order. A pass removes from the pending list only the games it settled. It sets a file's date to the record's date only if the file has not changed since the pass read it.
- **Launch uploads local-only saves.** A save written just before the app quits may never reach the pending list. Launch therefore uploads every local save that has no remote record, as `ConflictPolicy` decides.
- **The title screen waits for the launch listing and downloads, not the uploads.** Continue and New Game are disabled, with a progress indicator, until `launch()` returns. Otherwise the player could continue a stale save, or start a game that the restore then overwrites. `launch()` returns once listing and downloads finish; uploads run in the next pass. A retry when the app becomes active does nothing until `launch()` has run, so it cannot queue ahead of the launch pass. A download is not written if a local save appeared while it downloaded.
- **Timeouts.** Every CloudKit call `TVSaveSync` makes gives up after 30 seconds and counts as offline. Cancelling the caller cancels the call, and the timer stops when the call ends. A call that ignores cancellation is left to finish. An upload that lands after its timeout is not recorded as this device's, so its iCloud copy can look newer than the local save. Before reporting such a conflict, `TVSaveSync` downloads the iCloud copy; if its bytes equal the local save, it takes that record as synced instead.
- **Keeping the local save checks the iCloud copy again.** A conflict remembers the iCloud record it was decided against. Keep This Save lists iCloud again and uploads only if the record is unchanged, conditionally on that record's change tag; if the record changed before or during the upload, it reports `superseded`, the conflict stays, and the alert asks again.
- **Failed conflict resolution.** If the iCloud copy cannot be loaded, or iCloud cannot be reached, the conflict stays and the alert shows an error.
- **Pending list storage.** `TVSaveSync` takes a `UserDefaults` suite name rather than an instance, because `UserDefaults` is not `Sendable`.

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

  M1 uses three layers: buildings in front, terrain in the middle, and an opaque navy back. Each layer is the icon's island scaled by a whole factor, so the pixel art stays crisp.
- **CI runtime:** building for `generic/platform=tvOS Simulator` needs the tvOS SDK but not the simulator runtime (confirmed locally with Xcode 27). The CI step still installs the runtime when it is missing, as a guard for Xcode versions that require it.

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
