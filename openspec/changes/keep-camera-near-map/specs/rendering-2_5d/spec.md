## ADDED Requirements

### Requirement: Camera stays near the map

After every pan, the camera centre SHALL stay within `GameSession.cameraMapMargin` (8) tiles of the map on every axis. On Apple TV it SHALL stay on the map itself. A view that lies wholly off the map SHALL cull to no tiles and draw no terrain or building sprites, without failing.

#### Scenario: Panning far off the map stops at the margin

- **WHEN** the player pans 100,000 points past any of the four edges of a 24 × 24 map
- **THEN** the camera centre stops 8 tiles past the map on the axis it left by, and no further

#### Scenario: A view off the map draws nothing

- **WHEN** the camera stands 500 tiles past any edge or corner of the map
- **THEN** culling returns no tile range and the scene places no sprite
