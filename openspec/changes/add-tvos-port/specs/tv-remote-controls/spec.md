## Purpose

Defines how the Siri Remote and game controllers drive the city map, tile selection, building placement, road painting, demolition and HUD focus on Apple TV, where there is no touch point and no pointer.

## ADDED Requirements

### Requirement: One input owner per mode

On Apple TV, input SHALL have exactly one owner at a time. While the map has focus, the game SHALL read the remote and controllers directly, and remote input MUST NOT move system focus. While the HUD has focus, the system focus engine SHALL own the remote, and remote input MUST NOT pan the camera. Each press and swipe MUST produce at most one action.

#### Scenario: Swipe on the map never moves focus

- **WHEN** the map has focus and the player swipes down on the remote
- **THEN** the camera pans and focus stays on the map

#### Scenario: Swipe in the HUD never pans

- **WHEN** the HUD has focus and the player swipes left
- **THEN** the camera does not move

### Requirement: Reticle marks the target tile

On Apple TV the map SHALL show a reticle at the center of the screen. The reticle tile SHALL be the camera's center tile, and it MUST take the role that the touch point has on iOS and the hover pointer has on the Mac: selection, the tile menu, placement, road painting and demolition all act on the reticle tile. The camera center MUST stay within the map, so that every tile, corners included, can be the reticle tile and the reticle tile is never off the map. The reticle SHALL show four direction hints naming the tile that a click up, right, down or left would step to.

#### Scenario: Swipe past the corner keeps the reticle on the map

- **WHEN** the reticle tile is (0, 0) and the player swipes far towards the west corner
- **THEN** the reticle tile is still (0, 0)

#### Scenario: Reticle hints name the four steps

- **WHEN** the reticle tile is (10, 10)
- **THEN** the direction hints are up (10, 9), right (11, 10), down (10, 11) and left (9, 10)

### Requirement: Reticle tooltip

With the inspect tool active and the reticle resting on a building for 0.5 seconds, the HUD SHALL show the same tooltip the Mac shows for a hovered building, placed beside the reticle so it does not cover it. The tooltip MUST NOT show over a tile without a building, while a placement is pending, or while road painting is on.

#### Scenario: Reticle rest on a building shows the tooltip

- **WHEN** the inspect tool is active and the reticle rests on a house for 0.5 seconds
- **THEN** the tooltip for that house is shown

#### Scenario: No tooltip over empty ground

- **WHEN** the reticle rests on an empty grass tile for 0.5 seconds
- **THEN** no tooltip is shown

### Requirement: Remote pans the map

While the map has focus, a swipe SHALL pan the camera continuously, scaled by the current zoom so that a full-width swipe moves the view by the same screen distance at every zoom. A click on the edge of the touch surface or a press of the directional pad SHALL move the camera by exactly one tile along the matching iso axis: up north-east, right south-east, down south-west and left north-west. A swipe MUST NOT also count as a click.

#### Scenario: Directional click steps one tile

- **WHEN** the map has focus, the reticle tile is (10, 10) and the player clicks right
- **THEN** the reticle tile becomes (11, 10)

#### Scenario: Swipe pans by screen distance independent of zoom

- **WHEN** the same full-width swipe is applied at zoom 1.0 and at zoom 2.0
- **THEN** the camera moves half as many tiles at zoom 2.0 as at zoom 1.0

### Requirement: Zoom without pinch

On Apple TV the HUD SHALL offer zoom-in and zoom-out buttons that multiply the zoom by 1.5 and by 1/1.5, within the camera's zoom bounds of 0.25 and 4.0. Holding Play/Pause for at least 0.4 seconds while the map has focus SHALL step the zoom through 2.0, 1.0 and 0.5 in that order, wrapping, and from any other zoom SHALL go to 1.0. A connected controller's right and left triggers SHALL zoom in and out continuously within the same bounds.

#### Scenario: Zoom button multiplies by 1.5

- **WHEN** the zoom is 1.0 and the player activates zoom in
- **THEN** the zoom is 1.5

#### Scenario: Zoom button respects the maximum

- **WHEN** the zoom is 4.0 and the player activates zoom in
- **THEN** the zoom stays 4.0

#### Scenario: Holding Play/Pause cycles the zoom levels

- **WHEN** the map has focus, the zoom is 2.0 and the player holds Play/Pause for 0.5 seconds
- **THEN** the zoom is 1.0

### Requirement: Select and hold on the map

While the map has focus, a press of select released within 0.4 seconds SHALL act as a tap on the reticle tile. A press held for at least 0.4 seconds SHALL open the tile menu for the reticle tile, the same menu that a long-press opens on iOS, when the inspect tool is active, no placement is pending and the game is not in route mode. Otherwise, holding select SHALL do nothing. Select on the building that is already selected SHALL move focus into its inspector callout. In route mode, select SHALL add the reticle tile as a stop under the route-mode rules.

#### Scenario: Short select taps the reticle tile

- **WHEN** the inspect tool is active and select is pressed and released after 0.2 seconds with the reticle on a house
- **THEN** the selected tile is the reticle tile and no tile menu is open

#### Scenario: Holding select opens the tile menu

- **WHEN** the inspect tool is active and select is held for 0.5 seconds with the reticle on an empty grass tile
- **THEN** the tile menu is open for the reticle tile

#### Scenario: Holding select does nothing while a placement is pending

- **WHEN** a house placement is pending and select is held for 0.5 seconds
- **THEN** no tile menu opens and the placement is still pending

#### Scenario: Select on the selected building focuses its callout

- **WHEN** the house at the reticle tile is selected and the player presses select again
- **THEN** focus moves to the inspector callout

