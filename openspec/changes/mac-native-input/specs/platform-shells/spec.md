## ADDED Requirements

### Requirement: Esc steps back on the Mac

On the Mac, Esc SHALL close the topmost open thing, one per press. In a sheet, Esc SHALL close the sheet; in the pause menu it SHALL resume the game. In the game window with no sheet open, Esc SHALL, in this order: close a full-screen panel over the map, such as an overview, cancel a pending placement and disarm its tool, close the open build drawer, disarm the armed tool, leave route mode, fold the inspector's details (which hold the town market), and clear the selection. With nothing open, Esc SHALL pause the game, which opens the pause menu. On the title screen, Esc SHALL close the open sheet.

#### Scenario: Esc closes the drawer before the tool
- **WHEN** the road tool is armed, the Town drawer is open, and the player presses Esc twice
- **THEN** the first press closes the drawer with the road tool still armed, and the second disarms it

#### Scenario: Esc leaves route mode
- **WHEN** the player is in route mode and presses Esc
- **THEN** route mode ends

#### Scenario: Esc folds the market before closing the inspector
- **WHEN** the inspector shows the town center with its details open and the player presses Esc twice
- **THEN** the first press folds the details and the second clears the selection

#### Scenario: Esc on an idle map pauses
- **WHEN** nothing is open or armed and the player presses Esc
- **THEN** the game is paused

### Requirement: Mac trackpad and mouse camera

On the Mac, over the map, a scroll with precise deltas (a trackpad, or a Magic Mouse's touch surface) SHALL pan the camera as a drag of the same distance would, including the scroll's momentum, in the direction the system scroll setting gives. A pinch SHALL zoom around the cursor, and a line-based mouse scroll wheel SHALL zoom around the cursor, in when the wheel turns away from the player. Zooming around the cursor SHALL keep the point under the cursor in place and SHALL stay within the camera's zoom limits. A right-drag or a middle-drag SHALL pan the camera like a left-drag. Left-click and left-drag SHALL select, place and pan as before. iOS and Apple TV SHALL keep their gestures.

#### Scenario: Trackpad scroll pans
- **WHEN** a trackpad scroll arrives with deltas (30, -12)
- **THEN** the camera pans as a drag of (30, -12) would

#### Scenario: Mouse wheel zooms in
- **WHEN** a mouse wheel turns one notch away from the player
- **THEN** the camera zooms in by a factor of 1.1

#### Scenario: Zoom keeps the point under the cursor
- **WHEN** the camera zooms by 2 around a cursor 200 points right of and 100 points above the view's center
- **THEN** the map point under the cursor is the same before and after

#### Scenario: Zoom stops at the limit
- **WHEN** the camera is at its maximum zoom and zooms in around the cursor
- **THEN** neither the zoom nor the camera center changes

#### Scenario: Right-drag pans
- **WHEN** the mouse moves (8, 5) with the right or middle button down
- **THEN** the camera pans as a drag of (8, 5) would

### Requirement: Mac keyboard camera

On the Mac game window, with no sheet open and no text field focused, the arrow keys and W, A, S and D SHALL pan the camera one tile width of the map per press at any zoom, toward the side the key names, repeating while held. `+` and `=` SHALL zoom in and `-` SHALL zoom out by the camera's zoom step.

#### Scenario: Left arrow pans left
- **WHEN** the player presses the left arrow or A at zoom 1
- **THEN** the camera pans as a drag of 64 points to the right would

#### Scenario: Plus zooms in
- **WHEN** the player presses `+` or `=`
- **THEN** the camera zooms in by the zoom step

### Requirement: Mac Game menu

The Mac menu bar SHALL have a Game menu while a game is open: Pause or Resume on Space, Speed 1×, 2× and 3× on ⌘1, ⌘2 and ⌘3, Zoom In on ⌘+ and Zoom Out on ⌘−. Choosing a speed SHALL resume a paused game. On the title screen the menu's items SHALL be disabled.

#### Scenario: Game menu shortcuts
- **WHEN** the Game menu is built
- **THEN** it lists Pause on Space, the speeds on ⌘1 to ⌘3, Zoom In on ⌘+ and Zoom Out on ⌘−

#### Scenario: Space toggles pause
- **WHEN** the game runs and the player chooses Pause, then chooses it again
- **THEN** the game is paused, then running again
