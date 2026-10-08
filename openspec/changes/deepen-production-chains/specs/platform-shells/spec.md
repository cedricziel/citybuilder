## ADDED Requirements

### Requirement: Terrain rejection message

A placement rejected for missing required terrain SHALL show a message naming the terrain in player language.

#### Scenario: Mountain requirement message

- **WHEN** a placement is rejected with `needsTerrain(.mountain)`
- **THEN** the HUD message reads "Needs mountain ground"
