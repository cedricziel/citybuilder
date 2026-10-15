## ADDED Requirements

### Requirement: Title screen shows the island

When the app has registered a world renderer, the title screen SHALL draw the starting island (single island, seed 0, with finished houses around the town center) behind its menu. The island SHALL be built off the main thread; until it is ready, and when no renderer is registered, the title screen SHALL show a plain warm gradient. The camera SHALL drift around the town center, never more than 4 tiles from it, and the light SHALL move forward as a time-lapse: from morning to evening (time-of-day fraction 0.30 to 0.82) over 150 seconds, then through the night back to morning over 10 seconds. The clock MUST NOT run backwards, so residents never walk in reverse. With Reduce Motion on, the camera SHALL stay on the town center and the time of day SHALL stay at 0.45. The backdrop MUST NOT take touches, clicks or focus.

#### Scenario: Title camera drifts around the town center
- **WHEN** the title backdrop has run for 0, 20 and 300 seconds
- **THEN** the camera centers differ from each other, and each is within 4 tiles of the town center

#### Scenario: Title light moves from morning to evening
- **WHEN** the title backdrop has run for 0, 145 and 160 seconds
- **THEN** the time-of-day fraction is 0.30, above 0.8, and 0.30 again, and the tick count grew at every step

#### Scenario: Title night passes quickly
- **WHEN** the title backdrop runs through one 160-second light cycle
- **THEN** the time of day is night for at most 10 seconds of it

#### Scenario: Title backdrop stands still under Reduce Motion
- **WHEN** Reduce Motion is on and the title backdrop has run for 0 and 300 seconds
- **THEN** both cameras are centered on the town center and the time-of-day fraction is 0.45

#### Scenario: Title backdrop without a renderer
- **WHEN** no world renderer is registered
- **THEN** the renderer registry has no factory, and the title backdrop draws only the gradient

### Requirement: Title menu entrance

When the title screen appears, the title and each menu button SHALL fade in and rise 16 points into place, one after another, the item at position n (the title is 0) starting n × 0.08 seconds after the screen appears. On Apple TV the items SHALL only rise, staying opaque, so the default focus can land on Continue (or New Game without a save) while they enter. With Reduce Motion on, every item SHALL appear at once in place.

#### Scenario: Menu items enter in order
- **WHEN** the title screen appears with Reduce Motion off
- **THEN** item 0 starts at 0 seconds, item 3 at 0.24 seconds, and an item that has not entered sits 16 points below its place

#### Scenario: Menu items appear at once under Reduce Motion
- **WHEN** the title screen appears with Reduce Motion on
- **THEN** every item starts at 0 seconds with no offset and no animation

### Requirement: Title menu buttons respond to touch and pointer

On iPhone, iPad and Mac a title menu button SHALL scale to 0.96 while pressed and to 1.03 while the pointer hovers over it. With Reduce Motion on it SHALL keep its size and darken while pressed instead. On Apple TV the title menu SHALL keep the system bordered button styles, so focus lifts and tilts the button natively.

#### Scenario: Pressed and hovered button scale
- **WHEN** a title menu button is pressed, hovered, or neither, with Reduce Motion off
- **THEN** its scale is 0.96, 1.03 and 1

#### Scenario: Pressed button under Reduce Motion
- **WHEN** a title menu button is pressed with Reduce Motion on
- **THEN** its scale is 1 and its brightness is lowered
