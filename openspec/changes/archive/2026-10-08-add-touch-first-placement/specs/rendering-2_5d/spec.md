## ADDED Requirements

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
