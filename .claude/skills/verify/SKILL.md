---
name: verify
description: Build, launch, and drive Citybuilder in the iOS Simulator to observe a change at runtime.
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
- **Build:** Arm a palette button, then tap a grass tile.
  - Starting stock is wood 6 / planks 5 / food 2.
  - Lumberjack (2 wood, $80) succeeds; a house (4 planks) fits too.
  - Locked buildings show a lock and are rejected with "Needs <Tech> research".
- **Camera:** Pinch with two fingers (`touch2_path`) to zoom out and read the whole island.
- **Pause:** The pause button opens the menu. Tap Save Game ("Saved" appears), then Quit to Title. The title screen should now offer Continue, which restores money, buildings, and camera.

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
