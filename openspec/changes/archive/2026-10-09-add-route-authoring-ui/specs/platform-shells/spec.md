## ADDED Requirements

### Requirement: Routes button and route list

The HUD SHALL show a Routes button when the player owns a port or a ship, or the world has a route. It SHALL open a route list with one row per route in ID order. A row's title SHALL read "Route <n>" by list position, its stops line SHALL join the route's port stops with " → " (a player port reads "Your port (<x>, <y>)" from its anchor, a rival port "<rival name>'s port"), and its status SHALL read "Active", "Paused" or "Broken" followed by " · <n> ship" or " · <n> ships". Each row SHALL offer Pause or Resume, Assign ship and Delete, and tapping a row SHALL select it for the map overlay (tapping the selected row clears the selection). The list SHALL offer New Route.

#### Scenario: Routes button needs a port, ship or route

- **WHEN** the player owns a port
- **THEN** the Routes button is shown
- **WHEN** the player owns no port and no ship and the world has no route
- **THEN** the Routes button is hidden

#### Scenario: Route list row text

- **WHEN** the world has one active route from the player's port anchored at (3, 4) to rival Mosshold's port, with one ship assigned
- **THEN** the row reads "Route 1", "Your port (3, 4) → Mosshold's port" and "Active · 1 ship"

#### Scenario: Pausing from the route list

- **WHEN** the player taps Pause on an active route's row
- **THEN** a `setRoutePaused(id:paused: true)` command is enqueued

### Requirement: Assigning a ship to a route

The route list SHALL show the number of the player's idle ships (state `.idle`, no route). Assign ship on a row SHALL enqueue `assignShipToRoute` for the lowest-ID idle player ship. With no idle ship the button SHALL be disabled and read "No idle ship".

#### Scenario: Assign the first idle ship

- **WHEN** the player has idle ships 40 and 41 and taps Assign ship on route `R`
- **THEN** `assignShipToRoute(shipID: 40, routeID: R)` is enqueued

#### Scenario: No idle ship to assign

- **WHEN** the player's only ship is sailing a route
- **THEN** the idle ship count is 0 and Assign ship is disabled

### Requirement: Route mode

The player SHALL enter route mode from New Route in the route list, or from Route from here on any port's inspector, which adds that port as the first stop. Entering SHALL clear a pending placement, the tile menu and the route selection and SHALL reset the tool to inspect. While route mode is on, a world tap SHALL go to the route-authoring view-model (ports of any owner and water tiles add stops, land is rejected) and SHALL NOT select a tile or enqueue a command, a long-press SHALL do nothing, and the build palette and inspector SHALL be hidden. A bottom overlay SHALL list the stops and offer Undo (remove the last stop), Cancel and Commit. Its message SHALL read "Tap ports and water to add stops.", "Ships can't stop on land." after a rejected land tap, "A route needs at least two ports." after a commit with fewer than two ports, and "A red leg crosses land. Add water stops around it." after a commit with a red segment. A successful commit SHALL enqueue `CreateRoute` and leave route mode; a rejected commit SHALL stay in route mode.

#### Scenario: World taps add stops in route mode

- **WHEN** route mode is on and the player taps a water tile
- **THEN** the in-progress route gains a sea waypoint, the selected tile is unchanged and no command is enqueued

#### Scenario: Route from here starts at the port

- **WHEN** the player inspects a rival port and taps Route from here
- **THEN** route mode is on and its first stop is that port

#### Scenario: Long-press does nothing in route mode

- **WHEN** route mode is on and the player long-presses a tile
- **THEN** no tile menu is requested

#### Scenario: Commit message for a lone port

- **WHEN** the player commits a route with one port stop
- **THEN** the overlay reads "A route needs at least two ports." and route mode stays on

#### Scenario: Land tap message

- **WHEN** the player taps a land tile in route mode
- **THEN** the overlay reads "Ships can't stop on land." until the next accepted tap

#### Scenario: Undo removes the last stop

- **WHEN** the player has stops port A, sea, port B with a manifest for B and taps Undo
- **THEN** the stops are port A and sea, and B's manifest is gone

#### Scenario: Commit leaves route mode

- **WHEN** the player commits a route between two ports over open water
- **THEN** a `CreateRoute` command is enqueued and route mode is off

### Requirement: Manifest editor sheet

Each port stop in the route-mode overlay SHALL open a manifest editor for that port. The editor SHALL list the port's actions in order and SHALL add an action from a verb, a good and a quantity from 5 to 100 in steps of 5 (default 20), and remove any action. At a player port an action SHALL read "Load <qty> <good>" or "Unload <qty> <good>"; at a rival port "Buy <qty> <good> — $<sell price>" or "Sell <qty> <good> — $<buy price>". At a rival port each good choice SHALL read "<good> — $<price> — <offer>" or "<good> — no offer". Done SHALL store the actions as the port's manifest (an empty list clears it); Cancel SHALL discard the edits.

#### Scenario: Draft adds and removes actions

- **WHEN** the player adds "load 20 planks" and "unload 10 wood" and removes the first
- **THEN** the draft holds only `unloadUpTo(wood, 10)`

#### Scenario: Rival port actions read buy and sell

- **WHEN** the player edits the manifest of a rival port that sells 12 wood, holding "load up to 20 wood"
- **THEN** the action reads "Buy 20 Wood — $5" and the wood choice for Buy reads "Wood — $5 — 12"

#### Scenario: Saved manifest rides on the route

- **WHEN** the player saves "unload 10 planks" for port B and commits a route from port A to port B
- **THEN** the `CreateRoute` command's manifest for B is `[unloadUpTo(planks, 10)]`
