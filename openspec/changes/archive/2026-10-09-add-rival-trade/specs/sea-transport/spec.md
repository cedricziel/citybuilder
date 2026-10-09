## ADDED Requirements

### Requirement: Routes may stop at rival ports

A route waypoint SHALL accept a port of any owner, and manifest actions at a rival port SHALL execute as trades (spec `rival-trade`) instead of moving goods to or from the port's own stockpile. Manifest actions at a player port SHALL behave as before.

#### Scenario: Route to a rival port is valid

- **WHEN** the player creates a route between their own port and rival 1's port
- **THEN** the route is added in the active state

#### Scenario: Player port unchanged

- **WHEN** a player ship executes "unload up to 10 planks" at the player's own port
- **THEN** 10 planks move into that port's stockpile and the player's balance does not change
