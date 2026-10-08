## ADDED Requirements

### Requirement: Terrain shows the season

Grass and forest tiles SHALL use their autumn sprites in autumn and their winter sprites in winter (`terrain-<kind>-autumn`, `terrain-<kind>-winter`, with matching animation frames), and their regular sprites in spring and summer. Tiles that come into view later SHALL use the current season's sprites. A missing seasonal sprite SHALL fall back to the regular one.

#### Scenario: Winter tints grass

- **WHEN** the scene renders a snapshot dated winter
- **THEN** visible grass nodes show the winter grass sprite

#### Scenario: Summer has no tint

- **WHEN** the scene renders a snapshot dated summer
- **THEN** visible grass nodes show the regular grass sprite
