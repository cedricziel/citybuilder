## ADDED Requirements

### Requirement: Pausing a route

The command system SHALL accept `SetRoutePaused(id:paused:)` at tick boundaries. Pausing an `.active` route SHALL make it `.paused`, and resuming a `.paused` route SHALL make it `.active`. A broken route or an unknown route ID SHALL be left unchanged. While its route is paused, a `.sailing` or `.docked` ship SHALL keep its position, waypoint index, manifest progress and dock wait. Idle and returning ships SHALL be unaffected.

#### Scenario: Paused route holds its ships

- **WHEN** a route with a sailing ship and a docked ship is paused and the world ticks 10 times
- **THEN** the route is paused, the sailing ship's position is unchanged and the docked ship's cargo and manifest index are unchanged

#### Scenario: Resumed route sails on

- **WHEN** a paused route with a sailing ship is resumed
- **THEN** the route is active and the ship moves on the next tick

#### Scenario: Broken route stays broken

- **WHEN** `SetRoutePaused(id:paused: false)` is applied to a broken route
- **THEN** the route is still broken
