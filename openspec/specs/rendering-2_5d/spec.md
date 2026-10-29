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

The world snapshot SHALL list every building, other than roads, that has no road tile orthogonally adjacent to its footprint. The renderer MUST show the no-road status icon ("Buildings show a status icon while something is wrong") above each listed building, and MUST remove it as soon as a road touches the building. The building inspector MUST show a "Road:" line that reads "connected" or "none".

#### Scenario: Snapshot lists a building without an adjacent road

- **WHEN** a house stands with no road tile next to any of its footprint tiles
- **THEN** the snapshot's set of road-disconnected buildings contains the house

#### Scenario: A touching road clears the snapshot entry

- **WHEN** a road is placed on a tile orthogonally adjacent to that house's footprint and one tick runs
- **THEN** the snapshot's set of road-disconnected buildings no longer contains the house

#### Scenario: Disconnected building sprite carries the no-road marker

- **WHEN** the renderer reconciles a snapshot listing a building as road-disconnected
- **THEN** the building's sprite has a status-icon child textured `status-no-road`

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

Grass tiles, and the grass that forest and mountain tiles stand on, SHALL use their autumn sprites in autumn and their winter sprites in winter (`terrain-grass-autumn`, `terrain-grass-winter`, with matching variants and animation frames), and their regular sprites in spring and summer. Tiles that come into view later SHALL use the current season's sprites. A missing seasonal sprite SHALL fall back to the regular one.

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

### Requirement: Houses render in the world's age

A finished house SHALL use the most specific sprite that exists among `building-house[-tierN]-<age>-<culture>`, `building-house[-tierN]-<age>`, `building-house[-tierN]-<culture>` and `building-house[-tierN]`, where the age part is omitted for Medieval and the culture part for Northern European.

#### Scenario: Industrial Mediterranean citizens

- **WHEN** the scene draws a citizens-tier house in an Industrial Mediterranean world
- **THEN** the node's texture name is "building-house-tier2-industrial-mediterranean"

#### Scenario: Medieval names are unchanged

- **WHEN** the scene draws a peasants-tier house in a Medieval Northern European world
- **THEN** the node uses the shared house sprite

### Requirement: Iso direction enumeration

CityRender2D SHALL expose a public `IsoDirection` enum with four cases — `.ne`, `.se`, `.sw`, `.nw` — naming the four iso-grid axes along which the placement HUD's arrow controls move a pending ghost. Each case MUST expose a `tileOffset: (dx: Int, dy: Int)` whose values move the pending anchor by exactly one tile along the named axis. `IsoDirection` MUST live in CityRender2D (not CityCore) to preserve the framework-free invariant on CityCore.

#### Scenario: IsoDirection NE moves ghost up-right by one tile

- **WHEN** `IsoDirection.ne.tileOffset` is queried
- **THEN** it returns `(dx: 0, dy: -1)`

#### Scenario: IsoDirection SE moves ghost down-right by one tile

- **WHEN** `IsoDirection.se.tileOffset` is queried
- **THEN** it returns `(dx: 1, dy: 0)`

#### Scenario: IsoDirection SW moves ghost down-left by one tile

- **WHEN** `IsoDirection.sw.tileOffset` is queried
- **THEN** it returns `(dx: 0, dy: 1)`

#### Scenario: IsoDirection NW moves ghost up-left by one tile

- **WHEN** `IsoDirection.nw.tileOffset` is queried
- **THEN** it returns `(dx: -1, dy: 0)`

### Requirement: Long-press intent translation

The renderer's `InputTranslator` SHALL expose `longPressIntent(atScreenPoint:mapWidth:mapHeight:)` that converts a long-press location to a `.longPressTile(coord)` intent, returning `nil` when the press falls outside the map bounds. Long-press is an iOS-only gesture; the renderer's Mac path MUST NOT emit `.longPressTile` intents.

#### Scenario: Long-press point translates to long-press intent at the tile under the touch

- **WHEN** `InputTranslator.longPressIntent(atScreenPoint: p, mapWidth: 32, mapHeight: 32)` is called with `p` at the screen center of tile (5, 7)
- **THEN** the returned intent equals `.longPressTile(TileCoordinate(x: 5, y: 7))`

#### Scenario: Long-press outside map bounds dispatches no intent

- **WHEN** `InputTranslator.longPressIntent` is called with a screen point that resolves to a tile coordinate outside the `(0..<mapWidth) × (0..<mapHeight)` range
- **THEN** the call returns `nil`

#### Scenario: Long-press inside map bounds dispatches longPressTile intent

- **WHEN** the iOS scene's long-press recognizer fires its `.began` event inside the map bounds
- **THEN** the scene's intent sink receives exactly one `.longPressTile(coord)` intent at the tile under the touch-down point

### Requirement: Placement-confirmation intents

The `Intent` enum SHALL include `.confirmPlacement`, `.cancelPlacement`, and `.nudgePlacement(direction: IsoDirection)` cases. They name the pending-placement state machine's transitions: confirm enqueues a `.place` command at the pending anchor and clears pending state, cancel clears pending state without enqueuing, nudge moves the pending anchor one tile along the direction's `tileOffset`. The renderer never emits these three intents (the placement HUD is SwiftUI and calls `GameSession.confirmPendingPlacement()`, `cancelPendingPlacement()` and `nudgePendingPlacement(_:)` directly), so the app shells ignore them. `GameSession` mirrors `IsoDirection` as `NudgeDirection` because CityUI does not depend on CityRender2D. The transitions MUST be platform-neutral so headless tests and the CLI can drive the flow.

A confirm whose placement `World.canPlace` rejects (the tile became occupied, the player lost the money) MUST NOT clear the pending state: it shows the rejection on the HUD so the player can nudge somewhere valid.

#### Scenario: Confirm placement intent enqueues a place command

- **WHEN** a `PendingPlacement(kind: .house, anchor: (3, 4))` is active and the controller receives `.confirmPlacement`
- **THEN** the world's command queue gains a `.place(.house, at: TileCoordinate(x: 3, y: 4))` command and the pending placement is cleared

#### Scenario: Cancel placement intent clears state without enqueuing

- **WHEN** a `PendingPlacement` is active and the controller receives `.cancelPlacement`
- **THEN** the pending placement is cleared and no command is enqueued

#### Scenario: Confirm of a rejected placement keeps it pending

- **WHEN** a `PendingPlacement` is active on a tile the world would reject and the controller receives `.confirmPlacement`
- **THEN** the pending placement stays, no command is enqueued, and the HUD shows the rejection message

#### Scenario: Nudge placement intent moves the pending anchor

- **WHEN** a `PendingPlacement(anchor: (5, 5))` is active and the controller receives `.nudgePlacement(direction: .se)`
- **THEN** the pending anchor becomes `(6, 5)` and no command is enqueued

### Requirement: Pending-placement nudge clamps to map bounds

