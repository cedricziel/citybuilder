## MODIFIED Requirements

### Requirement: Residents stroll the streets

During day and dusk, each inhabited house with an adjacent road SHALL show up to three strollers (one per three residents) walking the nearby roads, and none at night. Stroller positions SHALL be a pure function of house, slot and tick.

A stroller's route SHALL be a walk along the roads: from the road tile nearest the house, the shortest road path to the farthest road tile it reaches within 3 tiles of the house, walked back and forth. Every leg SHALL join two orthogonally adjacent road tiles, so a stroller's feet never cross a plot or a building that is not a road.

#### Scenario: Strollers by day

- **WHEN** a house with 9 residents next to a road is planned at midday
- **THEN** there are 3 strollers for it

#### Scenario: No strollers at night

- **WHEN** the same house is planned at midnight
- **THEN** there are no strollers for it

#### Scenario: Every stroller leg joins two neighbouring road tiles

- **WHEN** strollers are planned over a day for a house with roads behind it, in front of it and between it and its neighbour
- **THEN** every leg runs between two road tiles that share an edge

#### Scenario: A stroller's feet never land on a building that is not a road

- **WHEN** a stroller is at any point of any leg
- **THEN** the tile under its feet is a road or open ground, never a house or another building

## ADDED Requirements

### Requirement: Figures stand on their feet and face their way

Every node that draws a walker or an animal sprite SHALL anchor at `SpriteAtlas.walkerAnchor`, the point under the feet. It SHALL show the facing that matches its direction of travel, snapped to the nearest screen diagonal. It MUST NOT mirror a sprite with a negative `xScale`, because the light is baked into the sprite.

#### Scenario: A carrier stands on its tile

- **WHEN** a carrier node is created
- **THEN** its anchor point is `SpriteAtlas.walkerAnchor` and its `xScale` is positive

#### Scenario: A stroller heading down-left faces south-west

- **WHEN** a stroller moves toward +y (screen down-left)
- **THEN** its node plays the `sw` frames with a positive `xScale`

### Requirement: Figures stand still while the game is paused

When no new simulation tick has arrived for 0.3 s, carriers and strollers SHALL show their standing frame (frame 0) and play no walk cycle. They SHALL walk again on the next tick. Asking a node for the walk cycle it already plays SHALL leave that cycle running, not restart it.

#### Scenario: A paused carrier stands on frame 0

- **WHEN** the game is paused while a carrier walks a road
- **THEN** after 0.3 s without a tick its node shows frame 0 of its facing and runs no walk action

#### Scenario: A repeated request does not restart the cycle

- **WHEN** a node that walks south-east is asked again for the south-east walk cycle
- **THEN** it keeps the walk action it has

### Requirement: Figures sort by where they stand

A carrier, stroller or animal SHALL be depth-sorted, every frame, by the iso depth of the point under its feet (fractional column plus row, a tile centre counting as `x + y + 1`, like a building's footprint centre), plus a lift of a hundredth of a depth step. A figure whose feet are behind a building's footprint centre SHALL be hidden by the building; level with it or in front, it SHALL draw over it. A terrain object (tree clump, rock) SHALL sort a fiftieth of a step behind a building at its depth, so a figure passing behind a clump stays behind it until its feet are all but level with the clump.

Flat ground buildings (roads and the plaza paving) SHALL NOT take part in this sort: they draw on a flat layer above the terrain and below every standing building and figure, so a figure walking a road never sinks into the tile it steps onto.

Strollers SHALL stand on a road tile's centre at each end of a leg and move in a straight line between those centres, which are neighbouring road tiles; carriers stand on their path's tile centres the same way.

One depth per footprint sorts correctly only while a footprint is at most one tile longer than it is wide. A footprint 3:1 or longer (|width − height| ≥ 2) can be drawn over by a figure beside its long end; no catalogued building is that long, and a test fails if one becomes so.

#### Scenario: A figure behind a house is hidden by it

- **WHEN** a carrier walks the road along the back edge of a 2×2 house, or steps from there out to the tile beside the house's corner
- **THEN** its node sorts below the house's node until its feet are level with the house's footprint centre

#### Scenario: A figure in front of a house draws over it

- **WHEN** a figure walks the road down the house's front-right side
- **THEN** its node sorts above the house's node

#### Scenario: A figure on a road never sinks into it

- **WHEN** a carrier steps from one road tile to the next, down-screen or up-screen
- **THEN** at every point of the step its node sorts above every road tile it crosses

#### Scenario: A figure passing behind a tree clump stays behind it

- **WHEN** a figure steps from (a, b − 1) to (a + 1, b − 1) behind a clump on (a, b)
- **THEN** its node sorts below the clump until at least 95 % of the step
