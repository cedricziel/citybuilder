## ADDED Requirements

### Requirement: Ambient beds follow season and shore

When the bindings' `ambient` section names a bed per season (`seasons`) and a `coast` bed, the ambience SHALL follow the game's context:

- **Season.** The current season's bed SHALL have a target gain of 1 minus half the sea share. The other seasons' beds SHALL target 0.
- **Shore.** The sea share is the fraction of tiles within 6 tiles of the listener that are water. The coastal bed SHALL target the sea share times 1.5, at most 1.
- **Glide.** Every gain SHALL move toward its target by at most 0.25 per second of wall-clock time, so a full crossfade takes 4 seconds. The audio layer SHALL drive the glide from its own 10 Hz timer, so the pace is the same at every game speed and while the game is paused.
- **Start and stop.** A bed SHALL start silent when its target first rises above 0, and stop once its gain has fallen back to 0.
- **No snapshot yet.** Until the first snapshot arrives, the ambience SHALL stay silent.
- **Session end.** When the game session ends, every bed SHALL stop and the scene SHALL forget the season, sea share, listener and snapshot. This overrides, for seasonal beds, the earlier rule that the ambient bed keeps playing at session end.
- **No listener.** With no listener, the sea share SHALL be 0.
- **Fallback.** An `ambient` section without `seasons` SHALL keep the single-track behaviour.

#### Scenario: Seasons crossfade
- **WHEN** the season turns from autumn to winter, inland
- **THEN** after 2 seconds the autumn and winter beds are both at 0.5, and after 4 seconds autumn has stopped and winter plays at 1

#### Scenario: Crossfades keep their pace at any game speed
- **WHEN** the season turns while the game runs at 1×, at 3×, or is paused
- **THEN** after 2 seconds of wall-clock time the new season's bed is at 0.5 in each case

#### Scenario: Session end stops the beds
- **WHEN** the summer and coastal beds play and the session ends
- **THEN** both stop, and no bed starts again until the next game's snapshot

#### Scenario: The shore brings in the surf
- **WHEN** the listener moves to a tile where half the surrounding tiles are water, in summer
- **THEN** the coastal bed targets 0.75 and the summer bed 0.75

#### Scenario: Ambience waits for the world
- **WHEN** time passes before any snapshot arrives
- **THEN** no bed starts
