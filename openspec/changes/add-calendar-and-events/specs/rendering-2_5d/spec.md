## ADDED Requirements

### Requirement: Terrain shows the season

Grass and forest tiles SHALL take a warm tint in autumn and a frosty tint in winter, and no tint in spring and summer. Tiles that come into view later SHALL get the current tint.

#### Scenario: Winter tints grass

- **WHEN** the scene renders a snapshot dated winter
- **THEN** visible grass nodes have a non-zero color blend factor

#### Scenario: Summer has no tint

- **WHEN** the scene renders a snapshot dated summer
- **THEN** visible grass nodes have a zero color blend factor
