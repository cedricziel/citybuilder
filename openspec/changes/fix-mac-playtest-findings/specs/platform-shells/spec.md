## MODIFIED Requirements

### Requirement: Inspector callout

Selecting a building SHALL show the inspector as a callout next to it: 14 points right of the building's edge when the build controls are in the rail, 12 points below it when they are in the dock. When that side has no room the callout MUST flip to the other side, and it MUST stay inside the area the status pill, menus, rail and dock leave free. The callout SHALL show the building's name with a house's tier beside it, a residents meter for a house, and its key lines: residents and needs for a house, otherwise state and road, followed by a "Problem:" line naming the building's issue when it has one, shown with a warning symbol. Details SHALL show every other inspector line and control, and stays open for the session once chosen. The callout SHALL offer Demolish for the player's buildings, which enqueues a demolish command for the selected tile and clears the selection.

#### Scenario: Callout title and key lines
- **WHEN** the player selects a peasant house with 2 of 4 residents
- **THEN** the inspector title is "House", its tier is "Peasants", its residents fill is one half, and its key lines start with "Residents: 2/4" followed by a "Needs:" line

#### Scenario: Callout key lines for other buildings
- **WHEN** the player selects a lumberjack hut
- **THEN** its key lines start with its "State:" and "Road:" lines

#### Scenario: Callout names what stops a building
- **WHEN** the player selects a farm with no road beside it
- **THEN** the inspector's problem is "No road: connect it to a road" and its last key line is "Problem: No road: connect it to a road"

#### Scenario: Problem text for every building issue
- **WHEN** the inspector describes each building issue
- **THEN** no route to storage reads "Its road doesn't reach a warehouse or the town center", no trees in reach reads "No forest within 2 tiles", missing wood and grain reads "Waiting for wood, grain" and storage full reads "Store full: no carrier can take its goods"

#### Scenario: Callout flips at the edge
- **WHEN** a 220 by 120 point callout is placed for a building 14 points from the right edge of an 844 by 390 point view in the rail layout
- **THEN** the callout sits left of the building

#### Scenario: Callout stays on screen
- **WHEN** a 220 by 120 point callout is placed for a building at the top of the free area in the rail layout
- **THEN** the callout's top edge sits on the free area's top edge

#### Scenario: Demolish from the callout
- **WHEN** the player selects their house and taps Demolish in the callout
- **THEN** a demolish command for the house's tile is enqueued and nothing is selected

## ADDED Requirements

### Requirement: Quit asks whether to save

On the Mac, the pause menu's Quit SHALL ask whether to save first, offering Save and Quit, Quit Without Saving and Cancel. Save and Quit SHALL save and then quit; if the save fails the game MUST stay open and show the error. Quit Without Saving SHALL quit without saving. Cancel SHALL leave the game paused.

#### Scenario: Quit asks before terminating
- **WHEN** the player chooses Quit in the pause menu
- **THEN** the save-or-discard prompt shows and nothing is saved or quit yet

#### Scenario: Save and quit saves then terminates
- **WHEN** the player chooses Save and Quit
- **THEN** the game saves and then quits

#### Scenario: Quit without saving skips the save
- **WHEN** the player chooses Quit Without Saving
- **THEN** the game quits without saving

#### Scenario: A failed save keeps the game open
- **WHEN** the player chooses Save and Quit and the save fails
- **THEN** the game does not quit and the pause menu reports "Couldn't save"
