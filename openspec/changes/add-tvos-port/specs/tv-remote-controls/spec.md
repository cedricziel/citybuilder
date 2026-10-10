## Purpose

Defines how the Siri Remote and game controllers drive the city map, tile selection, building placement, tool painting and HUD focus on Apple TV, where there is no touch point and no pointer.

## ADDED Requirements

### Requirement: Reticle marks the target tile

On Apple TV the map SHALL show a reticle at the center of the screen. The reticle tile SHALL be the camera's center tile (`Camera.centerTile()`), and it MUST take the role that the touch point has on iOS and the hover pointer has on the Mac: selection, the tile context menu, placement and painting all act on the reticle tile. After the reticle rests on a tile for the hover tooltip delay, the HUD SHALL show the same tooltip the Mac shows for a hovered tile.

#### Scenario: Reticle tile follows the camera center

- **WHEN** the camera center is at `centerX = 8.4`, `centerY = 6.2`
- **THEN** the reticle tile is `TileCoordinate(x: 8, y: 6)`

#### Scenario: Reticle rest shows the hover tooltip

- **WHEN** the reticle rests on a building for the hover tooltip delay
- **THEN** the session's hovered tile is the reticle tile and the tooltip shows that building

### Requirement: Remote pans the map

While the map has focus, a swipe on the Siri Remote touch surface SHALL pan the camera continuously, proportionally to the swipe, scaled by the current zoom so that one full-width swipe moves the view by the same screen distance at every zoom. A directional click (up, down, left, right) SHALL move the camera by exactly one tile along the matching iso axis: up moves north-east, right south-east, down south-west and left north-west. Camera pans MUST respect the existing map bounds.

#### Scenario: Directional click steps one tile

- **WHEN** the map has focus, the reticle tile is (10, 10) and the player clicks right on the remote
- **THEN** the reticle tile becomes (11, 10)

#### Scenario: Swipe pans by screen distance independent of zoom

- **WHEN** the same full-width swipe is applied at zoom 1.0 and at zoom 2.0
- **THEN** the camera moves half as many tiles at zoom 2.0 as at zoom 1.0

#### Scenario: Stepping off the map is clamped

- **WHEN** the reticle tile is on the map's east edge and the player clicks right
- **THEN** the reticle tile does not change

### Requirement: Zoom without pinch

On Apple TV the HUD SHALL offer zoom-in and zoom-out buttons that change the camera zoom by one step each, within the existing minimum and maximum zoom. A connected game controller's right and left triggers SHALL zoom in and out continuously within the same bounds.

#### Scenario: Zoom button respects the maximum

- **WHEN** the camera is at maximum zoom and the player activates zoom in
- **THEN** the zoom stays at the maximum

### Requirement: Select and press-and-hold on the map

While the map has focus and no placement is pending, a click of the remote's select button SHALL behave as a tap on the reticle tile on iOS. Pressing and holding select for at least 0.4 seconds SHALL open the tile context menu for the reticle tile, the same menu that a long-press opens on iOS. In route mode, select SHALL add the reticle tile as a stop under the route-mode rules.

#### Scenario: Select taps the reticle tile

- **WHEN** the map has focus, the inspect tool is active and the player clicks select with the reticle on a house
- **THEN** the session's selected tile is the reticle tile

#### Scenario: Press-and-hold opens the tile menu

- **WHEN** the player holds select for 0.4 seconds with the reticle on an empty grass tile
- **THEN** the tile context menu opens for the reticle tile

#### Scenario: Select adds a route stop in route mode

- **WHEN** route mode is on and the player clicks select with the reticle on a water tile
- **THEN** the water tile is appended to the route's stops

### Requirement: Placement follows the reticle

On Apple TV, a building chosen from the build rail or the tile context menu SHALL enter pending placement with its anchor on the reticle tile. While a placement is pending, the anchor MUST follow the reticle as the camera moves, the ghost and its validity tint MUST update with it, select SHALL confirm the placement and Back SHALL cancel it. Confirming an invalid placement SHALL show the rejection message and keep the placement pending.

#### Scenario: Pending anchor follows the reticle

- **WHEN** a house placement is pending at (10, 10) and the player clicks right
- **THEN** the pending anchor is (11, 10)

#### Scenario: Select confirms a pending placement

- **WHEN** a valid house placement is pending and the player clicks select
- **THEN** a place command for the house at the pending anchor is enqueued and no placement is pending

#### Scenario: Back cancels a pending placement

- **WHEN** a house placement is pending and the player presses Back
- **THEN** no placement is pending and no command is enqueued

### Requirement: Toggle painting for roads and demolish

On Apple TV, with the road or demolish tool armed, select SHALL toggle painting on and off. When painting turns on, the tool SHALL apply to the reticle tile; while it stays on, the tool SHALL apply to every tile the reticle enters, once per tile. Back SHALL turn painting off, and a second Back SHALL return to the inspect tool. The tool strip hint SHALL read "Click to start painting <tool>" while painting is off and "Click to stop painting" while it is on.

#### Scenario: Painting a road along the reticle path

- **WHEN** the road tool is armed, the player clicks select at (5, 5) and then clicks right twice
- **THEN** road place commands are enqueued for (5, 5), (6, 5) and (7, 5), once each

#### Scenario: Back stops painting before leaving the tool

- **WHEN** painting is on with the road tool and the player presses Back once
- **THEN** painting is off and the road tool is still armed

### Requirement: Focus moves between map and HUD

On Apple TV the map and the HUD SHALL be separate focus sections. The game SHALL start with focus on the map. A downward swipe or click past the bottom of the map focus SHALL move focus into the build controls; Back from anywhere in the HUD SHALL return focus to the map. Back on the map with no tool armed, no placement pending and no painting SHALL open the pause menu. Play/Pause SHALL toggle the simulation between paused and running from any focus.

#### Scenario: Back from the HUD returns to the map

- **WHEN** focus is on a build rail entry and the player presses Back
- **THEN** focus is on the map

#### Scenario: Back on an idle map opens the pause menu

- **WHEN** focus is on the map, the inspect tool is active and no placement is pending
- **THEN** pressing Back opens the pause menu

#### Scenario: Play/Pause toggles the simulation

- **WHEN** the simulation is running and the player presses Play/Pause
- **THEN** the simulation is paused

### Requirement: Game controller mapping

When an extended game controller is connected to Apple TV, its left thumbstick SHALL pan the camera continuously, its D-pad SHALL act as directional clicks, A SHALL act as select (holding A acts as press-and-hold), B SHALL act as Back, the triggers SHALL zoom, and Menu SHALL open the pause menu. The Siri Remote MUST keep working while a controller is connected.

#### Scenario: Controller A selects the reticle tile

- **WHEN** a controller is connected, the map has focus and the player presses A
- **THEN** the input is handled exactly as a select click on the remote
