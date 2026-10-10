## MODIFIED Requirements

### Requirement: Input mapping

The renderer SHALL translate user input into intent values dispatched to a controller layer. Raw input MUST NOT be wired directly into `CityCore`. Supported inputs include tap/click, drag, pinch, two-finger pan, hover (Mac/iPad pointer), Apple Pencil hover where available, and on Apple TV the Siri Remote (swipe, directional click, select, press-and-hold, Back, Play/Pause) and extended game controllers. On Apple TV the scene MUST NOT treat touches from the remote's touch surface as screen locations: remote input reaches the controller layer only as the reticle-based intents defined in `tv-remote-controls`.

#### Scenario: Tap dispatched as intent

- **WHEN** the user taps a tile
- **THEN** an intent of `tapTile(coord)` is dispatched to the controller, which decides what to do (e.g. enqueue a place command)

#### Scenario: Remote select dispatched as a tap on the reticle tile

- **WHEN** the player clicks select on the Siri Remote with the reticle on tile (4, 7)
- **THEN** an intent of `tapTile((4, 7))` is dispatched to the controller
