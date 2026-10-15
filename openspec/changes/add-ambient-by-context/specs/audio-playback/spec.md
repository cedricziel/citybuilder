## ADDED Requirements

### Requirement: Ambient beds follow season and shore

When the bindings' `ambient` section names a bed per season (`seasons`) and a `coast` bed, the ambience SHALL follow the game's context:

- **Season.** The current season's bed SHALL have a target gain of 1 minus half the sea share. The other seasons' beds SHALL target 0.
- **Shore.** The sea share is the fraction of tiles within 6 tiles of the listener that are water. The coastal bed SHALL target the sea share times 1.5, at most 1.
- **Glide.** Each tick, every gain SHALL move toward its target by at most 0.025, so a full crossfade takes 40 ticks.
- **Start and stop.** A bed SHALL start silent when its target first rises above 0, and stop once its gain has fallen back to 0.
- **No snapshot yet.** Until the first snapshot arrives, the ambience SHALL stay silent.
- **Fallback.** An `ambient` section without `seasons` SHALL keep the single-track behaviour.

#### Scenario: Seasons crossfade
- **WHEN** the season turns from autumn to winter, inland
- **THEN** after 20 ticks the autumn and winter beds are both at 0.5, and after 40 ticks autumn has stopped and winter plays at 1

#### Scenario: The shore brings in the surf
- **WHEN** the listener moves to a tile where half the surrounding tiles are water, in summer
- **THEN** the coastal bed targets 0.75 and the summer bed 0.75

#### Scenario: Ambience waits for the world
- **WHEN** ticks pass before any snapshot arrives
- **THEN** no bed starts
