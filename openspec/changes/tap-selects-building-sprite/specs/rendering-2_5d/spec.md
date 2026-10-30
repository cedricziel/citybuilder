## MODIFIED Requirements

### Requirement: Input mapping
The renderer SHALL translate user input into intent values dispatched to a controller layer. Raw input MUST NOT be wired directly into `CityCore`. Supported inputs include tap/click, drag, pinch, two-finger pan, hover (Mac/iPad pointer), and Apple Pencil hover where available. With the Inspect tool armed, a tap SHALL go to the building whose status icon covers it. Failing that, it SHALL go to the frontmost standing building whose sprite covers it, where a sprite covers the building's footprint diamond swept up to the sprite's top. Otherwise it SHALL go to the tile under it. Roads lie flat and SHALL NOT take a tap this way. Under Demolish or a place tool, a tap SHALL go to the tile under it.

#### Scenario: Tap dispatched as intent
- **WHEN** the user taps a tile
- **THEN** an intent of `tapTile(coord)` is dispatched to the controller, which decides what to do (e.g. enqueue a place command)

#### Scenario: Tapping a building's sprite selects it
- **WHEN** the Inspect tool is armed and the player taps a house's roof where it stands over the road behind the house
- **THEN** the scene dispatches `tapTile` for the house's anchor tile, not the road's

#### Scenario: Other tools tap the tile behind a sprite
- **WHEN** Demolish or a place tool is armed and the player taps a house's roof over the road behind it
- **THEN** the scene dispatches `tapTile` for the road's tile

#### Scenario: The building in front takes an overlapping tap
- **WHEN** the Inspect tool is armed and the sprites of two buildings both cover the tap
- **THEN** the scene dispatches `tapTile` for the anchor of the building drawn in front
