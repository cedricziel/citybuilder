## ADDED Requirements

### Requirement: Minimap

On iPhone, iPad and Mac the HUD SHALL show a minimap of the whole map, drawn in the same iso orientation as the map, so that tile (x, y) sits at `x − y` across and `x + y` down. It SHALL show:

- each tile's terrain in its own colour: water, beach, grass, forest, and rock for mountain
- each player building's footprint in the player colour (`RivalColour.playerHex`), and each rival building's footprint in that rival's colour
- each ship as a dot
- the camera's visible area as an outlined rectangle

The terrain SHALL be drawn into an image once and redrawn only when the snapshot's terrain grid differs from the one last drawn. The building and ship markers SHALL be rebuilt at most once every 3 ticks. The camera rectangle SHALL follow the camera on every frame. Nothing drawn per frame SHALL allocate in proportion to the map's size.

#### Scenario: Terrain colours
- **WHEN** the terrain image is drawn for a map with a water, a beach, a grass, a forest and a mountain tile
- **THEN** the pixel at each tile's center has that terrain's minimap colour

#### Scenario: Iso orientation
- **WHEN** the minimap projects tiles (0, 0), (W − 1, 0), (0, H − 1) and (W − 1, H − 1) of a W by H map
- **THEN** (0, 0) is at the top, (W − 1, 0) at the right, (0, H − 1) at the left and (W − 1, H − 1) at the bottom

#### Scenario: Terrain redraws only when it changes
- **WHEN** the minimap applies two snapshots with the same terrain, then one in which a forest tile became grass
- **THEN** the terrain image is drawn twice in all, and the second image shows grass at that tile

#### Scenario: Buildings in their owner's colour
- **WHEN** the minimap applies a snapshot with a player house and a crimson rival's house
- **THEN** the player house's marker has the player colour and the rival house's marker is crimson

#### Scenario: Ships as dots
- **WHEN** the minimap applies a snapshot with a ship at (12.5, 7.25)
- **THEN** it has one ship dot at that position

#### Scenario: Markers refresh at most every 3 ticks
- **WHEN** a house is placed one tick after the minimap last rebuilt its markers
- **THEN** the house has no marker after that tick, and has one within 3 ticks

#### Scenario: Camera frame
- **WHEN** the camera is centered on (20, 20) at zoom 1.0 in a view 640 by 320 points
- **THEN** the camera rectangle spans `x − y` from −10 to 10 across and `x + y` from 30 to 50 down

### Requirement: Minimap moves the camera

A tap or click on the minimap SHALL center the camera on the map point under it. A drag SHALL keep the camera centered under the finger or pointer while it moves. A point outside the map SHALL move the camera to the nearest point on the map. A tap or click SHALL glide the camera there over 0.25 seconds, and when Reduce Motion is on it SHALL move the camera at once. A drag SHALL always move the camera at once. Touches on the minimap SHALL NOT reach the map's own gestures, so they neither pan the map nor select, place or demolish.

#### Scenario: Tap centers the camera
- **WHEN** Reduce Motion is on and the player taps the minimap point of tile (30, 12)
- **THEN** the camera is centered on (30, 12) at once, and its zoom is unchanged

#### Scenario: Tap glides without Reduce Motion
- **WHEN** Reduce Motion is off and the player taps the minimap point of tile (30, 12) with the camera at (10, 10)
- **THEN** the camera is between (10, 10) and (30, 12) after 0.1 seconds and centered on (30, 12) after 0.25 seconds

#### Scenario: Point off the map clamps
- **WHEN** the player taps the minimap left of the map's left corner
- **THEN** the camera moves to a point with x at 0 or more and y at most H − 1

### Requirement: Minimap toggle

The HUD SHALL offer a Minimap button among its menu buttons, and in the More menu when the menus fold. It SHALL show and hide the minimap. On the Mac, `M` SHALL do the same. The choice SHALL be stored in user defaults and SHALL hold across launches. When nothing is stored, the minimap SHALL be shown on iPad and Mac and hidden on iPhone, whose screen is tight.

#### Scenario: Minimap shown by default on iPad and Mac
- **WHEN** the minimap preference is read from empty user defaults on an iPad, a Mac and an iPhone
- **THEN** the minimap is shown on the iPad and the Mac and hidden on the iPhone

