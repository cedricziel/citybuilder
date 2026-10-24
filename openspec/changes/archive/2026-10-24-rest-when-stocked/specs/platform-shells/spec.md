## MODIFIED Requirements

### Requirement: Inspector callout

Selecting a building SHALL show the inspector as a callout next to it: 14 points right of the building's edge when the build controls are in the rail, 12 points below it when they are in the dock. When that side has no room the callout MUST flip to the other side, and it MUST stay inside the area the status pill, menus, rail and dock leave free. The callout SHALL show the building's name with a house's tier beside it, a residents meter for a house, and its key lines: residents and needs for a house, then, below its top tier, "Next: <tier> need <goods>" naming the goods the next tier needs that its own tier does not, otherwise state and road, followed by a "Problem:" line naming the building's issue when it has one, shown with a warning symbol. A producer resting while the stores hold plenty SHALL instead show a calm line, "Resting: stores hold plenty of <good>", with no warning symbol and no "Problem:" prefix. Details SHALL show every other inspector line and control, and stays open for the session once chosen. The callout SHALL offer Demolish for the player's buildings, which enqueues a demolish command for the selected tile and clears the selection.

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
- **THEN** no route to storage reads "Its road doesn't reach a warehouse or the town center", no trees in reach reads "No forest within 2 tiles: build a forester beside it", no room to plant reads "No open grass within 2 tiles to plant", missing wood and grain reads "Waiting for wood, grain" and storage full reads "Store full: no carrier can take its goods"

#### Scenario: Callout flips at the edge
- **WHEN** a 220 by 120 point callout is placed for a building 14 points from the right edge of an 844 by 390 point view in the rail layout
- **THEN** the callout sits left of the building

#### Scenario: Callout stays on screen
- **WHEN** a 220 by 120 point callout is placed for a building at the top of the free area in the rail layout
- **THEN** the callout's top edge sits on the free area's top edge

#### Scenario: Demolish from the callout
- **WHEN** the player selects their house and taps Demolish in the callout
- **THEN** a demolish command for the house's tile is enqueued and nothing is selected

#### Scenario: Callout names the next tier's needs

- **WHEN** the player selects a citizens' house in a Northern European town, then a peasants' house, then a merchants' house
- **THEN** the first two have the key lines "Next: Merchants need bread, tools, beer" and "Next: Citizens need planks", and the merchants' house has no "Next:" line

#### Scenario: A resting producer reads calm
- **WHEN** the player selects a sawmill resting while the stores hold 40 planks
- **THEN** its last key line is "Resting: stores hold plenty of planks", it has no problem, and no warning symbol shows