The pending placement's anchor SHALL be clamped to the map's tile range `(0..<mapWidth) × (0..<mapHeight)`. A `.nudgePlacement` that would push the anchor outside bounds MUST be a no-op (the previous anchor persists). The placement HUD MAY visually disable the arrow that would push out of bounds, but the no-op behavior is the source of truth.

#### Scenario: Nudge placement clamps at the east edge

- **WHEN** a `PendingPlacement(anchor: (mapWidth - 1, 5))` is active and the controller receives `.nudgePlacement(direction: .se)`
- **THEN** the pending anchor remains `(mapWidth - 1, 5)` and the intent is a no-op

#### Scenario: Nudge placement clamps at the north edge

- **WHEN** a `PendingPlacement(anchor: (5, 0))` is active and the controller receives `.nudgePlacement(direction: .ne)`
- **THEN** the pending anchor remains `(5, 0)` and the intent is a no-op

### Requirement: Placement HUD

CityUI on iOS SHALL render a `PlacementHUD` overlay whenever `GameSession.pendingPlacement` is non-nil. The HUD MUST display four iso-aligned arrow buttons (NE, SE, SW, NW), a central checkmark button, and a cancel button. Each arrow button MUST nudge the pending anchor along the matching direction (the `.nudgePlacement` transition) and MAY be disabled when that step would leave the map. The checkmark button MUST confirm (the `.confirmPlacement` transition) and is tinted by whether the placement is currently valid; confirming an invalid one shows why instead of placing. The cancel button MUST cancel (the `.cancelPlacement` transition). All buttons MUST have hit targets of at least 44 × 44 points to satisfy iOS touch-target guidelines. The arrows sit a fixed distance from the tile, along the rendered diamond's diagonals, so they stay large at any zoom.

The HUD anchors to the screen position of the pending tile, derived by `IsoMath` projection of `pendingPlacement.anchor` through the current `Camera`. The HUD MUST track the anchor as the player nudges and MUST reposition on camera pan / zoom.

The HUD MUST NOT render on macOS; the Mac shell continues to commit placement on click and has no pending-placement state.

#### Scenario: PlacementHUD renders four arrow buttons positioned around the pending tile

- **WHEN** `GameSession.pendingPlacement` is non-nil on iOS
- **THEN** the `PlacementHUDViewModel.arrows` array contains exactly four entries — one each for `.ne`, `.se`, `.sw`, `.nw` (as `NudgeDirection`) — in stable order, and each has a distinct offset from the tile

#### Scenario: PlacementHUD checkmark button dispatches confirmPlacement

- **WHEN** the player taps the central checkmark on a visible PlacementHUD
- **THEN** the view model's confirm callback fires and `GameSession.pendingPlacement` is cleared on the next render

#### Scenario: PlacementHUD cancel button dispatches cancelPlacement

- **WHEN** the player taps the cancel button on a visible PlacementHUD
- **THEN** the view model's cancel callback fires and `GameSession.pendingPlacement` is cleared on the next render

#### Scenario: PlacementHUD arrow button dispatches the matching nudgePlacement direction

- **WHEN** the player taps the NE arrow on a visible PlacementHUD
- **THEN** the view model nudges the session along `.ne` and the pending anchor moves by `(dx: 0, dy: -1)` on the next render

### Requirement: Tile context menu on long-press

CityUI on iOS SHALL present a `TileContextMenu` whenever the controller receives a `.longPressTile(coord)` intent. The menu MUST list:

1. One Build entry per kind the build palette offers, in the palette's order: every `BuildingKind` except the town center, minus buildings the player's research made obsolete (hidden, exactly as in the palette). Entries whose `canPlace(_:at:)` would reject for research, terrain, occupancy, or insufficient materials, or that the player cannot afford, MUST appear disabled and MUST say why (a locked kind reads "Needs <tech> research"). The road entry appears whenever the palette offers it.
2. A Demolish entry, visible only when the tile holds a player-owned building, rendered with the destructive role.
3. A Cancel entry that dismisses the menu and keeps the inspector selection on the long-pressed tile.

A long-press MUST also select the tile for the inspector, and the inspector SHALL offer an Actions button that opens the same menu for the selected tile.

Selecting a non-road Build entry MUST enter pending-placement mode at the long-pressed tile via `GameSession.beginPendingPlacement(kind:at:)`. Selecting the road Build entry MUST arm the road place tool via `selectedTool = .place(.road)` WITHOUT entering pending-placement mode (roads paint via drag). Selecting Demolish MUST immediately enqueue `.demolish` at the long-pressed tile. Selecting Cancel MUST be a no-op beyond dismissing the menu.

The menu MUST NOT present on macOS; the Mac shell continues to use the palette + click model.

#### Scenario: Menu lists every placeable building kind as a separate entry

- **WHEN** `TileMenuViewModel(tile:, world:, money:)` is built for any tile
- **THEN** its items contain exactly one `.build(kind, enabled:, reason:)` entry per kind the palette shows (including `.road`)

#### Scenario: Road menu entry arms the place tool without entering pending state

- **WHEN** the menu's road `.build(.road)` choice is applied via `GameSession.applyMenuChoice(.build(.road), at: tile)`
- **THEN** `selectedTool == .place(.road)` and `pendingPlacement == nil`

#### Scenario: Unaffordable buildings appear disabled in the menu

- **WHEN** `TileMenuViewModel` is built for a tile where the player cannot afford a sawmill (e.g. insufficient money or insufficient island materials)
- **THEN** the `.build(.sawmill, enabled: false, reason:)` entry has `enabled == false` and a reason

#### Scenario: Locked buildings appear disabled with the research reason

- **WHEN** `TileMenuViewModel` is built for a world where the mine's tech is not researched
- **THEN** the mine entry is disabled and its reason reads "Needs <tech> research"

#### Scenario: Obsolete buildings are left out of the menu

- **WHEN** `TileMenuViewModel` is built for a world that researched the tech replacing the quern house
- **THEN** the items contain no quern house entry

#### Scenario: Demolish entry appears only when tile holds a player-owned building

- **WHEN** `TileMenuViewModel` is built for a tile holding a player-owned house
- **THEN** the items contain a `.demolish` entry

- **WHEN** `TileMenuViewModel` is built for an empty grass tile
- **THEN** the items do NOT contain a `.demolish` entry

#### Scenario: Menu emits dismiss for inspect entry

- **WHEN** the menu's cancel choice is applied via `GameSession.applyMenuChoice(.dismiss, at: tile)`
- **THEN** `pendingPlacement == nil` and `selectedTool` is unchanged

#### Scenario: Long-press intent opens the tile menu request on iOS

- **WHEN** the controller receives a `.longPressTile(coord)` intent on iOS
- **THEN** `GameSession.tileMenuRequest == TileMenuRequest(tile: coord)`

#### Scenario: Menu Build choice for a non-road kind enters pending placement

