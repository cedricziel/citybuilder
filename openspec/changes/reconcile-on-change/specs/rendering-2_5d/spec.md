## ADDED Requirements

### Requirement: Sprites reconcile only on change

The renderer SHALL keep what its terrain and building sprites were drawn from: the tiles on screen, the terrain grid and occupancy, and the buildings with their road access, house populations, house modifiers and rivals. A frame where none of these changed SHALL add, remove and rebuild no sprite and SHALL NOT build the desired sprite set again. When only the camera moves, the renderer SHALL add and remove only the tiles that entered or left the view. When occupancy changes, it SHALL redraw only the tiles whose terrain object changed. After any sequence of frames, the sprites in the scene SHALL be the ones a full rebuild of the latest frame would place.

#### Scenario: An unchanged frame reconciles nothing

- **WHEN** the scene draws five more frames of the same snapshot
- **THEN** it runs no terrain pass and no building pass, and adds and removes no tile

#### Scenario: A pan redraws only the edges

- **WHEN** the camera moves one tile at zoom 0.5
- **THEN** the tiles added and removed are fewer than a fifth of the tiles on screen, and the sprites match a full rebuild

#### Scenario: A new building redraws only the tiles round it

- **WHEN** a house is placed beside a forest
- **THEN** one building pass runs, fewer than 20 tiles are redrawn, and the sprites match a full rebuild

#### Scenario: Incremental frames match a full rebuild

- **WHEN** the camera pans and zooms, a forest tile turns to grass and a house moves, one frame after another
- **THEN** after each frame the scene's sprites are the ones a fresh scene would place for that frame
