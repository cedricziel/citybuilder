## ADDED Requirements

### Requirement: Route overlay from the session

The session SHALL give the scene a route overlay: in route mode, the in-progress waypoints with their land-crossing segment indices and the tile of a rejected land tap (reported once); otherwise the waypoints of the route selected in the route list with no red segments; otherwise none. The scene SHALL draw one leg per pair of consecutive waypoints in the routes layer, red for a land-crossing segment, and SHALL flash a red marker on a rejected tile.

#### Scenario: Session overlay follows route mode and selection

- **WHEN** route mode is on with stops at a port and a water tile
- **THEN** the session's route overlay holds those two waypoints
- **WHEN** route mode is off and the route list has route `R` selected
- **THEN** the overlay holds `R`'s waypoints and no red segments
- **WHEN** route mode is off and no route is selected
- **THEN** there is no overlay

#### Scenario: Red leg in the scene

- **WHEN** the scene draws an overlay of three waypoints whose second segment crosses land
- **THEN** the routes layer holds two legs and only the second is red

#### Scenario: Rejected land tap flashes

- **WHEN** the overlay reports a rejected tap at tile `(4, 5)`
- **THEN** the scene adds a flash marker at that tile's screen position, and the next frame's overlay reports no tap