- **WHEN** the menu's `.build(.house)` choice is applied via `GameSession.applyMenuChoice(.build(.house), at: TileCoordinate(x: 3, y: 4))`
- **THEN** `pendingPlacement?.kind == .house` and `pendingPlacement?.anchor == TileCoordinate(x: 3, y: 4)`

#### Scenario: Menu Build choice for road arms the road place tool

- **WHEN** the menu's `.build(.road)` choice is applied via `GameSession.applyMenuChoice(.build(.road), at: TileCoordinate(x: 3, y: 4))`
- **THEN** `selectedTool == .place(.road)` and `pendingPlacement == nil` (the player paints by tapping / dragging tiles)

### Requirement: Tap is suppressed while a placement is pending

While `GameSession.pendingPlacement` is non-nil, the controller's `handleTap(at:)` SHALL be a no-op. World taps MUST NOT change the pending anchor, MUST NOT commit placement, and MUST NOT change `selectedTool`. The player MUST use the PlacementHUD's arrows / checkmark / cancel to drive the pending state. This prevents the common "tap to dismiss the menu then accidentally move the ghost" failure mode.

#### Scenario: handleTap is suppressed while a placement is pending

- **WHEN** `pendingPlacement?.anchor == (3, 4)` and the player taps tile `(7, 7)`
- **THEN** `pendingPlacement?.anchor` remains `(3, 4)`, no command is enqueued, and `selectedTool` is unchanged

#### Scenario: ghostState reads from pendingPlacement when set

- **WHEN** `pendingPlacement?.anchor == (3, 4)` and `pendingPlacement?.kind == .house`
- **THEN** `ghostState()` returns a `GhostPreview` with `tile == TileCoordinate(x: 3, y: 4)` and `kind == .house` regardless of `hoveredTile`

### Requirement: First-run coach mark for touch placement

CityUI on iOS SHALL show a one-time coach mark "Long-press a tile to build" on first launch. The coach mark MUST be dismissable and MUST NOT show again once dismissed. State persists via `UserDefaults` under a stable key. The coach mark MUST NOT show on macOS.

#### Scenario: First-run coach mark shows once and is dismissable

- **WHEN** the player launches the app on iOS for the first time with no stored coach-mark flag
- **THEN** the coach-mark overlay is presented and tapping its dismiss control sets the stored flag to `true`

#### Scenario: Coach mark does not show after dismissal flag is set

- **WHEN** the player launches the app on iOS with the stored coach-mark flag set to `true`
- **THEN** the coach-mark overlay is not presented

### Requirement: Palette-armed buildings route through pending placement on iOS

On iOS, when the player taps a world tile with a build tool armed via the `BuildPaletteView`, the tap SHALL enter pending-placement mode for that building kind at the tapped tile (matching the long-press → menu → pick flow), EXCEPT when the armed tool is `.place(.road)` or `.demolish`. Road and demolish MUST continue to commit immediately on tap / drag (paint behavior). A drag with a non-road building armed MUST NOT paint buildings, and a drag pans the camera in that case. On macOS, palette-armed taps MUST commit immediately on click for every kind, including non-road buildings.

The rule is the session flag `GameSession.confirmsBuildingPlacement`, on by default on iOS and off on macOS, so both behaviours are testable on either platform.

#### Scenario: Palette-armed building tap enters pending placement on iOS

- **WHEN** `selectedTool == .place(.house)` on iOS and the player taps tile `(3, 4)`
- **THEN** `pendingPlacement?.kind == .house` and `pendingPlacement?.anchor == TileCoordinate(x: 3, y: 4)` and no `.place` command is yet enqueued

#### Scenario: Palette-armed building drag does not paint on iOS

- **WHEN** `selectedTool == .place(.house)` on iOS and the player drags across tile `(3, 4)`
- **THEN** no `.place` command is enqueued

#### Scenario: Camera pans unless a tool paints tile by tile

- **WHEN** the armed tool is inspect, or a non-road building on iOS
- **THEN** a one-finger drag pans the camera
- **WHEN** the armed tool is road or demolish, or any place tool on macOS
- **THEN** the pan gesture is masked off so drag-to-paint reaches the scene

#### Scenario: Palette-armed building tap commits on click on macOS

- **WHEN** `selectedTool == .place(.house)` on macOS and the player clicks tile `(3, 4)`
- **THEN** a `.place(.house, at: TileCoordinate(x: 3, y: 4))` command is enqueued and `pendingPlacement == nil`

#### Scenario: Palette-armed road tap or drag paints immediately on iOS

- **WHEN** `selectedTool == .place(.road)` on iOS and the player taps tile `(3, 4)`
- **THEN** a `.place(.road, at: TileCoordinate(x: 3, y: 4))` command is enqueued and `pendingPlacement == nil`

### Requirement: Night falls on the scene

The scene SHALL darken by the time of day's darkness, and inhabited houses SHALL show lit windows whose brightness follows the darkness.

#### Scenario: Night overlay

- **WHEN** the scene renders a snapshot at tick 780
- **THEN** its night overlay has alpha 0.55

### Requirement: Residents stroll the streets

During day and dusk, each inhabited house with an adjacent road SHALL show up to three strollers (one per three residents) walking the nearby roads, and none at night. Stroller positions SHALL be a pure function of house, slot and tick.

#### Scenario: Strollers by day

- **WHEN** a house with 9 residents next to a road is planned at midday
- **THEN** there are 3 strollers for it

#### Scenario: No strollers at night

- **WHEN** the same house is planned at midnight
- **THEN** there are no strollers for it

### Requirement: Signature range rings

While a signature building kind is being placed or a placed one is selected, the scene SHALL outline the tiles within its range and highlight the buildings it affects: 8 tiles for the guild hall and gallery, 6 tiles (speed) and 4 tiles (smoke) for the steam engine, and 10 tiles for the power plant. The monument SHALL have no ring.

#### Scenario: Guild hall ring

- **WHEN** the player starts placing a guild hall
- **THEN** the scene shows a ring 8 tiles around the ghost footprint and highlights the workshops inside it

### Requirement: Signature sprites follow their state

An unfinished operational monument SHALL show construction frame 0 for stages 0–8, frame 1 for stages 9–16 and frame 2 for stages 17–24, and its operational animation once complete. Steam engines and power plants SHALL animate only while fuelled, and galleries only while a commission runs; otherwise they SHALL show their idle sprite. Smoky houses SHALL be tinted grey.

#### Scenario: Half-built monument

- **WHEN** a snapshot holds an operational monument at stage 12
- **THEN** its sprite is `building-monument-constructing-1`

#### Scenario: Cold engine is idle

- **WHEN** a snapshot holds an operational, unfuelled steam engine
- **THEN** its sprite is `building-steam-engine` and it does not animate

### Requirement: Culture signature rings and animation

