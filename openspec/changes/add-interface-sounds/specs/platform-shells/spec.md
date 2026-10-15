## ADDED Requirements

### Requirement: Interface actions make a sound

CityUI SHALL send each interface sound to `UISounds.sink`, which the app shell sets at launch:
- `tap`: choosing Continue, New Game or Settings on the title screen, and inspecting a tile;
- `select`: choosing a build tool;
- `toggle`: the player pausing or resuming, with the pause button, a pause hotkey or the Apple TV Menu button. A pause the game makes itself (a sheet, going to the background, Back or Escape opening the pause menu, a load) SHALL make no sound;
- `open`: opening a build drawer;
- `close`: closing a build drawer;
- `reject`: a placement the rules reject, when its message shows. The simulation never sees such a placement, so its `placementRejected` event cannot carry this sound.

With no sink set, nothing SHALL happen.

#### Scenario: Title menu choices tap
- **WHEN** the player chooses New Game, then Settings, on the title screen
- **THEN** the sink receives `tap` twice

#### Scenario: Build drawer opens and closes with a sound
- **WHEN** the player opens the Gather drawer and then closes it
- **THEN** the sink receives `open`, then `close`

#### Scenario: Tools and pause make a sound
- **WHEN** the player picks the road tool, then pauses
- **THEN** the sink receives `select`, then `toggle`

#### Scenario: A rejected placement knocks
- **WHEN** the player taps a water tile with the house tool armed
- **THEN** the sink receives `reject`

#### Scenario: A pause the game makes is silent
- **WHEN** the game sets its paused state itself, without the player's pause action
- **THEN** the sink receives nothing
