## ADDED Requirements

### Requirement: Ship facing selection
The 2.5D renderer SHALL select the texture for each `Ship` sprite from a set of exactly 8 pre-rendered facings — `n`, `ne`, `e`, `se`, `s`, `sw`, `w`, `nw` — by quantizing the ship's snapshot `Fixed` heading to the nearest facing. Free `zRotation` rotation of ship sprites is forbidden: every ship sprite SHALL have `zRotation == 0` at all times. Texture swap on facing change MUST be instantaneous (no cross-fade, no blend).

#### Scenario: Heading near east selects east facing
- **WHEN** a ship's snapshot heading is `Fixed(0)` (east in the world convention)
- **THEN** the renderer assigns the `ship-e-<frame>` texture to that ship's sprite

#### Scenario: Heading just past 22.5° selects northeast facing
- **WHEN** a ship's snapshot heading is `Fixed(0.40)` radians (~22.9°, just past the halfway between E and NE)
- **THEN** the renderer assigns the `ship-ne-<frame>` texture to that ship's sprite

#### Scenario: Heading transitions snap immediately
- **WHEN** a ship's heading changes between snapshots such that the nearest facing changes from `e` to `ne`
- **THEN** within one render frame the ship sprite's texture is `ship-ne-<frame>`; no intermediate rotation is applied

#### Scenario: Ship zRotation always zero
- **WHEN** any ship sprite is inspected at any render frame
- **THEN** its `zRotation` property is `0`

### Requirement: Ship sprite rendering
The renderer SHALL draw each `Ship` entity as an `SKSpriteNode` whose position is derived from the ship's `Fixed2D` snapshot position via the standard iso projection, with sub-tile interpolation between snapshots so motion appears smooth at display refresh rate.

#### Scenario: Ship sprite present for every ship entity
- **WHEN** the renderer reconciles a snapshot containing N ship entities
- **THEN** the scene graph contains exactly N ship sprites under the ships layer node

#### Scenario: Ship sprite removed when ship despawns
- **WHEN** a ship entity is removed from a snapshot (e.g. sunk in a future change)
- **THEN** the corresponding ship sprite is removed from the scene graph within the next render frame

#### Scenario: Ship position is sub-tile smooth
- **WHEN** a ship moves from position `P1` to `P2` between two snapshots 100 ms apart
- **THEN** the ship sprite's drawn position at any intermediate render frame is a linear interpolation of `P1` and `P2` weighted by elapsed render-frame time

### Requirement: Off-screen ship culling
Ship sprites whose projected screen position falls outside the visible viewport (plus a configurable margin) SHALL be removed from the scene graph and re-added when they re-enter the viewport. While culled, no per-frame interpolation work is performed for that ship.

#### Scenario: Off-screen ship sprite removed
- **WHEN** a ship's projected screen position is outside the viewport plus the configured margin
- **THEN** within one render frame the sprite is not present in the scene graph

#### Scenario: Re-entering ship sprite re-added
- **WHEN** a previously-culled ship's projected screen position re-enters the viewport plus margin
- **THEN** within one render frame the sprite is present in the scene graph at the snapshot-derived position

### Requirement: Shore-building orientation derivation
For each shore-placement building (Port, Shipyard, or any future opt-in to the shore-placement rule), the renderer SHALL derive a cardinal `orientation` value from `{n, s, e, w}` by comparing the centroid of the building's `seaFace` tiles to the centroid of its `landFace` tiles, and SHALL select the corresponding sprite variant `building-<kind>-<orientation>[-<state>-<frame>]`. The derivation MUST be pure and deterministic.

#### Scenario: Sea-face north derives orientation n
- **WHEN** a Port's sea-face centroid has a smaller `y` than its land-face centroid (water is to the north in tile-space convention where lower `y` is north)
- **THEN** the renderer selects sprite variant `building-port-n-*`

#### Scenario: Sea-face east derives orientation e
- **WHEN** a Port's sea-face centroid has a larger `x` than its land-face centroid
- **THEN** the renderer selects sprite variant `building-port-e-*`

