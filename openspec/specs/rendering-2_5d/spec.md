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

### Requirement: HUD reflects the camera's current island

The HUD SHALL display the name of the island under the camera and a stocks row showing the goods currently held on that island. The lookup MUST read from `WorldSnapshot.island(at: snapshot.camera.centerTile())`. When the camera is over water, the HUD MUST display the most recent island it was over (sticky behavior) so the player keeps their reference frame during sea crossings.

#### Scenario: HUD reads current island from camera

- **WHEN** the camera centers on a tile inside Island #2
- **THEN** the HUD shows Island #2's name and its `IslandSummary.stockpile` as good chips

#### Scenario: HUD is sticky over water

- **WHEN** the camera was over Island #1 and pans over open water without crossing into another island
- **THEN** the HUD continues to display Island #1's name and stocks

#### Scenario: HUD switches when camera enters another island

- **WHEN** the camera was sticky on Island #1 and pans into Island #2
- **THEN** the HUD updates to Island #2's name and stocks on the next snapshot

#### Scenario: HUD is empty when camera has never been on an island

- **WHEN** a fresh world is loaded with the camera starting over water (no `previousIsland` cached) and no Island in view
- **THEN** the HUD shows the money / population badge as usual and the island row is hidden

### Requirement: Stocks row layout

The HUD's stocks row SHALL render one chip per good with non-zero stock OR non-zero capacity on the current island. Each chip MUST display the good's icon (loaded from `Icons.atlas`) and the integer count. Goods with both zero stock AND zero capacity MUST be omitted to keep the row uncluttered.

#### Scenario: Stocks row shows goods present on the island

- **WHEN** the current island has 12 wood and 4 planks in its stockpile
- **THEN** the HUD renders two chips: a wood chip with "12" and a planks chip with "4"

#### Scenario: Goods with zero stock and zero capacity are omitted

- **WHEN** an island has warehouses storing wood and planks but no capacity at all for food
- **THEN** the food chip is not rendered

#### Scenario: Goods icon uses nearest-neighbor interpolation

- **WHEN** a good icon is rendered at any scale
- **THEN** SwiftUI's `Image.interpolation(.none)` is applied so the pixel art stays crisp

### Requirement: Ghost preview surfaces material cost

When a build tool is armed and the player is hovering over a tile, the ghost preview SHALL expose the building's `materialCost` and the current available amount on the placement's island via a `costBreakdown: [Good: (need: Int, have: Int)]?` payload. The CityUI cost-breakdown row MUST render one chip per required good, showing the per-good `need / have` pair. Goods where `have < need` MUST render in a red foreground color. Tools whose armed building has empty `materialCost` (road, demolish, inspect) MUST produce a nil `costBreakdown` and hide the row entirely.

#### Scenario: Ghost preview surfaces material cost when build tool is armed

- **WHEN** the player arms the sawmill build tool and hovers over a buildable tile
- **THEN** the ghost preview returns a `costBreakdown` with entries for `.wood` (need: 4) and `.planks` (need: 1)

#### Scenario: Cost breakdown reads available stock from current island

- **WHEN** the placement anchor falls on Island #1 and Island #1 holds 2 wood and 3 planks
- **THEN** the `have` values in the breakdown are 2 wood and 3 planks (not the global total across islands)

#### Scenario: Shortfall good highlights red

- **WHEN** the cost breakdown's `(need, have)` for a good has `have < need`
- **THEN** the chip's text color is red (or the platform's equivalent destructive style)

#### Scenario: Free-of-materials tool has no cost row

- **WHEN** the player arms the road build tool
- **THEN** `costBreakdown` is nil and the cost-breakdown row is not rendered

### Requirement: Camera center tile exposure

