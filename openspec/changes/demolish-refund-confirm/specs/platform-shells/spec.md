## ADDED Requirements

### Requirement: Demolish asks first

Demolishing one of the player's standing buildings other than a road SHALL ask for a confirmation before any command is enqueued: the demolish tool's tap or click, the tile menu's Demolish, the inspector callout's Demolish and the Apple TV remote's select all go through it. The confirmation SHALL be titled "Demolish <building>?" and say "You get <refund> back.", or "You get nothing back." when the refund is $0, with a destructive Demolish button and Cancel. Confirming SHALL enqueue the demolish command for the tile; cancelling SHALL enqueue nothing. A road, ruins and a burning building SHALL be demolished at once, without a confirmation. Dragging the demolish tool SHALL demolish only what needs no confirmation. While the confirmation is open on Apple TV, the remote SHALL belong to it, and SHALL return to the map when it closes.

#### Scenario: Demolishing a standing building asks first

- **WHEN** the player taps their sawmill with the demolish tool
- **THEN** no command is enqueued and the confirmation reads "Demolish Sawmill?" and "You get $60 back."

#### Scenario: Confirming demolishes, cancelling keeps the building

- **WHEN** the player confirms the sawmill's demolish confirmation, or cancels it
- **THEN** confirming enqueues a demolish command for the sawmill's tile, and cancelling enqueues nothing and closes the confirmation

#### Scenario: Roads, ruins and burning buildings go at once

- **WHEN** the player taps a road, ruins or a burning building with the demolish tool
- **THEN** a demolish command for the tile is enqueued without a confirmation

#### Scenario: Dragging the demolish tool skips standing buildings

- **WHEN** the player drags the demolish tool over a road and a sawmill
- **THEN** a demolish command is enqueued for the road only and no confirmation opens

#### Scenario: The remote moves to the demolish confirmation

- **WHEN** on Apple TV the player selects their sawmill with the demolish tool armed, and then the confirmation closes
- **THEN** the remote leaves the map while the confirmation is open and returns to the map once it closes

## MODIFIED Requirements

### Requirement: Inspector callout beside the building

Selecting a building SHALL show the inspector as a callout next to it: 14 points right of the building's edge when the build controls are in the rail, 12 points below it when they are in the dock. When that side has no room the callout MUST flip to the other side, and it MUST stay inside the area the status pill, menus, rail and dock leave free. The callout SHALL show the building's name with a house's tier beside it, a residents meter for a house, and its key lines: residents and needs for a house, then, below its top tier, "Next: <tier> need <goods>" naming the goods the next tier needs that its own tier does not, otherwise state and road, followed by a "Problem:" line naming the building's issue when it has one, shown with a warning symbol. Details SHALL show every other inspector line and control, and stays open for the session once chosen. The callout SHALL offer Demolish for the player's buildings, which demolishes the selected tile as in "Demolish asks first" and clears the selection once the demolish command is enqueued.

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
- **THEN** no route to storage reads "Its road doesn't reach a warehouse or the town center", no trees in reach reads "No forest within 2 tiles: build a forester beside it", no room to plant reads "No open grass within 2 tiles to plant", missing wood and grain reads "Waiting for wood, grain" and output stuck on bread reads "Output stuck: no room for bread"

#### Scenario: Callout flips at the edge
- **WHEN** a 220 by 120 point callout is placed for a building 14 points from the right edge of an 844 by 390 point view in the rail layout
- **THEN** the callout sits left of the building

#### Scenario: Callout stays on screen
- **WHEN** a 220 by 120 point callout is placed for a building at the top of the free area in the rail layout
- **THEN** the callout's top edge sits on the free area's top edge

#### Scenario: Demolish from the callout
- **WHEN** the player selects their house, taps Demolish in the callout and confirms
- **THEN** a demolish command for the house's tile is enqueued and nothing is selected

#### Scenario: Callout names the next tier's needs

- **WHEN** the player selects a citizens' house in a Northern European town, then a peasants' house, then a merchants' house
- **THEN** the first two have the key lines "Next: Merchants need bread, tools, beer" and "Next: Citizens need planks", and the merchants' house has no "Next:" line