#### Scenario: Shipyard uses same derivation rule
- **WHEN** a Shipyard has its sea-face centroid south of its land-face centroid
- **THEN** the renderer selects sprite variant `building-shipyard-s-*`

#### Scenario: Orientation persists with building
- **WHEN** a shore-building's `landFace`/`seaFace` classification has not changed between two snapshots
- **THEN** the renderer's derived `orientation` is identical between those two snapshots

#### Scenario: Tie-breaking prefers axis with larger centroid delta
- **WHEN** sea-face and land-face centroids differ in both `x` and `y` (e.g. an L-shaped split)
- **THEN** the renderer selects the orientation corresponding to the axis with the larger absolute centroid delta

### Requirement: Route polyline overlay
The renderer SHALL draw a polyline overlay representing the waypoint sequence of any route that is either (a) selected in the UI, or (b) currently being edited in route-authoring mode. The overlay MUST be drawn in a layer above terrain and below buildings, and MUST NOT be drawn for routes that are neither selected nor under edit (to avoid overdraw clutter at scale).

#### Scenario: Selected route renders polyline
- **WHEN** the user selects a route in the UI
- **THEN** within one render frame a polyline connecting all of that route's waypoint projected positions is visible

#### Scenario: Unselected route does not render polyline
- **WHEN** no route is selected and route-authoring mode is inactive
- **THEN** no route polyline is present in the scene graph

#### Scenario: Polyline layer ordering
- **WHEN** a route polyline is drawn
- **THEN** its z-position is greater than the terrain layer's z-position and less than the buildings layer's z-position

### Requirement: Route-authoring input mode
The 2.5D renderer SHALL support a route-authoring input mode entered from the UI. While the mode is active: (a) a tap on a port building adds a `.port(id:)` waypoint to the in-progress route; (b) a tap on a water tile adds a `.sea(position:)` waypoint at the iso-unprojected tap position; (c) a tap on a land tile is rejected with visual feedback (red flash) and no waypoint is added; (d) the in-progress polyline is rendered live, with any segment that would cross land highlighted in red; (e) tapping a "Commit" affordance issues the `CreateRoute` command via the command queue and exits the mode; (f) tapping a "Cancel" affordance discards the in-progress route and exits the mode.

#### Scenario: Tap on port adds port waypoint
- **WHEN** the user is in route-authoring mode and taps a port building
- **THEN** the in-progress route gains a `.port(id:)` waypoint referencing that port's `PortID`

#### Scenario: Tap on water tile adds sea waypoint
- **WHEN** the user is in route-authoring mode and taps an unoccupied water tile
- **THEN** the in-progress route gains a `.sea(position:)` waypoint at the tapped tile's `Fixed2D` center

#### Scenario: Tap on land tile rejected
- **WHEN** the user is in route-authoring mode and taps a non-water tile that is not a port
- **THEN** no waypoint is added and a red-flash visual cue plays on the tap location

#### Scenario: Land-crossing segment highlighted red
- **WHEN** the in-progress route contains a segment between two waypoints that would cross one or more non-water tiles
- **THEN** that segment is drawn in red until the segment is corrected by adding intermediate waypoints

#### Scenario: Commit issues CreateRoute command
- **WHEN** the user taps Commit on an in-progress route with ≥2 port waypoints and no red segments
- **THEN** a `CreateRoute(waypoints:manifest:speed:)` command is enqueued at the next tick boundary and the renderer exits route-authoring mode

#### Scenario: Commit rejected when red segments remain
- **WHEN** the user taps Commit on an in-progress route containing at least one red (land-crossing) segment
- **THEN** no command is enqueued, the renderer remains in route-authoring mode, and the UI surfaces the validation failure reason

#### Scenario: Cancel discards in-progress route
- **WHEN** the user taps Cancel while in route-authoring mode
- **THEN** the in-progress route's waypoint buffer is cleared and the renderer exits route-authoring mode