`Camera` SHALL expose a `centerTile() -> TileCoordinate` method that returns the integer tile the camera's center is currently over, using floor semantics — tile (x, y) covers the half-open square `[x, x+1) × [y, y+1)` in tile-space. This is read by `IsoWorldScene` once per camera-driven listener update to inform the audio layer's listener position. (The existing implementation pre-dates this change, originally added in `add-island-hud-overlay`; the floor invariant matches how the HUD's tile-to-island lookup is defined.)

#### Scenario: Camera-center tile is exposed

- **WHEN** the camera has `centerX = 8.4`, `centerY = 6.2`
- **THEN** `centerTile()` returns `TileCoordinate(x: 8, y: 6)`

#### Scenario: Camera-center tile updates as camera pans

- **WHEN** the camera pans from `centerX = 8.4` to `centerX = 9.6`
- **THEN** `centerTile()` returns `TileCoordinate(x: 9, y: 6)` after the pan (floor of the fractional center)

### Requirement: Camera listener callback

`IsoWorldScene` SHALL accept a `cameraListener: ((TileCoordinate) -> Void)?` callback that fires at most once per wall-clock second from inside the scene's per-frame tick. The callback receives the current `centerTile()`. When the callback is nil, the scene MUST NOT perform any per-second listener bookkeeping (cost is gated on the consumer being present).

#### Scenario: Callback invoked at most 1 Hz

- **WHEN** the scene's per-frame tick fires 120 times within one wall-clock second and `cameraListener` is set
- **THEN** the callback is invoked at most once across that window

#### Scenario: Callback receives current camera center

- **WHEN** the callback fires and the camera's `centerTile()` is `(8, 6)`
- **THEN** the callback receives `TileCoordinate(x: 8, y: 6)`

#### Scenario: No callback means no work

- **WHEN** `cameraListener` is nil
- **THEN** the scene's per-frame tick does no per-second timestamping or tile-rounding for the listener path

### Requirement: Road-access marker

The world snapshot SHALL list every building, other than roads, that has no road tile orthogonally adjacent to its footprint. The renderer MUST draw a "no road" marker above each listed building, and MUST remove the marker as soon as a road touches the building. The building inspector MUST show a "Road:" line that reads "connected" or "none".

#### Scenario: Snapshot lists a building without an adjacent road

- **WHEN** a house stands with no road tile next to any of its footprint tiles
- **THEN** the snapshot's set of road-disconnected buildings contains the house

#### Scenario: A touching road clears the snapshot entry

- **WHEN** a road is placed on a tile orthogonally adjacent to that house's footprint and one tick runs
- **THEN** the snapshot's set of road-disconnected buildings no longer contains the house

#### Scenario: Disconnected building sprite carries the no-road marker

- **WHEN** the renderer builds the sprite for a building listed as road-disconnected
- **THEN** the building node has a child named `overlay-no-road`

#### Scenario: Inspector reports road access

- **WHEN** the inspector is opened on a building listed as road-disconnected
- **THEN** its lines include "Road: none"

### Requirement: Building sprites anchor at the footprint's bottom vertex

The renderer SHALL place a building sprite (and the placement ghost) horizontally centred on the building's footprint diamond, with the sprite's bottom edge on the diamond's bottom vertex. Relative to the anchor tile's centre, the sprite's bottom-centre is at x = (w − h) × tileWidth / 4 (the diamond's centre) and y = −(w + h − 1) × tileHeight / 2 (the bottom vertex) for a w × h footprint.

#### Scenario: A 2×3 building's sprite sits on its footprint

- **WHEN** the renderer builds the node for a building with a 2×3 footprint
- **THEN** the sprite's position relative to its anchor tile is x = −16 and y = −64

#### Scenario: Square footprints keep their existing anchor

- **WHEN** the renderer builds the node for a building with a 2×2 footprint
- **THEN** the sprite's position relative to its anchor tile is x = 0 and y = −48

### Requirement: Houses render their tier

The world snapshot SHALL report each house's tier. The renderer MUST draw a peasant house with `building-house`, a citizen house with `building-house-tier2` and a merchant house with `building-house-tier3`, and MUST swap the sprite when the tier changes.

#### Scenario: Merchant house uses the tier 3 sprite

- **WHEN** the renderer builds the sprite for an operational house whose snapshot tier is merchants
- **THEN** the node's texture is `building-house-tier3`

#### Scenario: Tier change swaps the house sprite

- **WHEN** a house's tier changes between two snapshots
- **THEN** the reconciler replaces that house's node

### Requirement: Terrain shows the season

Grass and forest tiles SHALL use their autumn sprites in autumn and their winter sprites in winter (`terrain-<kind>-autumn`, `terrain-<kind>-winter`, with matching animation frames), and their regular sprites in spring and summer. Tiles that come into view later SHALL use the current season's sprites. A missing seasonal sprite SHALL fall back to the regular one.

#### Scenario: Winter tints grass

- **WHEN** the scene renders a snapshot dated winter
- **THEN** visible grass nodes show the winter grass sprite

#### Scenario: Summer has no tint

- **WHEN** the scene renders a snapshot dated summer
- **THEN** visible grass nodes show the regular grass sprite

### Requirement: Buildings render in the world's culture

An operational building or upgraded house SHALL use its culture variant sprite (`building-<kind>-<culture>`, `building-house-tier<N>-<culture>`) when the world's culture is not Northern European and the variant exists, and the shared sprite otherwise. Construction stages SHALL use the shared sprites.

#### Scenario: East Asian town center

- **WHEN** the scene draws an operational town center in an East Asian world
- **THEN** the node's texture name is "building-town-center-east-asian"

#### Scenario: Shared fallback

- **WHEN** the scene draws an operational sawmill in an East Asian world
- **THEN** the node uses the shared sawmill sprite

#### Scenario: Construction stays shared

- **WHEN** the scene draws a house under construction in a Middle Eastern world
- **THEN** the node uses the shared construction sprite
