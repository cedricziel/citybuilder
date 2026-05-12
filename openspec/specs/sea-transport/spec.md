# sea-transport Specification

## Purpose
TBD - created by archiving change add-archipelago-and-sea. Update Purpose after archive.

## Requirements
### Requirement: Ship entity
The simulation SHALL represent each ship as an `EntityID` with associated components: `Fixed2D` position, `Fixed` heading (in radians), an optional `RouteID`, a current `waypointIdx` integer, a cargo dictionary `[Good: Int]`, and a `ShipState` enum value. The position MUST live in fixed-point coordinates anchored to the same grid as terrain tiles (1.0 unit = 1 tile).

#### Scenario: Ship has a single canonical position type
- **WHEN** any subsystem queries a ship's position
- **THEN** the position returned is `Fixed2D`, never a tile `(Int, Int)` and never a `Double`

#### Scenario: Ship cargo is bounded by capacity
- **WHEN** the sum of all goods in a ship's cargo is queried
- **THEN** the sum is less than or equal to that ship class's declared capacity

### Requirement: Route entity
The simulation SHALL represent each route as an `EntityID` with associated components: an ordered non-empty list of `Waypoint` values, a `manifest` mapping `PortID` to an ordered list of `ManifestAction` values, a `Fixed` speed, and a `RouteState` enum. Routes MUST be `Codable` and persist independently of any ship.

#### Scenario: Route persists after assigned ship is destroyed
- **WHEN** a ship is removed from the world while assigned to a route
- **THEN** the route remains present in the world with all waypoints and manifest intact, and any other ships assigned to it continue running it

#### Scenario: Route requires at least two port waypoints
- **WHEN** the player attempts to commit a route containing fewer than two `.port` waypoints
- **THEN** the commit is rejected with reason code `route_needs_two_ports`

### Requirement: Waypoint kinds
A `Waypoint` SHALL be exactly one of two cases: `.sea(position: Fixed2D)` for an open-water steering point, or `.port(id: PortID)` for a stop where the ship docks and executes manifest actions.

#### Scenario: Sea waypoint position lies on water tile
- **WHEN** a `.sea(position:)` waypoint is committed
- **THEN** the terrain type at the integer-floor of its position is `.water`

#### Scenario: Port waypoint references an existing port
- **WHEN** a `.port(id:)` waypoint is committed
- **THEN** there exists a port building in the world with that `PortID`

### Requirement: Route validation
The simulation SHALL expose a `validate(route:) -> ValidationResult` query that checks every rule needed for the route to be `.active`. The query MUST be pure (no side effects on the world) and deterministic.

#### Scenario: Route with land-crossing segment is invalid
- **WHEN** `validate(route:)` is called on a route whose line segment between two consecutive waypoints crosses one or more non-water tiles
- **THEN** the result is `.invalid(reason: .segmentCrossesLand(segmentIndex:))`

#### Scenario: Route referencing a non-existent port is invalid
- **WHEN** `validate(route:)` is called on a route whose `.port` waypoint references a `PortID` not present in the world
- **THEN** the result is `.invalid(reason: .unknownPort(portID:))`

#### Scenario: Valid route validates as active
- **WHEN** `validate(route:)` is called on a route satisfying all rules (≥2 port waypoints, every sea waypoint on water, every segment clear of land, all port references resolvable)
- **THEN** the result is `.valid`

#### Scenario: Segment sampling resolution is sub-tile
- **WHEN** `validate(route:)` evaluates a segment that crosses a land tile only along its corner
- **THEN** the validator detects the crossing (segment sampling step MUST be ≤ 0.25 tile)

### Requirement: Manifest actions
A `ManifestAction` SHALL be exactly one of two cases: `.loadUpTo(good: Good, qty: Int)` or `.unloadUpTo(good: Good, qty: Int)`. Ships executing a manifest at a port MUST apply actions in declared order, each action MUST be capped by the ship's free capacity (for loads) or current cargo of that good (for unloads), and each action MUST further be capped by what the port's goods buffer can provide or accept.

