## ADDED Requirements

### Requirement: Building animations follow pause and Reduce Motion

The renderer SHALL keep one state for every building animation on screen: running, held or stopped.
- With Reduce Motion on, the state SHALL be stopped, and each animated building SHALL show the frame it was drawn with, its operational frame 0.
- Otherwise, while the game is paused (no new tick for 0.3 s), the state SHALL be held: each building animation SHALL keep its current frame.
- Otherwise the state SHALL be running.

A building drawn while the state is held or stopped SHALL start in that state. A change of state SHALL slow only each building's own animation; badges, glows and pennants on the building SHALL keep their motion. The renderer SHALL touch building nodes only on frames where the state changes.

#### Scenario: Reduce Motion rests a building on its first frame

- **WHEN** Reduce Motion turns on while a windmill's sails are mid-turn
- **THEN** its animation stops and the windmill shows its operational frame 0
- **AND** the sails turn again once Reduce Motion is off and the game ticks

#### Scenario: Pausing holds a building's animation

- **WHEN** no tick arrives for more than 0.3 s
- **THEN** each building animation stops on its current frame
- **AND** it runs again with the next tick
