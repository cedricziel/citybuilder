## ADDED Requirements

### Requirement: HUD pause button

The HUD top-right cluster SHALL include a pause / play button adjacent to the existing settings gear. The button's SF Symbol MUST be `pause.fill` when `session.isPaused == false` and `play.fill` when `session.isPaused == true`. Tapping the button MUST toggle `session.isPaused`. The button MUST stay visible in both states so it doubles as a state indicator.

#### Scenario: HUD shows the pause glyph when running

- **WHEN** the game is running (`session.isPaused == false`) and the HUD renders
- **THEN** the pause button's icon is `pause.fill`

#### Scenario: HUD shows the play glyph when paused

- **WHEN** the game is paused (`session.isPaused == true`) and the HUD renders
- **THEN** the pause button's icon is `play.fill`

#### Scenario: Tapping the HUD pause button toggles isPaused

- **WHEN** the player taps the pause button while running
- **THEN** `session.isPaused` becomes `true`

- **WHEN** the player taps the pause button while paused
- **THEN** `session.isPaused` becomes `false`