#### Scenario: Select adds a route stop in route mode

- **WHEN** route mode is on and the player presses select with the reticle on a water tile
- **THEN** the water tile is appended to the route's stops

### Requirement: Placement follows the reticle

On Apple TV, choosing a building from the build rail or the tile menu SHALL move focus to the map and start a pending placement of that building at the reticle tile. While a placement is pending, its anchor MUST follow the reticle as the camera moves, and the ghost and its validity tint MUST update with it. Select SHALL confirm. A valid confirm enqueues the place command and immediately starts a new pending placement of the same building at the reticle. An invalid confirm shows the rejection message and keeps the placement pending. Back SHALL cancel the pending placement and return to the inspect tool.

#### Scenario: Choosing a building starts placement at the reticle

- **WHEN** the reticle tile is (10, 10) and the player chooses the house in the build rail
- **THEN** focus is on the map and a house placement is pending at (10, 10)

#### Scenario: Pending anchor follows the reticle

- **WHEN** a house placement is pending at (10, 10) and the player clicks right
- **THEN** the pending anchor is (11, 10)

#### Scenario: Confirm places and starts the next placement

- **WHEN** a valid house placement is pending at (10, 10) and the player presses select
- **THEN** a place command for a house at (10, 10) is enqueued and a new house placement is pending at the reticle tile

#### Scenario: Back cancels placement and returns to inspect

- **WHEN** a house placement is pending and the player presses Back
- **THEN** no placement is pending, no command is enqueued and the inspect tool is active

### Requirement: Road painting

On Apple TV, with the road tool armed, select SHALL toggle painting on and off. Turning painting on SHALL place road on the reticle tile. While painting is on, each directional click SHALL step the reticle and place road on the tile it enters, and swipes SHALL pan without placing road. While painting is on, the reticle SHALL show a painting style that differs from its idle style.

#### Scenario: Painting a road with clicks

- **WHEN** the road tool is armed, the player presses select at (5, 5) and then clicks right twice
- **THEN** road place commands are enqueued for (5, 5), (6, 5) and (7, 5), once each

#### Scenario: Swipes do not paint

- **WHEN** painting is on and the player swipes across three tiles
- **THEN** no road place command is enqueued for those tiles

#### Scenario: Reticle shows painting

- **WHEN** painting is on
- **THEN** the reticle is in its painting style

### Requirement: Demolish acts on one building at a time

On Apple TV, with the demolish tool armed, select SHALL demolish the player building under the reticle, and only that building. Demolish SHALL NOT paint. While demolish is armed, the reticle SHALL show a demolish style that differs from its idle and painting styles.

#### Scenario: Demolish removes only the building under the reticle

- **WHEN** demolish is armed, the reticle is on a player house and the player presses select, then clicks right onto another house
- **THEN** exactly one demolish command is enqueued, for the first house

### Requirement: Back steps out one level at a time

On Apple TV, while the game is running, Back SHALL undo the innermost state, one level per press, in this order: close an open sheet or menu (including the tile menu), close an open drawer, return focus from the HUD to the map, cancel a pending placement, turn road painting off, put away an armed road or demolish tool, leave route mode after removing its last stop (one stop per press), clear the selection, and finally open the pause menu. Back on the pause menu SHALL close it and resume. Back on the title screen MUST NOT be handled by the game, so the system returns to the Home screen.

#### Scenario: Back on an idle map opens the pause menu

- **WHEN** focus is on the map, the inspect tool is active, nothing is selected and the player presses Back
- **THEN** the pause menu is open

#### Scenario: Back stops painting before putting the tool away

- **WHEN** road painting is on and the player presses Back once
- **THEN** painting is off and the road tool is still armed

#### Scenario: Back in route mode removes the last stop

- **WHEN** route mode is on with two stops and the player presses Back
- **THEN** route mode is still on with one stop

#### Scenario: Back on the pause menu resumes

- **WHEN** the pause menu is open and the player presses Back
- **THEN** the pause menu is closed and the simulation runs at the speed it had before

#### Scenario: Back on the title screen is left to the system

- **WHEN** the title screen is showing and the player presses Back
- **THEN** the game does not handle the press

### Requirement: Play/Pause moves focus between map and HUD

On Apple TV, a press of Play/Pause shorter than 0.4 seconds SHALL move focus from the map to the HUD's build rail, and from anywhere in the HUD back to the map. Inside the HUD, the build rail, the top bar, the inspector callout and the route overlay SHALL be linked so that focus can move between them with directional input. The simulation is paused and resumed through the pause menu and the speed control.

#### Scenario: Play/Pause enters the HUD

- **WHEN** focus is on the map and the player presses Play/Pause
- **THEN** focus is on the build rail

#### Scenario: Play/Pause returns to the map

- **WHEN** focus is on the Goals button and the player presses Play/Pause
- **THEN** focus is on the map

### Requirement: Game controller mapping

When an extended game controller is connected to Apple TV, its left thumbstick SHALL pan like a swipe, its directional pad SHALL act as directional clicks, A SHALL act as select (holding A acts as holding select), B SHALL act as Back, Y SHALL act as Play/Pause, the triggers SHALL zoom, and Menu SHALL open the pause menu. The Siri Remote MUST keep working while a controller is connected.

#### Scenario: Controller A selects the reticle tile

- **WHEN** a controller is connected, the map has focus, the inspect tool is active and the player presses and releases A
- **THEN** the selected tile is the reticle tile

#### Scenario: Controller Menu opens the pause menu

- **WHEN** a controller is connected, a house placement is pending and the player presses Menu
- **THEN** the pause menu is open