#### Scenario: Load action up to ship capacity
- **WHEN** a ship with 20 units of free capacity executes `.loadUpTo(wood, 50)` at a port holding 100 wood
- **THEN** the ship's wood cargo increases by 20 and the port's wood stock decreases by 20

#### Scenario: Load action up to port stock
- **WHEN** a ship with 60 units of free capacity executes `.loadUpTo(wood, 50)` at a port holding 30 wood
- **THEN** the ship's wood cargo increases by 30 and the port's wood stock decreases by 30

#### Scenario: Unload action up to port free capacity
- **WHEN** a ship carrying 40 wood executes `.unloadUpTo(wood, 50)` at a port with 25 units of free buffer capacity
- **THEN** the ship's wood cargo decreases by 25 and the port's wood stock increases by 25

#### Scenario: Manifest actions execute in declared order
- **WHEN** a ship docks at a port whose manifest is `[.unloadUpTo(wood, 100), .loadUpTo(food, 100)]` and the port has 0 free capacity until the unload completes
- **THEN** the unload runs first, freeing capacity, and the load proceeds against the freed capacity in the same docking turn

### Requirement: Ship state machine
A ship SHALL be in exactly one of four states: `.idle`, `.sailing`, `.docked`, `.returning`. Allowed transitions:
- `.idle → .sailing` when assigned a valid `.active` route.
- `.sailing → .docked` on arrival at a `.port` waypoint.
- `.docked → .sailing` when manifest execution at that port completes (all actions applied OR `dockTimeout` elapsed).
- `.sailing → .returning` when the route transitions to `.broken` or the next-waypoint port is removed.
- `.returning → .idle` on arrival at a port (any reachable port the ship can compute a straight-line path to without crossing land).

#### Scenario: Idle ship transitions to sailing on route assignment
- **WHEN** an `.idle` ship is assigned to a route whose `validate(route:)` returns `.valid`
- **THEN** within one tick the ship's state is `.sailing` and `waypointIdx` is set to the first sea or port waypoint after the ship's current position

#### Scenario: Sailing ship docks on arrival at port waypoint
- **WHEN** a `.sailing` ship moves within arrival epsilon of a `.port` waypoint
- **THEN** within one tick the ship's state becomes `.docked`

#### Scenario: Broken route triggers returning state
- **WHEN** the route a `.sailing` ship is following transitions to `.broken`
- **THEN** within one tick the ship's state becomes `.returning`

#### Scenario: Returning ship becomes idle on reaching a port
- **WHEN** a `.returning` ship arrives within arrival epsilon of any port it could reach in a straight line over water
- **THEN** within one tick the ship's state becomes `.idle` and its `routeID` is cleared

### Requirement: Per-tick ship integration
Each `.sailing` ship SHALL advance its position toward the position of `route.waypoints[ship.waypointIdx]` by `route.speed * dt` per tick, where `dt = Fixed(1.0/10.0)` (100 ms). Heading MUST be updated to match the direction of motion via `Fixed.atan2`. Ships within `arrivalEpsilon` (catalog-tuned, default `Fixed(0.25)`) of the target waypoint MUST advance their `waypointIdx` by one (modulo route length) at the end of the same tick.

#### Scenario: Ship reaches a waypoint within N ticks
- **WHEN** a ship at position `P` is sailing toward waypoint `Q` with speed `S` and Euclidean distance `D = distance(P, Q)`
- **THEN** after at most `ceil(D / (S * dt)) + 1` ticks the ship's `waypointIdx` has advanced past `Q`

#### Scenario: Heading is updated to match motion direction
- **WHEN** a `.sailing` ship integrates one tick toward a waypoint due north
- **THEN** the ship's heading after the tick equals `Fixed.atan2(north_dy, 0)` for the chosen north-positive convention

#### Scenario: Integration uses only Fixed arithmetic
- **WHEN** the `tickShips` system runs
- **THEN** no `Double`, `Float`, or `CGFloat` value is read or written by code reachable from that system call

