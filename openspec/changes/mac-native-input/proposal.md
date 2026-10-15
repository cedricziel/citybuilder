## Why

On the Mac, Esc does nothing: it neither closes what is open nor pauses the game. A two-finger trackpad scroll does not move the map, a mouse wheel cannot zoom, and pinch zooms on the view's center instead of the cursor. A Mac city builder should take the trackpad, the mouse and the keyboard the way other Mac apps do.

## What Changes

- Esc in the Mac game window closes the topmost open thing: a placement, the build drawer, an armed tool, route mode, the inspector's details (where the market lives), then the inspector. On an idle map Esc opens the pause menu. In a sheet, Esc closes the sheet; in the pause menu it resumes.
- A two-finger trackpad scroll pans the map and keeps its momentum, in the direction the system scroll setting gives. Pinch zooms around the cursor. A mouse wheel zooms around the cursor. Right-drag and middle-drag pan. Left-click and left-drag keep selecting, placing and panning.
- The arrow keys and W, A, S and D pan; `+`, `=` and `-` zoom.
- A Game menu lists Pause (Space), the three speeds (⌘1, ⌘2, ⌘3), Zoom In (⌘+) and Zoom Out (⌘−). Bare 1, 2 and 3 stay the build-category hotkeys.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `platform-shells`: new requirements "Esc steps back on the Mac", "Mac trackpad and mouse camera", "Mac keyboard camera" and "Mac Game menu".

## Impact

- **CityUI:** `GameSession.zoom(by:aroundScreenOffset:)`; `MacMapInput`, a pure mapping from scroll, drag and key input to camera actions; `CityRootView.stepBack`, the Esc order; a macOS-only event monitor that applies them over the map; `GameMenuCommand` and `GameCommands` for the menu. Sheets' close buttons take Esc.
- **CitybuilderMac:** adds `GameCommands` to the app's commands.
- **iOS and tvOS:** no change in behaviour.