#### Scenario: Hiding the minimap persists
- **WHEN** the player hides the minimap and the preference is read again from the same user defaults
- **THEN** the minimap is hidden

#### Scenario: Mac minimap hotkey
- **WHEN** the HUD's hotkeys are queried
- **THEN** the minimap toggle is M

### Requirement: Minimap layout

The minimap SHALL keep the HUD's margin inside the safe area. When the build controls sit in the left rail, it SHALL sit in the bottom-right corner, and the tool strip and the placement rejection banner SHALL stay left of it. When the build controls sit in the bottom dock, it SHALL sit in the top-right corner below the menu buttons, and the stocks tray and the session banner SHALL stay left of it: the tray SHALL drop columns of goods until it fits. The inspector callout's free area SHALL leave out the minimap's band: in the rail layout, the area level with or below the minimap; in the dock layout, the area level with or above it. The map image SHALL be 144 by 72 points on a phone, 224 by 112 on an iPad and 240 by 120 on a Mac, and 144 by 72 in any view narrower than 600 points, such as Slide Over.

#### Scenario: Minimap corner per dock
- **WHEN** the minimap is placed for a landscape view and for a portrait view
- **THEN** it sits bottom-right in the landscape view and top-right in the portrait view

#### Scenario: Minimap size per idiom
- **WHEN** the minimap size is queried for a phone, an iPad and a Mac
- **THEN** it is 144 by 72, 224 by 112 and 240 by 120 points

#### Scenario: Stocks tray stays clear of the minimap
- **WHEN** the dock layout is made with the minimap shown at iPhone, iPad portrait and Slide Over widths, with 1, 4 and 18 goods in the tray
- **THEN** the tray's right edge never passes the minimap card's left edge

#### Scenario: Callout avoids the minimap
- **WHEN** the inspector callout's free area is computed in the rail layout with the minimap shown
- **THEN** its bottom edge is above the minimap's top edge

### Requirement: Apple TV map overview

Apple TV SHALL NOT show the corner minimap. Instead a full-screen overview SHALL show the same layers. It SHALL open from a Map button in the top bar, which SHALL move focus to the map, from a connected controller's X button while the map has focus (X SHALL close it again), and from the Play/Pause hold zoom cycle, whose stops become 2.0, 1.0, 0.5 and then the overview. Holding Play/Pause in the overview SHALL close it and set the zoom to 2.0. On opening, a cursor SHALL sit on the camera's center. In the overview, swipes and the stick SHALL move the cursor, a directional click SHALL step it 4 tiles along the same iso axis a click steps the reticle, and the cursor SHALL stay on the map. Select SHALL center the camera on the cursor's tile and close the overview; only a select pressed while the overview is open SHALL count, so the release of the press that opened it does nothing. The camera SHALL jump there without a glide. Back SHALL close the overview and leave the camera unchanged. While the overview is open, no input SHALL pan the map, select or place. When the overview closes, the map SHALL keep focus.

#### Scenario: Play/Pause hold cycle reaches the overview
- **WHEN** the map has focus, the zoom is 0.5 and the player holds Play/Pause for 0.5 seconds
- **THEN** the overview is open and the zoom is still 0.5
- **WHEN** the player holds Play/Pause for 0.5 seconds again
- **THEN** the overview is closed and the zoom is 2.0

#### Scenario: Controller X opens the overview
- **WHEN** the map has focus and the controller's X button is pressed
- **THEN** the overview is open with its cursor on the camera's center tile

#### Scenario: Select in the overview jumps the camera
- **WHEN** the overview is open with the camera at (10, 10), and the player clicks right twice and presses select
- **THEN** the camera is centered on (18, 10) and the overview is closed

#### Scenario: Back closes the overview
- **WHEN** the overview is open and the player presses Back
- **THEN** the overview is closed, the camera is unchanged and the game is not paused

#### Scenario: Map button hands the remote to the overview
- **WHEN** the HUD has focus, the player chooses Map and then presses Back
- **THEN** the overview opened with the map taking focus, Back closed it, and the map still has focus

#### Scenario: Overview cursor stays on the map
- **WHEN** the overview cursor is on tile (1, 1) and the player clicks left
- **THEN** the cursor is on a tile inside the map
