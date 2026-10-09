## MODIFIED Requirements

### Requirement: Adaptive HUD per idiom
The HUD SHALL adapt its layout to the shape of the screen on iPhone, iPad and Mac. When the view is wider than tall, the build controls MUST sit in a rail on the left edge; otherwise they MUST sit in a dock along the bottom edge. A status pill SHALL sit at the top center and the menu buttons (Goals, Research, Standings, Routes, Settings) at the top right; on a phone in portrait the menu buttons MUST fold into a single More menu. The HUD SHALL keep an 8 point margin inside the safe area on a phone and 16 points elsewhere. On a phone the rail SHALL hide its labels, the speed control SHALL be a single button and the status pill SHALL leave out the date. Layouts MUST share underlying SwiftUI views from `CityUI` and differ only in placement and chrome.

#### Scenario: iPad sidebar HUD
- **WHEN** the HUD lays out in a landscape view 1180 points wide and 820 points tall
- **THEN** the build controls are placed in the left rail with all three categories visible

#### Scenario: iPhone compact HUD
- **WHEN** the HUD lays out in a portrait view 390 points wide and 844 points tall
- **THEN** the build controls are placed in the bottom dock with the categories' drawers closed

#### Scenario: Phone portrait folds the menus
- **WHEN** the HUD layout is made for a phone in a portrait view and for a phone in a landscape view
- **THEN** the portrait layout folds the menu buttons into a More menu and the landscape layout does not

#### Scenario: Mac HUD with menu bar
- **WHEN** the app runs on Mac
- **THEN** primary actions are exposed both in the on-screen HUD and in the macOS menu bar

## ADDED Requirements

### Requirement: Status pill and stocks tray

The status pill SHALL show the date, money, population, the current island's name and the speed control. Tapping the island name SHALL open the island's stocks tray under the pill, and tapping it again SHALL close it. The tray MUST be closed when a session starts, and MUST stay empty on a rival's island.

#### Scenario: Island name toggles the stocks tray
- **WHEN** the camera is on an island holding 12 wood and the player taps the island name
- **THEN** the stocks tray lists wood 12
- **WHEN** the player taps the island name again
- **THEN** the stocks tray is empty

### Requirement: Game speed

The speed control SHALL offer 1×, 2× and 3× game speed next to the pause button. At speed n each firing of the session's 10 Hz timer MUST advance the world by n ticks. On the compact idiom a single button SHALL step through 1×, 2× and 3× and back to 1×. Choosing a speed, or stepping it, SHALL also resume a paused game. Speed is session state and MUST NOT be saved.

#### Scenario: Double speed runs two ticks per timer firing
- **WHEN** the speed is 2× and the session's timer fires once
- **THEN** the world's tick count rises by 2

#### Scenario: Compact speed button cycles
- **WHEN** the compact speed button is tapped three times starting from 1×
- **THEN** the speed reads 2×, then 3×, then 1×

#### Scenario: Choosing a speed resumes
- **WHEN** the game is paused and the player chooses 3×
- **THEN** the speed is 3× and the game is no longer paused

### Requirement: Build categories, rail and drawers

The build controls SHALL offer three categories, Town, Gather and Craft, followed by Road and Demolish. Every player-buildable kind except the road MUST belong to exactly one category. Tapping a category SHALL open its drawer, which lists the category's visible kinds with their sprite, name, cost and lock state; tapping the open category again SHALL close it. Picking a kind in the drawer SHALL arm that tool and close the drawer. A locked kind MUST be shown dimmed with a lock and MUST NOT arm. Arming any build or demolish tool SHALL clear the selection. Opening a sheet SHALL close the drawer. With no drawer open, the category of the armed kind SHALL be highlighted. On the Mac the keys 1, 2 and 3 SHALL open the Town, Gather and Craft drawers, R SHALL arm the road and X SHALL arm demolish.

#### Scenario: Kinds sort into categories
- **WHEN** the category of the house, the lumberjack hut, the sawmill and the road is queried
- **THEN** they are Town, Gather, Craft and none

#### Scenario: Every buildable kind has one category
- **WHEN** the categories of every palette kind other than the road are queried
- **THEN** each kind has a category, and the three drawers together list each kind once

#### Scenario: Picking a drawer tile arms and closes
- **WHEN** the player opens the Craft drawer and picks the sawmill
- **THEN** the sawmill tool is armed, no drawer is open, and Craft is highlighted

#### Scenario: Locked drawer tile does nothing
- **WHEN** the player opens the Gather drawer and picks the mine before Mining is researched
- **THEN** no tool is armed and the Gather drawer stays open

#### Scenario: Arming clears the selection
- **WHEN** a building is selected and the player arms the road
- **THEN** nothing is selected

#### Scenario: Rail hotkeys
- **WHEN** the rail's hotkeys are queried
- **THEN** Town is 1, Gather is 2, Craft is 3, Road is R and Demolish is X

### Requirement: Tool strip

While a build or demolish tool is armed, the HUD SHALL show a tool strip with the tool's name, its cost, a one-line hint naming the building, the material chips for the island under the camera when no tile is hovered, and a cancel button that returns to inspect. The placement rejection banner SHALL sit directly above the tool strip. The hint SHALL read "Tap or drag to place <building>" on touch devices and "Click or drag to place <building>" on the Mac, with the building's name in lower case, and for demolish "Tap a building to demolish" or "Click a building to demolish".

#### Scenario: Tool strip chips without hover
- **WHEN** the sawmill tool is armed, no tile is hovered, and the camera is on the starting island
- **THEN** the armed cost breakdown lists 4 wood with 6 on hand and 1 plank with 5 on hand

#### Scenario: Tool strip hint
- **WHEN** the tool strip hint is built for the house on a touch device and for demolish on the Mac
- **THEN** it reads "Tap or drag to place house" and "Click a building to demolish"

### Requirement: Inspector callout

Selecting a building SHALL show the inspector as a callout next to it: 14 points right of the building's edge when the build controls are in the rail, 12 points below it when they are in the dock. When that side has no room the callout MUST flip to the other side, and it MUST stay inside the area the status pill, menus, rail and dock leave free. The callout SHALL show the building's name with a house's tier beside it, a residents meter for a house, and its key lines: residents and needs for a house, otherwise state and road. Details SHALL show every other inspector line and control, and stays open for the session once chosen. The callout SHALL offer Demolish for the player's buildings, which enqueues a demolish command for the selected tile and clears the selection.

#### Scenario: Callout title and key lines
- **WHEN** the player selects a house with 2 of 6 residents
- **THEN** the inspector title is "House", its tier is "Peasants", its residents fill is one third, and its key lines start with "Residents: 2/6" followed by a "Needs:" line

#### Scenario: Callout key lines for other buildings
- **WHEN** the player selects a lumberjack hut
- **THEN** its key lines are its "State:" and "Road:" lines

#### Scenario: Callout flips at the edge
- **WHEN** a 220 by 120 point callout is placed for a building 14 points from the right edge of an 844 by 390 point view in the rail layout
- **THEN** the callout sits left of the building

#### Scenario: Callout stays on screen
- **WHEN** a 220 by 120 point callout is placed for a building at the top of the free area in the rail layout
- **THEN** the callout's top edge sits on the free area's top edge

#### Scenario: Demolish from the callout
- **WHEN** the player selects their house and taps Demolish in the callout
- **THEN** a demolish command for the house's tile is enqueued and nothing is selected
