# rendering-2_5d Specification

## Purpose
TBD - created by archiving change add-mvp-foundation. Update Purpose after archive.

## Requirements
### Requirement: Isometric tile renderer
The world SHALL be rendered in 2.5D isometric projection using SpriteKit. The renderer MUST consume `WorldSnapshot` values from `CityCore` without mutating simulation state.

#### Scenario: Snapshot-driven rendering
- **WHEN** the renderer draws a frame
- **THEN** all drawn entities reflect the most recent `WorldSnapshot` and the renderer performs no writes to the simulation

### Requirement: Custom tilemap (no SKTileMapNode)
The renderer SHALL NOT use `SKTileMapNode`. Tiles MUST be drawn as individually managed `SKSpriteNode` instances or batched draws to allow variable footprints and isometric stacking.

#### Scenario: Variable-footprint building drawn correctly
- **WHEN** a 3×3 building is placed
- **THEN** the renderer draws it as a single visual unit aligned to its anchor tile in iso projection

### Requirement: Visible-tile culling
The renderer SHALL draw only sprites visible within the current camera view plus a small buffer margin. Off-screen sprites MUST not be added to the SpriteKit scene tree.

#### Scenario: Off-screen tile not in scene
- **WHEN** the camera is positioned such that tile (X, Y) is fully outside the visible region plus margin
- **THEN** no SpriteKit node corresponds to tile (X, Y)

### Requirement: Camera pan and zoom
The renderer SHALL provide a camera that can pan over the map and zoom within configured min/max factors. Camera state MUST be persistable per game so it restores on load.

#### Scenario: Two-finger pan
- **WHEN** the user performs a two-finger pan gesture on iPad
- **THEN** the camera translates by the gesture delta

#### Scenario: Pinch zoom respects bounds
- **WHEN** the user pinches inward beyond minimum zoom
- **THEN** zoom is clamped to the minimum and further pinching has no effect

#### Scenario: Camera persists across save/load
- **WHEN** a save is loaded
- **THEN** the camera position and zoom restore to their values at save time

### Requirement: Input mapping
The renderer SHALL translate user input into intent values dispatched to a controller layer. Raw input MUST NOT be wired directly into `CityCore`. Supported inputs include tap/click, drag, pinch, two-finger pan, hover (Mac/iPad pointer), and Apple Pencil hover where available.

#### Scenario: Tap dispatched as intent
- **WHEN** the user taps a tile
- **THEN** an intent of `tapTile(coord)` is dispatched to the controller, which decides what to do (e.g. enqueue a place command)

### Requirement: Frame interpolation between ticks
Visual positions for moving entities (notably carriers) SHALL be interpolated between consecutive simulation snapshots to provide smooth motion at display refresh rate.

#### Scenario: Carrier moves smoothly between ticks
- **WHEN** the simulation ticks at 10 Hz and the display refreshes at 60 Hz
- **THEN** carrier sprites are visually positioned by interpolating between the previous and current tick's positions

### Requirement: 60 fps target on baseline iPad
The renderer MUST hold 60 fps on the baseline iPad target for an MVP-sized maxed-out island under typical gameplay conditions.

#### Scenario: Frame budget held under load
- **WHEN** the maxed-out MVP island is rendered with all gameplay running
- **THEN** the average frame duration stays at or below 16.7 ms over a 60-second profiling sample

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

### Requirement: Sprite loading via SpriteAtlas
The 2.5D renderer SHALL obtain every sprite texture used to draw terrain, buildings, walkers, or any future categorized sprite kind exclusively through the `SpriteAtlas` type. Direct calls to `SKTexture(imageNamed:)` for catalogued sprites MUST NOT appear in any CityRender2D source file.

#### Scenario: Renderer source uses SpriteAtlas exclusively
- **WHEN** the CityRender2D test suite runs a code-scan check across all `.swift` files in CityRender2D
- **THEN** no occurrence of `SKTexture(imageNamed:` is found for sprite categories covered by the catalog

#### Scenario: Sprite rendering is unchanged at runtime
- **WHEN** a snapshot is rendered with the post-migration `SpriteAtlas` and compared to a pre-migration screenshot of the same snapshot
- **THEN** the two images are visually indistinguishable (no pixel-level regression check required; visual smoke is sufficient)

### Requirement: Missing-sprite fallback in release
In release builds, if `SpriteAtlas` resolves a sprite name to a nil texture (e.g., due to a catalog bug that escaped debug-build asset-presence checks), the renderer SHALL draw a single-color placeholder sprite (magenta, 32×32) and log the missing sprite name once per process lifetime. The renderer MUST NOT crash.

#### Scenario: Placeholder drawn for missing sprite
- **WHEN** a release build attempts to draw a sprite whose name resolves to nil
- **THEN** a magenta 32×32 placeholder is drawn at the intended position and no crash occurs

#### Scenario: Missing sprite logged once
- **WHEN** the same missing sprite name is encountered N times in a single process lifetime
- **THEN** the renderer logs the name exactly once