Placing or selecting a mead hall or forum SHALL show an 8-tile range ring, and a temple garden a 6-tile ring, highlighting the buildings it affects; the caravanserai SHALL show none. The four culture signature buildings SHALL animate only while served and otherwise show their idle sprite.

#### Scenario: Temple ring

- **WHEN** the player starts placing a temple garden
- **THEN** the scene shows a ring 6 tiles around the ghost footprint and highlights the houses at citizens or above inside it

#### Scenario: Unserved forum is idle

- **WHEN** a snapshot holds an operational, unserved forum
- **THEN** its sprite is `building-forum` and it does not animate

### Requirement: Buildings render in their owner's culture

Culture variant and age look lookups for a building SHALL use its owner's culture and age: the world's culture and age for player buildings, the rival's for rival buildings. Residents walking on a rival island SHALL take names from the rival's culture.

#### Scenario: Rival town center in its own culture

- **WHEN** the scene draws rival 2's operational town center in a Northern European world where rival 2 is East Asian
- **THEN** the node's texture name is "building-town-center-east-asian"

#### Scenario: Player buildings unchanged

- **WHEN** the scene draws the player's operational town center in the same world
- **THEN** the node uses the shared town center sprite

### Requirement: Rival buildings fly a pennant

Every rival building other than a road, operational or under construction, SHALL carry a pennant child node in its rival's colour, drawn from a texture generated in code (a 1×6 px pole and a 5×3 px triangle), placed at the top-left of the building sprite and above it in z-order. Player buildings SHALL carry no pennant.

#### Scenario: Pennant on a rival house

