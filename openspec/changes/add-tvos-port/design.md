## Context

See proposal.md for why. The current state that shapes the approach:

- Every local package declares `.iOS(.v18)` and `.macOS(.v15)` only. CityCore is Foundation-only and already compiles on Linux, so adding tvOS to it is a manifest change.
- Platform branches in CityUI, CityRender2D and CityAudio use two guard styles: `#if os(iOS)` (touch placement, tool strip wording, the audio session) and `#if canImport(UIKit)` (the scene's touch handling, long-press recogniser, sprite and icon loading). `canImport(UIKit)` is true on tvOS, so the second style silently pulls touch code into the TV build.
- Map input goes through `GameSession`: `handlePanDelta(deltaX:deltaY:)` converts screen pixels to tile-space camera moves, and `handlePinch(factor:)` zooms. Pending placement (`add-touch-first-placement`) is a session state machine with confirm, cancel and nudge transitions, and it is platform-neutral apart from the iOS views.
- `Camera.centerTile()` already exists, with floor semantics.
- `SaveStore` writes to Application Support. `CloudKitSync.swift` defines a `CloudKitClient` protocol (`upload`, `fetchLatest(gameID:)`, `isAccountAvailable`) and an `InMemoryCloudKitClient` for tests. No production client talks to `CKContainer` yet, nothing calls the protocol, and it cannot list a user's games.
- The release pipeline (`fastlane/Fastfile` `TARGETS`, the `release-please.yml` matrix) is table-driven. The match `tvos` profile and the ASC tvOS platform already exist.

## Goals / Non-Goals

**Goals:**

- Full play on Apple TV with the Siri Remote alone. A game controller is a convenience, not a requirement.
- All remote-to-intent logic lives in platform-neutral types that the existing macOS test runs cover. `#if os(tvOS)` only wires system callbacks to those types.
- Internal TestFlight builds for tvOS from the same release tag as iOS and Mac.

**Non-Goals:**

- Top Shelf extension with dynamic content. A static Top Shelf image only.
- Multiplayer or companion-device control (iPhone as remote).
- A redesigned TV-first art style. The terrain surface renderer in progress elsewhere is independent, and any Metal or SpriteKit shader it adds is available on tvOS.
- Turning on iCloud sync for iOS and Mac. This change builds the production CloudKit client, and only the tvOS save path uses it. The general sync rollout stays its own change.

## Decisions

### D1. Reticle at screen center instead of a free-moving cursor

The remote has no pointer. The reticle is fixed at screen center, and the map moves under it, so the reticle tile is always `Camera.centerTile()`.

- _Alternative: a cursor that moves across a still map, panning at the edges._ This needs two movement modes, makes edge panning fiddly with swipes, and means a new screen-to-tile path that iOS and Mac do not have. Rejected.
- _Alternative: focus engine over tiles (each tile focusable)._ Thousands of focusable views, and the focus engine's spatial search does not follow the iso grid. Rejected.

The center reticle reuses existing camera math, and placement, painting and selection all read one tile.

### D2. Directional clicks map to iso axes, rotated 45°

Up → NE `(0, −1)`, right → SE `(+1, 0)`, down → SW `(0, +1)`, left → NW `(−1, 0)`, reusing `IsoDirection.tileOffset`. A click moves the camera by exactly that offset, so the reticle steps one tile.

- _Alternative: screen-aligned steps (up moves the view straight up)._ A straight screen step is half a tile diagonally in iso terms, so it lands between tiles and a click would sometimes not change the reticle tile. Rejected.

The rotation matches the rendered tile edges, and it is the same mapping as the iOS nudge arrows.

### D3. Placement anchor follows the reticle; no arrow HUD on tvOS

On tvOS the pending anchor tracks `centerTile()` on every camera change, select confirms, and Back cancels. The iOS `PlacementHUD` arrows are not rendered.

- _Alternative: render the iOS arrow HUD and move focus between arrows._ Four focus moves plus a click to nudge one tile is slower than one directional click. Rejected.

`GameSession` gets a `pendingPlacementFollowsCamera` flag, set on tvOS. When it is set, a camera change calls the existing anchor setter, which clamps like nudging does.

### D4. Toggle painting for road and demolish

Select toggles a `paintActive` state. While it is on, each new `centerTile()` gets the armed tool once, de-duplicated per tile within a stroke.

- _Alternative: paint while select is held._ Holding the clickpad while swiping on it is awkward on the Siri Remote, and holding select is already press-and-hold for the tile menu. Rejected.
- _Alternative: line tool (pick start and end)._ Better for long straight roads, but it is a new interaction on every platform. Left as a follow-up.

### D5. One platform-neutral `RemoteInputMapper` in CityUI

A value type converts remote events (`.swipe(dx, dy)`, `.click(direction)`, `.select`, `.selectHeld`, `.back`, `.playPause`, `.zoom(step)`) into `GameSession` calls and focus changes. It is not inside `#if os(tvOS)`, so swift-testing on the macOS host covers every scenario in `tv-remote-controls`. The tvOS views only translate `onMoveCommand`, `onExitCommand`, `onPlayPauseCommand`, the select press and GameController callbacks into mapper events.

- _Alternative: put the logic inside the `#if os(tvOS)` views._ It would be untestable in CI, because `swift test` runs on macOS. Rejected.

### D6. Narrow touch guards from `canImport(UIKit)` to `os(iOS)`

Wherever a `canImport(UIKit)` branch handles touch locations or gesture recognisers, the guard becomes `os(iOS)`. Branches that only load images or colours keep `canImport(UIKit)`, which tvOS shares.

- _Alternative: keep the guards and ignore touches at runtime on tvOS._ The remote's touch surface delivers `UITouch`es with locations relative to the pad, which would turn into taps on random tiles. Rejected.

### D7. tvOS saves: Caches plus CloudKit as the durable copy

tvOS gives apps no persistent local storage, so `SaveStore` defaults to Caches on tvOS. After every write, the tvOS app queues an upload through a `CloudKitClient`. At launch it downloads newer or missing records before the title screen lists saves. With no iCloud account it shows a notice and keeps going.

- _Alternative: `NSUbiquitousKeyValueStore`._ Its 1 MB total quota is too small for city saves. Rejected.
- _Alternative: iCloud Drive documents._ Not available on tvOS. Rejected.
- _Alternative: refuse to play without iCloud._ That is hostile, and App Review dislikes hard account gates. Rejected in favour of the notice.

This needs two things the persistence layer lacks today. First, `CloudKitClient` gains `listGames()`, which returns the game ID and modification date for each record, so launch can find saves missing from Caches. Second, a production `CKContainerClient` implements the protocol against the private database, using the record type and `CKAsset` body from `icloud-sync`. Its live tests stay behind `CITYBUILDER_CLOUDKIT_TESTS=1`, per the original D13. The save format and migration pipeline do not change, and `SaveStore` gains only a platform default for its directory.

### D8. TV HUD layout as a fourth `HUDMetrics` case

`HUDMetrics.layout(for:)` gains an idiom parameter, default derived from the platform, and returns a TV layout on tvOS: rail with labels, menus unfolded, margins 60/80, 66 pt minimum control height. The parameter keeps it testable on macOS.

- _Alternative: derive TV from the screen size (1920 wide)._ A large Mac window would get the TV layout. Rejected.

### D9. −/+ steppers replace `Stepper` and `Slider` on tvOS only

A shared `SteppedValueControl` view (−, value, +) backs the manifest editor quantities and the audio volumes on tvOS. iOS and Mac keep their native `Stepper` and `Slider`. The step and clamp logic sits in a tested value type.

### D10. CloudKit, GameController: system frameworks only

GameController and CloudKit are Apple frameworks, so the "Apple frameworks only" rule holds, and there is no new build tool.

### D11. Release pipeline additions

Add a `tv` entry to the Fastfile `TARGETS` (scheme `CitybuilderTV`, match platform `tvos`, upload platform `appletvos`, destination `generic/platform=tvOS`, `.ipa`). Add a `tvos` row to the `release-please.yml` matrix with lane platform `tv`. Add `build (CitybuilderTV)` with `generic/platform=tvOS Simulator` to `ci.yml`, and add it to `ci-ok`'s `needs`. `scripts/check-ios-icon-opaque.sh` is not reused: tvOS icons are layered image stacks, and the generator writes opaque layers by construction.

### Determinism

No simulation code changes. Remote input ends in the same `GameSession` calls as touch and mouse input, which enqueue the same `Command`s for the next tick boundary. Camera, reticle, painting and focus state are session-local UI state. They are never written into `World` and never saved, so `World` stays byte-identical under replay.

### CityCore invariant

CityCore gains only the `.tvOS(.v18)` platform entry. No source file changes, and `scripts/check-no-apple-ui-imports.sh` continues to gate it. `IsoDirection` stays in CityRender2D, and `RemoteInputMapper` lives in CityUI.

## Risks / Trade-offs

- [The Siri Remote's swipe has momentum and varies between remote generations] → Pan from `GCMicroGamepad` D-pad axis values with a dead zone and a speed curve, tuned on hardware (a deferred task). The mapper takes normalised deltas, so the tuning is one constant.
- [Caches can be purged while the app is suspended, before an upload completes] → Upload immediately after each save, not batched. The notice covers the no-account case. A purge between save and upload loses at most one autosave interval.
- [The production CloudKit client is new code that the iOS and Mac apps do not exercise yet] → Every `icloud-sync` scenario runs against `InMemoryCloudKitClient`. `CKContainerClient` gets a gated live test and a hardware check on Apple TV (a deferred task). The CloudKit schema must be deployed to production in the CloudKit console before the first TestFlight build (a deferred task).
- [The HUD is designed for touch and pointer, and some panels may trap focus or be unreachable] → Every sheet gets an explicit default focus and a Back exit. A tvOS-simulator walkthrough of every HUD panel is a task, done with the verify skill.
- [Performance on Apple TV HD (A8)] → The deployment target is tvOS 18, which runs on Apple TV HD. Treat the A8 as the floor, and measure fps on hardware (a deferred task).
- [Layered icon and Top Shelf assets block App Store Connect validation if missing] → Generate them in the first milestone and run `altool --validate-app` on the first tvOS archive before relying on CI.

## Migration Plan

Additive: a new target and new platform branches. iOS and Mac behaviour is unchanged, apart from the `canImport(UIKit)` → `os(iOS)` guard narrowing, which compiles identically on iOS. Roll back by removing the tvOS row from the release matrix. Builds already on TestFlight stay internal.

## Open Questions

- Exact swipe speed curve and dead zone. Tuned on hardware and does not change the specs.
- Whether a static Top Shelf image is enough, or a carousel of city screenshots is wanted later. It does not affect this change.
