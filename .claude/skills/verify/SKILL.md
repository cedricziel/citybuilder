---
name: verify
description: Build, launch, and drive Citybuilder in the iOS or tvOS Simulator to observe a change at runtime.
---

# Verify Citybuilder at runtime

## Build

```bash
xcodegen generate
xcodebuild -project Citybuilder.xcodeproj -scheme CitybuilderiOS \
  -destination 'platform=iOS Simulator,id=<UDID>' -derivedDataPath <scratch>/dd-ios build
xcodebuild -project Citybuilder.xcodeproj -scheme CitybuilderMac \
  -destination 'platform=macOS' -derivedDataPath <scratch>/dd-mac CODE_SIGNING_ALLOWED=NO build
```

- The Makefile's `DESTINATION_IOS` names `iPhone 16`, which may not be installed. Pick a UDID from `xcrun simctl list devices available`.
- The app lands at `<scratch>/dd-ios/Build/Products/Debug-iphonesimulator/Citybuilder.app`. The bundle id is `com.cedricziel.citybuilder`.

## Launch

1. `xcrun simctl boot <UDID>`, then attach the simulator panel.
2. The first `launch` after a cold boot can time out. If it does, run `xcrun simctl launch --terminate-running-process <UDID> com.cedricziel.citybuilder`.
3. The app has no logging of its own. `log show --predicate 'process == "Citybuilder"'` only shows UIKit noise.

## Flows worth driving

- **Title:** New Game… → Single Island / Default seed → Start.
- **Town for art shots:** launch with `-uiTestSeedTown` (Debug only); New Game then starts on the seed-0 island with four finished houses beside the town center. The `iso-sprite-authoring` skill covers before/after shots.
- **Build:** Arm a palette button, then tap a grass tile.
  - Starting stock is wood 6 / planks 5 / food 2.
  - Lumberjack (2 wood, $80) succeeds; a house (4 planks) fits too.
  - Locked buildings show a lock and are rejected with "Needs <Tech> research".
- **Camera:** Pinch with two fingers (`touch2_path`) to zoom out and read the whole island.
- **Pause:** The pause button opens the menu. Tap Save Game ("Saved" appears), then Quit to Title. The title screen should now offer Continue, which restores money, buildings, and camera.

## Apple TV

The tvOS simulator runtime is a separate download of several GB. Check `xcrun simctl list runtimes | grep tvOS` first, and run `xcodebuild -downloadPlatform tvOS` only with enough free disk. Building for `generic/platform=tvOS Simulator` works without the runtime; launching does not.

1. Pick an Apple TV simulator: `xcrun simctl list devices available | grep 'Apple TV'`.
2. Build:

   ```bash
   xcodebuild -project Citybuilder.xcodeproj -scheme CitybuilderTV \
     -destination 'platform=tvOS Simulator,id=<UDID>' -derivedDataPath <scratch>/dd-tv build
   ```

3. The app lands at `<scratch>/dd-tv/Build/Products/Debug-appletvsimulator/Citybuilder.app`. Install and launch it with `xcrun simctl boot <UDID>`, `xcrun simctl install <UDID> <app>`, then `xcrun simctl launch <UDID> com.cedricziel.citybuilder`.
4. Screenshots: `xcrun simctl io <UDID> screenshot <file>.png`.
5. Remote presses: Xcode 27 ships no Simulator.app, so drive the remote from the `CitybuilderTVUITests` UI-test target (`Apps/CitybuilderTVUITests/TVWalkthroughTests.swift`). It presses `XCUIRemote` buttons, asserts focus, and saves a screenshot per step:

   ```bash
   TEST_RUNNER_WALKTHROUGH_DIR=<scratch>/walk xcodebuild test -project Citybuilder.xcodeproj \
     -scheme CitybuilderTV -destination 'platform=tvOS Simulator,id=<UDID>' \
     -derivedDataPath <scratch>/dd-tv [-only-testing:CitybuilderTVUITests/TVWalkthroughTests/<test>]
   ```

   - Add a test for each new flow. Its `focus(_:)` helper presses toward an element until it holds focus.
   - Each test launches with `-uiTestResetSaves`, which the Debug app honours by deleting its save folder and swapping in an empty pending-upload list and a signed-out, in-memory iCloud, so saves from manual runs (step 6) or from iCloud do not move the title's focus to Continue.
   - The test creates the screenshot folder and fails when it cannot write a screenshot.
   - `-uiTestSeedPort` (Debug only) starts a Renaissance game with a player port under the camera, for the Routes and manifest-editor walks.
   - The test class is `@MainActor` and has no `setUp`, because Swift 6 isolation rejects an override there.
   - With an older Xcode that still has Simulator.app, choose I/O > Show Apple TV Remote, or use the keyboard with the simulator window focused (arrow keys move, Return selects, Escape is Back, Space is Play/Pause).
6. Saves live in Caches on Apple TV: `xcrun simctl get_app_container <UDID> com.cedricziel.citybuilder data` then `Library/Caches/Citybuilder/saves/`.

## Gotchas

- **One simulator per session.** Parallel sessions on this repo install builds with the same bundle id. If two share a simulator, each overwrites the other's app and data container: saves appear or vanish, and Continue fails with errors from code you didn't write. Pick a simulator no other session is using, and when the app misbehaves, check `log show --predicate 'process == "Citybuilder"'` for messages your branch doesn't contain.
- **Continue row loads asynchronously.** Right after launch, New Game sits where Continue will appear. Wait about 3 s before tapping.
- **Finding a tile's screen position.** With no tool armed, tap a building; the inspector shows its anchor. From two such points you can work out the tile pitch (at zoom 1 an x-step is about (+32.5, +16) pt).

- **Stale art after sprite changes.** Incremental `xcodebuild` doesn't recompile an `*.atlas` folder when PNGs inside it change, because the folder's own timestamp stays the same. Run `touch Resources/*.atlas` before building, then check that the timestamp of `Citybuilder.app/Terrain.atlasc/Terrain.1.png` is new.

- Sheet transitions are slow. Take a second screenshot before deciding a tap failed.
- To check art, render the files in `Resources/*.atlas/*.png` onto a magenta contact sheet with PIL. Wrong-image bugs are obvious there and hard to see in-game.
- **Tap coordinates on the iPhone 17 Pro Max.** Screenshots come back 921×2000 (from 1320×2868); device points are screenshot pixels × 0.478. The Continue button is near (220, 475), New Game near (220, 553), the dialog's Start near (384, 615–670) depending on how many sections the dialog has.
- **Build only what's committed.** When the working tree holds unfinished work, build HEAD from a throwaway worktree: `git worktree add --detach <scratch>/verify-head HEAD`, then `xcodegen generate` and `xcodebuild` there with its own `-derivedDataPath`.
- **Seasons take time.** A season lasts one minute of game time, so winter starts three minutes into a new game. Use the wait for other work instead of polling.