- **WHEN** the scene draws a house owned by rival 1
- **THEN** the house node has a pennant child in crimson (#B03A2E)

#### Scenario: No pennant on roads or player buildings

- **WHEN** the scene draws a rival road and a player house
- **THEN** neither node has a pennant child

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

### Requirement: Ground macro field

The renderer SHALL draw one map-sized ground macro field over the ground tiles and under every object and building, blended `multiplyX2`, where 0.5 grey leaves the ground unchanged. The field SHALL interpolate a colour per map vertex smoothly between vertices, with at least 4 texels per tile across. The vertex colour SHALL come from:

- world-space noise that varies grass between lush and dry over several tiles and mottles it below tile size;
- a darker floor under forest;
- worn ground next to occupied tiles;
- wet sand on beach vertices next to water;
- water that is brighter next to land and darker with distance from it;
- the season.

The field SHALL be a pure function of the terrain grid, the occupied tiles and the season. The renderer SHALL rebuild it when one of them changes, and at no other time. Outside the map the field SHALL be neutral.

#### Scenario: Neighbouring grass tiles differ smoothly

- **WHEN** the macro field is built for a map of grass
- **THEN** the field colour differs between vertices several tiles apart, and no two adjacent texels differ by more than a small step

#### Scenario: Deep water is darker than shallow water

- **WHEN** the macro field is built for an island in open water
- **THEN** a water vertex next to the beach is lighter than a water vertex five tiles out

#### Scenario: Forest floor is darker than meadow

- **WHEN** the macro field is built for a map with a forest in a meadow
- **THEN** a vertex inside the forest is darker than a meadow vertex nearby

#### Scenario: Building a house wears the ground

- **WHEN** a building is placed on grass
- **THEN** the next macro field is browner at the vertices next to its footprint, and unchanged two tiles away

#### Scenario: The macro field is rebuilt only on change

- **WHEN** the scene renders frames whose terrain, occupancy and season are unchanged
- **THEN** it does not rebuild the macro field

#### Scenario: The macro field follows the season

- **WHEN** the season turns from spring to winter
- **THEN** the scene rebuilds the macro field with the winter palette

### Requirement: Grass picks a variant per tile

A full grass tile SHALL draw one of the grass variants for its season (`terrain-grass[-<season>]-v<n>`, variant 0 as the plain name), chosen by `SpriteAtlas.variantIndex` from its coordinate. Transition tiles are unchanged.

#### Scenario: Grass variants are stable per tile

- **WHEN** the same grass tile is drawn in two frames
- **THEN** it draws the same variant both times, and some of its neighbours draw other variants

### Requirement: Terrain objects on forest and mountain tiles

A forest tile SHALL draw a tree clump (`terrain-forest-<density>`), and a mountain tile a rock outcrop (`terrain-mountain-<density>`), over its ground. The variant comes from `SpriteAtlas.variantIndex`. The tile's ground SHALL be drawn as grass (or a grass transition), so forest and mountain show no tile edge of their own.

The density SHALL follow the tile's distance to the edge of its forest or rock region, counted over edge neighbours:

- distance 1: `sparse` (a forest tile may take `medium` by hash);
- distance 2: `medium`;
- distance 3 or more: `dense`. Inside a rock region, smooth world noise opens some tiles to `medium` and raises others, 4 or more from the edge, to `peak`.

A tile next to an occupied tile SHALL drop one class. An occupied tile SHALL draw no object, and an occupied forest tile SHALL still draw grass ground. A forest region reaching the map's border SHALL count the border as its edge. When a building is placed or cleared, or a tile is felled or planted, the scene SHALL redraw the objects it changes.

Objects are visual only. Simulation and placement MUST keep using each tile's own terrain.

#### Scenario: Forest edges are thinner than forest interiors

- **WHEN** the scene renders a 7 × 7 forest
- **THEN** its edge tiles draw `sparse` or `medium` clumps, and its centre tile draws a `dense` clump

#### Scenario: Trees never stand on a building

- **WHEN** a road is built on a forest tile
- **THEN** that tile draws no tree clump, and its forest neighbours drop one density class

#### Scenario: Rock thins toward the edge

- **WHEN** the scene renders a large mountain region
- **THEN** its edge tiles draw `sparse` outcrops, and its interior tiles draw `medium`, `dense` or `peak` outcrops, never `sparse`

#### Scenario: A forest reaching the map border

- **WHEN** a map is all forest
- **THEN** its corner tiles draw `sparse` or `medium` clumps and a tile 3 from every border draws a `dense` one

#### Scenario: A building placed in a live forest clears its clump and thins its neighbours

- **WHEN** a house is placed on a forest the scene already shows
- **THEN** the tiles under it draw grass ground and no clump, and the forest tiles next to it drop to `sparse`

#### Scenario: Felling and planting reach the scene

- **WHEN** a forest tile turns to grass, and later a grass tile beside the forest turns to forest
- **THEN** the first loses its clump and the second gains one

#### Scenario: Forest ground has no tile edge

- **WHEN** a forest tile borders a grass tile
- **THEN** both tiles draw grass ground

### Requirement: Terrain objects depth-sort with buildings

A terrain object SHALL draw just behind the global z of a 1 × 1 building on its tile, `10 + (c + r + 1) × 0.01 − 0.0002 + (c mod 3) × 0.00005`. Objects nearer the camera then cover buildings behind them, buildings nearer the camera cover objects behind them, and a building at the same depth always covers the object. Objects at one depth that overlap are at most two columns apart; they keep a fixed order by column, so they never swap when the scene rebuilds.

#### Scenario: A clump in front of a house covers it

- **WHEN** a forest tile lies in front of a house (greater c + r than the house's footprint centre)
- **THEN** the tree clump's global z is greater than the house's

#### Scenario: A clump behind a house stays behind it

- **WHEN** a forest tile lies behind a house
- **THEN** the tree clump's global z is less than the house's

#### Scenario: A clump level with a building sorts behind it in every season

- **WHEN** a forest tile has the same depth as a house's footprint centre
- **THEN** the tree clump's global z is less than the house's in every season

#### Scenario: Rock and trees level with a building keep one order in every season

- **WHEN** a mountain tile and a forest tile have the same depth as a house's footprint centre
- **THEN** in every season both objects draw behind the house, and they keep one order between them

### Requirement: Terrain objects follow the season

Tree clumps SHALL use their `-autumn` and `-winter` sprites in those seasons. Rock outcrops SHALL use their `-winter` sprites in winter. Both SHALL use the plain sprites otherwise, and fall back to the plain sprite when a seasonal one is missing. A season change SHALL redraw every visible object.

#### Scenario: Forests turn in autumn

- **WHEN** the season turns from summer to autumn
- **THEN** every visible tree clump redraws with its `-autumn` sprite

#### Scenario: Rock keeps its look in autumn

- **WHEN** the season is autumn
- **THEN** rock outcrops draw their plain sprites

### Requirement: Scree under rock

The renderer SHALL draw one map-sized scree cover between the ground tiles and the macro field, alpha-blended. Its opacity SHALL follow the share of mountain tiles round each vertex, so it fades out across the edge of a rock region. It SHALL be rebuilt with the macro field.

#### Scenario: Scree fades at the edge of rock

- **WHEN** the cover is built for a mountain region in a meadow
- **THEN** it is opaque in the region's interior, transparent two tiles outside it, and in between at its edge

### Requirement: Areas of effect while placing and selecting

While a building with a catchment radius is the ghost and could be placed there, or is selected with the inspect tool (a rival's building included), the scene SHALL show its area of effect: the outline of every tile within its catchment, drawn in gold over a dark under-stroke with a faint gold tint, on the ground below trees and buildings. The tiles it would work SHALL be highlighted: a tree in reach SHALL brighten on its own node, and open grass a forester would plant SHALL take a stronger gold tint. While a building with a terrain requirement is the ghost, the scene SHALL outline and tint every tile of each valid site within 6 tiles of the cursor and brighten the required terrain's objects there. A red ghost of a building with a catchment, and an anchor off the map, SHALL show no area. The overlay SHALL use a fixed number of nodes whatever the area's size, and SHALL vanish, restoring every brightened tree and rock, when the ghost and the selection go.

#### Scenario: Placing a hut outlines its catchment and brightens its trees
- **WHEN** a lumberjack hut ghost stands at an anchor with 18 unoccupied forest tiles within 2 tiles of its plot
- **THEN** the scene outlines the 6 by 6 tiles around the plot and brightens exactly those 18 trees' nodes

#### Scenario: A forester's open grass is tinted
- **WHEN** a forester ghost stands where its catchment holds 12 open grass tiles
- **THEN** the target fill covers exactly those 12 tiles

#### Scenario: Placing a mine shows the valid sites nearby
- **WHEN** the mine is armed and the cursor is within 6 tiles of rock where a mine may stand
- **THEN** the scene outlines every tile of each valid mine plot whose anchor is within 6 tiles of the cursor, and brightens the rock on those tiles

#### Scenario: A red ghost shows no catchment
- **WHEN** a lumberjack hut ghost stands on the town center
- **THEN** the scene shows no area of effect

#### Scenario: A selected hut shows its catchment
- **WHEN** the player selects a lumberjack hut with the inspect tool
- **THEN** the scene outlines its catchment and brightens the trees in reach

#### Scenario: The overlay keeps its node count
- **WHEN** the area of effect shows for a hut and then for a mine with dozens of valid sites
- **THEN** the overlay layer holds no more than three nodes both times

#### Scenario: Trees return to normal
- **WHEN** the player disarms the hut tool
- **THEN** the overlay is gone and no tree keeps its brightening

### Requirement: Buildings show a status icon while something is wrong

The renderer SHALL float one status icon over the roof of every player building that is not doing its job, and SHALL show none over a building that is fine. The icon is chosen in this order:

1. The building's `BuildingIssue`, mapped as follows:
   - `.missingInputs(goods)` → the first good's "short" icon.
   - `.outputStuck(good)` → that good's "stuck" icon (`per-good-storage`).
   - `.noRoad`, `.noRouteToStorage`, `.noTreesInReach` and `.noRoomToPlant` → their pictograms.
2. Otherwise, for a house, the "short" icon of the first good in its `shortGoods`, in `Good` order.
3. Otherwise, if the building is in `roadDisconnectedBuildings`, the no-road pictogram.

A "short" icon is the good on a cream disc with a red "!" pip. A "stuck" icon is the good with an amber pause pip. Pictograms are white on a red disc.

The icon SHALL be one sprite node, a child of the building's sprite, centred over the sprite's top. Its size at zoom 1 SHALL be 22 pt on iOS, 20 pt on macOS and 30 pt on tvOS. Its on-screen size SHALL follow clamp(zoom, 0.75, 1.25). It SHALL draw above the night overlay. It SHALL bob 2 pt (times its zoom scale) over 1.8 s with a phase that depends on the building's id, and SHALL be still while Reduce Motion is on.

#### Scenario: Missing input shows the good
- **WHEN** a player bakery's issue is `.missingInputs([.flour])`
- **THEN** its sprite has one status-icon child textured `status-flour-short`

#### Scenario: A house short of a need shows the good
- **WHEN** a player house has no issue and its `shortGoods` is `[.beer, .bread]`
- **THEN** its status icon is `status-bread-short`

#### Scenario: A working building shows no icon
- **WHEN** a player sawmill has no issue and has a road
- **THEN** its sprite has no status-icon child

#### Scenario: The icon goes when the issue is fixed
- **WHEN** the bakery's flour arrives and its issue clears
- **THEN** on the next reconcile its sprite has no status-icon child

#### Scenario: Reduce Motion stills the icon
- **WHEN** Reduce Motion is on and a building gets a status icon
- **THEN** the icon runs no bob action

#### Scenario: Icon keeps three quarters of its size at zoom 0.5
- **WHEN** the camera zoom is 0.5 on macOS
- **THEN** the icon's on-screen size is 15 pt

#### Scenario: Tapping the icon selects the building
- **WHEN** the Inspect tool is armed and the player taps inside a building's status icon
- **THEN** the scene dispatches `tapTile` for that building's anchor tile

#### Scenario: Other tools tap through the icon
- **WHEN** Demolish or a place tool is armed and the player taps inside a building's status icon
- **THEN** the scene dispatches `tapTile` for the tile under the tap, not the building's anchor

#### Scenario: The nearest icon takes an overlapping tap
- **WHEN** the hit areas of two status icons both cover the tap
- **THEN** the tap selects the building whose icon centre is nearer

### Requirement: Carriers glide and show their load

When a carrier's tile changes, its node SHALL move to the new tile's position over the time since its previous step, clamped to 0.03–0.25 s, instead of jumping. A carrier's frames SHALL come from `carrier-<family>-<facing>-<frame>` for its load's family: logs for wood and planks, barrel for beer and wine, sack for food, grain, flour, bread, hops, grapes, tea leaves, coffee cherries, tea and coffee, and crate for ore, charcoal, iron, tools and any good a pack adds later. When those sprites are missing, they SHALL fall back to the walker frames for the same facing. A carrier SHALL draw just above the road it walks on in depth order, so buildings nearer the camera cover it.

#### Scenario: Carrier glides between tiles
- **WHEN** a carrier steps from one tile to the next between two frames
- **THEN** its node runs a move to the new tile's position instead of jumping there

#### Scenario: Load family from the good
- **WHEN** carriers deliver planks, beer, flour and tools
- **THEN** their load families are logs, barrel, sack and crate

#### Scenario: Carrier sprite falls back to the walker
- **WHEN** the atlas has no `carrier-sack-se-0`
- **THEN** a carrier with a sack facing south-east uses the walker's south-east frames

### Requirement: Chimneys smoke

The scene SHALL show smoke rising from the chimney of every operational house with residents, and of every operational player bakery, smelter, toolsmith and charcoal burner that has no building issue. An operational player brewery with no issue SHALL show steam. Rival workshops SHALL stay cold, because building issues are known only for the player's buildings. Empty houses and buildings with an issue SHALL show neither. Which buildings smoke SHALL be a pure function of the snapshot, and smoke SHALL never change simulation state.

#### Scenario: Inhabited house smokes
- **WHEN** a snapshot holds an operational house with 4 residents and an operational house with none
- **THEN** only the first house has a smoke source

#### Scenario: Idle workshop is cold
- **WHEN** a snapshot holds two operational bakeries, one with missing flour
- **THEN** only the bakery without an issue has a smoke source

#### Scenario: Brewery steams
- **WHEN** a snapshot holds an operational brewery with no issue
- **THEN** its source has the steam style

### Requirement: Ambient effects stay in budget

The scene SHALL draw ambient effects only for buildings in the visible tile range, and SHALL show at most `clamp(Int(24 × zoom), 8, 40)` smoke emitters. Working buildings come first, then those nearest the camera centre. Emitters SHALL be pooled and reused. With Reduce Motion on, ambient emitters SHALL emit at half the birth rate and half the speed.

#### Scenario: Smoke budget follows zoom
- **WHEN** 60 inhabited houses and 2 working bakeries are visible at zoom 0.5
- **THEN** the scene shows 12 smoke emitters, and both bakeries are among them

#### Scenario: Reduce Motion slows smoke
- **WHEN** Reduce Motion is on
- **THEN** a house's smoke emitter has half the birth rate and half the speed it has with Reduce Motion off

### Requirement: Fish jump near the coast

By day, every 8–15 s of scene time, one fish SHALL jump from a visible open-water tile (water on all eight sides) within 4 tiles of land, picked by a seeded generator. It SHALL make a short arc with a three-frame fish drawn in code, and a splash ring SHALL spread where it dives back in. Only one jump SHALL show at a time, at most 3 nodes. The fish SHALL be nodes of their own above the water and SHALL sort by the depth of the tile they jump from. No new jump SHALL start at night or while the game is paused, and a jump under way SHALL hold still. There SHALL be no fish with Reduce Motion on or below zoom 0.5.

#### Scenario: A fish jumps near the coast
- **WHEN** open water lies within 4 tiles of the land in view, by day
- **THEN** within 15 s a fish jumps from an open-water tile within 4 tiles of land, in at most 3 nodes, and the next jump comes 8–15 s later

#### Scenario: No fish
- **WHEN** it is night, the zoom is below 0.5, or Reduce Motion is on
- **THEN** no fish jumps

### Requirement: Sawdust puffs at the sawmills

Each working player sawmill in view (operational, with no building issue) SHALL show pale sawdust puffs below the saw, at the middle of its +x edge, from one emitter per mill that reuses the smoke puff texture. At most 8 mills SHALL show sawdust, by id. An emitter SHALL go back to a pool when its mill stops working or leaves the view, and come from the pool when one is needed. The puffs SHALL hold still at night and while the game is paused. There SHALL be no sawdust with Reduce Motion on or below zoom 0.5.

#### Scenario: Sawdust puffs at a working sawmill
- **WHEN** a working sawmill is in view by day
- **THEN** sawdust puffs at its front, and stops when the mill has a building issue

#### Scenario: Sawdust rests
- **WHEN** it is night or the game is paused
- **THEN** the puffs hold still, and with Reduce Motion or below zoom 0.5 there is no sawdust

### Requirement: Workers walk out from the gather sites

Each operational player lumberjack hut or mine with no building issue SHALL show one worker. The worker SHALL:
- walk from a tile beside the site, one 4-connected step at a time over free grass, road and the site's own terrain, to a forest tile (hut) or mountain tile (mine) at the edge of the woods or rock, next to free grass or road, within `World.lumberjackCatchmentRadius` of the site's footprint, picked by a hash of the site among those it can reach;
- work there among the trees or rock;
- walk back by the same tiles, drawn with the carrier frames for logs (hut) or a crate (mine);
- rest at the site.

A site with an issue, or with no tree or rock it can reach, SHALL show no worker. A worker SHALL finish the trip it is on: the scene SHALL keep each site's trip (its tiles and the day-clock tick it began) and plan a new one only when the worker is back at its rest point, leaving from the same tile. If a tile on the trip stops being walkable, the worker SHALL turn for home from where it stands, along the tiles it has walked. A tree felled or planted in the catchment SHALL never make a worker jump. While it glides between tiles, a worker SHALL sort by the further back of its two ends. Each game SHALL get its own map view, so the workers of another game never carry over. Workers keep working in winter, as the sim does. Workers SHALL stand still at night, while the game is paused, and with Reduce Motion on. They SHALL sort by the depth of their feet. At most 16 workers SHALL be drawn, sites on screen first, then by id; none below zoom 0.5, and none outside the visible tiles plus the sprites' screen margin.

#### Scenario: A woodcutter walks out and back
- **WHEN** a working lumberjack hut stands two tiles from a forest at midday
- **THEN** over one round trip its worker stands only on free grass, road or forest, never in the hut, works in the forest, and walks back carrying logs

#### Scenario: An idle site stays empty
- **WHEN** a lumberjack hut has no trees in reach, or a mine lacks a road
- **THEN** it shows no worker

#### Scenario: A miner carries a crate
- **WHEN** a working mine is planned on its way back
- **THEN** its worker carries a crate

#### Scenario: No jump when the woods change
- **WHEN** trees are felled and planted in a hut's catchment between ticks, by day, at night and with Reduce Motion on
- **THEN** its worker never moves more than one tile from one tick to the next

### Requirement: Animals graze by the farms

Each operational farm SHALL keep 2–4 sheep and each operational grain farm 1–2 cows. The count SHALL come from a hash of the building. The animals SHALL stand on free grass within 2 tiles of the farm's footprint. A free grass tile has grass terrain, no building and no terrain object (tree or rock). Each animal SHALL graze at its spot and, every 6–10 s, walk to a 4-connected neighbouring free tile, so every tile a walk passes over is free grass. Animals SHALL move by a day clock that stops at night: at dusk each animal SHALL keep the place it reached and stop animating, and at dawn it SHALL carry on from there. In winter there SHALL be no animals, because the herds and hens are kept inside. Positions SHALL come from the farm, slot and day clock, and from the round the scene keeps (see "Animals keep their round when the pasture changes"), and SHALL never change simulation state. At most 30 herd animals SHALL be drawn, the budget going to the farms nearest the camera centre first, none below zoom 0.5, and none outside the visible tile range. With Reduce Motion on, animals SHALL stand still where they were when it came on. While the game is paused they SHALL stop animating. The visible range SHALL use the same screen margin as the scene's sprites. Animals SHALL sort by the depth of their feet (`figureZ(at:)`), like the other figures, so a building nearer the camera covers them.

#### Scenario: Sheep graze beside a farm
- **WHEN** an operational farm stands in open grass at midday
- **THEN** 2 to 4 sheep stand on grass tiles within 2 tiles of it, none on the farm itself

#### Scenario: No animals inside a tree clump
- **WHEN** every grass tile around a farm carries a terrain object
- **THEN** the farm has no animals

#### Scenario: Animals hold still at night
- **WHEN** the same farm is planned at two ticks a minute apart at night
- **THEN** each animal stands in the same place and is not walking

#### Scenario: Panning to a farm gives it animals
- **WHEN** more farms are in view than the herd budget covers, and the camera centres on one of them
- **THEN** eligible farms get animals in order of distance from the camera centre until the budget is full: the farm under the camera has its animals, and no farm has animals while a nearer one has none

### Requirement: Hens peck by the houses

Each inhabited peasant house SHALL keep 1–2 hens, by a hash of the house, in its yard: the half of an open tile (free grass or road) next to its +x or +y edge. Hens SHALL never stand on the house's own plot, whose log piles, barrels and garden beds are part of the house sprite. A house with no open tile in front SHALL keep no hens. A hen SHALL hop to a new spot every 3–5 s. By night there SHALL be no hens. At most 24 hens SHALL be drawn, the houses nearest the camera centre first, and none below zoom 0.75.

#### Scenario: Hens peck by an inhabited house
- **WHEN** a peasant house with residents is planned at midday at zoom 1
- **THEN** 1 or 2 hens stand on the open tiles just in front of it, none on its plot

#### Scenario: Animals stay in budget
- **WHEN** 40 farms in open grass are visible at midday
- **THEN** at most 30 herd animals are planned

#### Scenario: No jump at dusk or dawn
- **WHEN** a farm's animals are planned on the ticks either side of dusk, and again either side of dawn
- **THEN** no animal moves further than one tile between the two ticks

#### Scenario: Walks stay on free grass
- **WHEN** a farm's pasture is broken up by trees and a house
- **THEN** at every tick each animal stands on a free grass tile

#### Scenario: No animals in winter
- **WHEN** a farm and an inhabited house are planned at midday in winter
- **THEN** there are no animals

### Requirement: Trees sway in the wind

Every tree clump object SHALL rock about its anchor (the trunk base on its tile), by at most 0.7°, on a shared repeating action. Its start SHALL be offset by a phase from a hash of its tile. Rock objects SHALL NOT sway. The sway SHALL be armed when the clump's node is made, with no per-frame work per clump.

Below zoom 0.5, or with Reduce Motion on, clumps SHALL stand upright and still. While the game is paused, they SHALL hold their current lean. The scene SHALL update the clumps on screen only when this state changes, and clumps made afterwards SHALL start in the current state.

#### Scenario: A tree clump sways
- **WHEN** the scene makes the node for a forest tile with a clump at zoom 1
- **THEN** the clump runs the sway action, and its lean never exceeds 0.7°

#### Scenario: Rock stays still
- **WHEN** the scene makes the node for a mountain tile with an outcrop
- **THEN** the outcrop runs no sway

#### Scenario: Sway stops far out and with Reduce Motion
- **WHEN** the camera zooms out below 0.5, or Reduce Motion comes on
- **THEN** every clump on screen stands upright with its sway stopped, and a clump made afterwards starts stopped

### Requirement: Animals keep their round when the pasture changes

The scene SHALL keep each animal's round (its tiles, in walking order) from tick to tick, and SHALL keep it while every tile on it is still open: free grass for a herd animal, free grass or road for a hen. When a tile on the round closes, the animal SHALL plan a new round through the open tiles, starting at the tile it was heading for, or at the nearest open tile when that one has closed, and SHALL walk there from the spot where it stands. A building or road placed on the pasture or yard SHALL never make an animal jump. A round no longer drawn (its home off screen or over budget) SHALL be forgotten; the next time the animal is drawn, its round starts afresh from the farm, slot and day clock. Each game SHALL get its own map view, so the animals and workers of another game never carry over.

#### Scenario: No jump when the pasture is built on
- **WHEN** a road tile is laid on a farm's pasture every few ticks, with the farm's sheep in view
- **THEN** no sheep moves more than one tile between two ticks, and a sheep that stands still stands on free grass

### Requirement: Port and shipyard animate while operational

An operational port SHALL loop its facing's six operational frames, `building-port-<o>-operational-0` to `-5`, at 0.45 s each. The loop SHALL show its crane lifting a crate off the wharf, swinging it onto the quay, setting it down and swinging back out.

An operational shipyard SHALL loop its facing's five operational frames, `building-shipyard-<o>-operational-0` to `-4`:
- frames 0–2, keel and ribs, then two and four strakes, SHALL show for 2.5 s each;
- frame 3, the finished hull with six strakes, SHALL show for 4 s;
- frame 4, the empty slipway after its launch, SHALL show for 1.25 s.

An operational entry MAY give each frame its own duration. When it does, it SHALL give exactly one positive duration per frame.

#### Scenario: Cargo comes ashore at an operational port

- **WHEN** the renderer draws an operational port facing east
- **THEN** it loops `building-port-e-operational-0` to `-5`, at 0.45 s each, 2.7 s per pass

#### Scenario: The shipyard planks a hull and launches it

- **WHEN** the renderer draws an operational shipyard facing north
- **THEN** it loops `building-shipyard-n-operational-0` to `-4`
- **AND** the finished hull, frame 3, shows the longest
- **AND** the empty slipway, frame 4, shows the shortest
- **AND** one pass lasts 12.75 s

### Requirement: Building animations follow pause and Reduce Motion

The renderer SHALL keep one state for every building animation on screen: running, held or stopped.
- With Reduce Motion on, the state SHALL be stopped, and each animated building SHALL show its operational frame 0, culture looks included.
- Otherwise, while the game is paused (no new tick for 0.3 s), the state SHALL be held: each building animation SHALL keep its current frame.
- Otherwise the state SHALL be running.

A building drawn while the state is held or stopped SHALL start in that state. A change of state SHALL slow only each building's own animation; badges, glows and pennants on the building SHALL keep their motion. The renderer SHALL touch building nodes only on frames where the state changes.

#### Scenario: Reduce Motion rests a building on its first frame

- **WHEN** Reduce Motion turns on while a windmill's sails are mid-turn
- **THEN** its animation stops and the windmill shows its operational frame 0
- **AND** the sails turn again once Reduce Motion is off and the game ticks

#### Scenario: Pausing holds a building's animation

- **WHEN** no tick arrives for more than 0.3 s
- **THEN** each building animation stops on its current frame
- **AND** it runs again with the next tick

### Requirement: Birds follow pause and Reduce Motion

Birds SHALL follow the same motion state as building animations:
- while running, flocks cross and gulls wheel;
- while held, every bird SHALL hang where it is, no new flock SHALL set out, and the wait for the next flock SHALL resume where it stopped;
- while stopped, the map SHALL show no birds.

#### Scenario: Pausing holds the birds

- **WHEN** the game is paused while a flock crosses
- **THEN** the flock and the gulls stop where they are, and the next flock's wait pauses with them
- **AND** they move on when the game ticks again

### Requirement: Plain ground is one backdrop

A tile whose ground is plain grass, beach or water, with no transition, SHALL have no ground sprite of its own. Forest and mountain tiles count as grass. One `SKSpriteNode` under the ground sprites, spanning the screen and clamped to the map, SHALL draw every such tile:
- a shader finds the tile under each pixel;
- it draws that tile's look (its grass variant, beach or water, in the current season) with its animation frames;
- each tile runs on its own phase, from its tile hash;
- every other tile, and the space outside the map, stays transparent.

The backdrop SHALL look the same as a sprite per tile, in every season and at night, under every overlay. Transition sprites, buildings and figures SHALL stay ordinary nodes. A tree or rock object over plain ground SHALL stand alone at the same z and column slot it has over a ground sprite. A terrain change SHALL update which tiles the backdrop draws, and a season change SHALL update its looks.

#### Scenario: Plain ground is one node

- **WHEN** the scene shows grass, beach and sea with no transitions between them
- **THEN** those tiles have no sprite, the backdrop draws them, and the scene holds one backdrop node

#### Scenario: Transition tiles keep their sprites

- **WHEN** a tile has a transition
- **THEN** it keeps its transition sprite and the backdrop leaves it transparent

#### Scenario: Plain ground follows the terrain

- **WHEN** a water tile turns to land
- **THEN** the backdrop draws it as grass, and the water round it, which now has shore transitions, gets sprites

#### Scenario: Trees and rocks keep their place over the backdrop

- **WHEN** a forest tile's ground is plain
- **THEN** its tree clump stands alone at the tile, with the z it has over a ground sprite

#### Scenario: Each tile animates on its own phase

- **WHEN** the backdrop's tiles are laid out
- **THEN** their animation phases come from their tile hashes and spread across the frames

#### Scenario: The ground backdrop follows the season

- **WHEN** the season turns from summer to winter
- **THEN** the backdrop draws the winter looks

### Requirement: The ground backdrop follows pause and Reduce Motion

The ground backdrop's animation SHALL follow the same motion state as building animations (see "Building animations follow pause and Reduce Motion"):
- while running, its clock advances;
- while held, its clock stops, so every tile keeps its frame, and it runs on from there with the next tick;
- while stopped, every tile shows its look's frame 0.

#### Scenario: Pausing holds the ground's animation

- **WHEN** no tick arrives for more than 0.3 s
- **THEN** the backdrop's clock stops, so every plain tile keeps its frame
- **AND** it runs on from there with the next tick

#### Scenario: Reduce Motion rests the ground on its first frame

- **WHEN** Reduce Motion is on
- **THEN** every plain tile shows its look's frame 0

### Requirement: Camera stays near the map

After every pan, the camera centre SHALL stay within `GameSession.cameraMapMargin` (8) tiles of the map on every axis. On Apple TV it SHALL stay on the map itself. A view that lies wholly off the map SHALL cull to no tiles and draw no terrain or building sprites, without failing.

#### Scenario: Panning far off the map stops at the margin

- **WHEN** the player pans 100,000 points past any of the four edges of a 24 × 24 map
- **THEN** the camera centre stops 8 tiles past the map on the axis it left by, and no further

#### Scenario: A view off the map draws nothing

- **WHEN** the camera stands 500 tiles past any edge or corner of the map
- **THEN** culling returns no tile range and the scene places no sprite

### Requirement: Sprites reconcile only on change

The renderer SHALL keep what its terrain and building sprites were drawn from: the tiles on screen, the terrain grid and occupancy, and the buildings with their road access, house populations, house modifiers and rivals. A frame where none of these changed SHALL add, remove and rebuild no sprite and SHALL NOT build the desired sprite set again. When only the camera moves, the renderer SHALL add and remove only the tiles that entered or left the view. When occupancy changes, it SHALL redraw only the tiles whose terrain object changed. After any sequence of frames, the sprites in the scene SHALL be the ones a full rebuild of the latest frame would place.

#### Scenario: An unchanged frame reconciles nothing

- **WHEN** the scene draws five more frames of the same snapshot
- **THEN** it runs no terrain pass and no building pass, and adds and removes no tile

#### Scenario: A pan redraws only the edges

- **WHEN** the camera moves one tile at zoom 0.5
- **THEN** the tiles added and removed are fewer than a fifth of the tiles on screen, and the sprites match a full rebuild

#### Scenario: A new building redraws only the tiles round it

- **WHEN** a house is placed beside a forest
- **THEN** one building pass runs, fewer than 20 tiles are redrawn, and the sprites match a full rebuild

#### Scenario: Incremental frames match a full rebuild

- **WHEN** the camera pans and zooms, a forest tile turns to grass and a house moves, one frame after another
- **THEN** after each frame the scene's sprites are the ones a fresh scene would place for that frame