### Requirement: Dock timeout policy
A `.docked` ship that cannot fully complete its current manifest action (port stock empty for a `.loadUpTo`, port capacity full for an `.unloadUpTo`) SHALL wait at most `dockTimeout` ticks (catalog-tuned, default 3000 ticks = 5 simulated minutes) and then advance to the next manifest action, applying it against whatever the port can now offer. Once all actions in the manifest have been attempted, the ship MUST transition back to `.sailing` toward the next waypoint regardless of whether actions fully succeeded.

#### Scenario: Ship waits when port is empty
- **WHEN** a docked ship's first manifest action is `.loadUpTo(wood, 50)` and the port has 0 wood
- **THEN** the ship remains `.docked` and its cargo does not change for at least 1 tick

#### Scenario: Ship advances past empty-port action after timeout
- **WHEN** a docked ship has waited `dockTimeout` ticks for a `.loadUpTo` that the port cannot satisfy at all
- **THEN** at tick `dockTimeout + 1` the ship advances to the next manifest action or, if none remains, transitions to `.sailing` toward the next waypoint

#### Scenario: Ship resumes sailing after partial manifest completion
- **WHEN** a docked ship has applied every manifest action at its current port (each capped by ship/port limits)
- **THEN** the ship transitions to `.sailing` toward the next waypoint within one tick

### Requirement: Route lifecycle commands
The command system SHALL accept the following commands at tick boundaries: `CreateRoute(waypoints:manifest:speed:)`, `EditRoute(id:waypoints:manifest:)`, `DeleteRoute(id:)`, `AssignShipToRoute(shipID:routeID:)`, `UnassignShip(shipID:)`. Each command MUST be validated; invalid commands MUST be rejected with a reason code and MUST NOT mutate state.

#### Scenario: CreateRoute rejected when validation fails
- **WHEN** `CreateRoute` is enqueued with waypoints whose validation returns `.invalid`
- **THEN** the command is rejected with the validation's reason code and no route is added to the world

#### Scenario: EditRoute recomputes ship waypoint index
- **WHEN** `EditRoute` replaces the waypoint list for a route while a ship is currently sailing toward `waypoints[i]`
- **THEN** after the command applies, the ship's `waypointIdx` is set to the index of the smallest-index waypoint in the new list that lies ahead of the ship along the new route order, or 0 if no such waypoint exists

#### Scenario: DeleteRoute idles all assigned ships
- **WHEN** `DeleteRoute(id:)` applies to a route with N ships assigned
- **THEN** all N ships transition to `.returning` within one tick and their `routeID` becomes nil after they reach `.idle`

### Requirement: Multiple ships per route
Two or more ships MAY be assigned to the same route simultaneously. Ships SHALL NOT collide; they MAY occupy overlapping positions. Each ship MUST maintain its own `waypointIdx` and cargo independently.

#### Scenario: Two ships assigned to same route operate independently
- **WHEN** ships `A` and `B` are both assigned to route `R` and ship `A`'s `waypointIdx` is 3 while `B`'s is 0
- **THEN** both ships continue integrating toward their respective targets without interfering

#### Scenario: Two ships at the same position do not interfere
- **WHEN** ships `A` and `B` happen to occupy positions within arrival epsilon of each other
- **THEN** neither ship's position, heading, cargo, nor state is altered by the proximity

### Requirement: Snapshot inclusion
The `Ship` and `Route` entities (with all components) SHALL be included in `World` Codable snapshots. A loaded snapshot MUST resume ship motion and manifest execution from the exact persisted position, heading, waypoint index, cargo, and state.

#### Scenario: Ship resumes mid-segment after load
- **WHEN** a snapshot taken while a ship is at position `P` with heading `H` and `waypointIdx` `i` is loaded
- **THEN** the loaded ship has the same position `P`, heading `H`, and `waypointIdx` `i`, and its next tick advances it toward `waypoints[i]`

#### Scenario: Docked ship resumes manifest progress after load
- **WHEN** a snapshot taken while a ship is `.docked` mid-manifest (e.g. after applying action 0 of 3) is loaded
- **THEN** the ship resumes from action 1 of 3 on the next tick at that port
