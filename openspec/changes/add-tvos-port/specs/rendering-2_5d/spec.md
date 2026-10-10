## MODIFIED Requirements

### Requirement: Input mapping

The renderer SHALL translate user input into intent values dispatched to a controller layer. Raw input MUST NOT be wired directly into `CityCore`. Supported inputs include tap/click, drag, pinch, two-finger pan, hover (Mac/iPad pointer), Apple Pencil hover where available, and on Apple TV the Siri Remote and extended game controllers. On Apple TV the scene MUST NOT treat touches from the remote's touch surface as screen locations: remote input reaches the controller layer only through the reticle rules in `tv-remote-controls`.

#### Scenario: Tap dispatched as intent

- **WHEN** the user taps a tile
- **THEN** an intent of `tapTile(coord)` is dispatched to the controller, which decides what to do (e.g. enqueue a place command)

#### Scenario: Remote select dispatched as a tap on the reticle tile

- **WHEN** the player presses select on the Siri Remote with the reticle on tile (4, 7)
- **THEN** an intent of `tapTile((4, 7))` is dispatched to the controller

### Requirement: Tap is suppressed while a placement is pending

While `GameSession.pendingPlacement` is non-nil, the controller's `handleTap(at:)` SHALL be a no-op. World taps MUST NOT change the pending anchor, MUST NOT commit placement, and MUST NOT change `selectedTool`. On iOS the player MUST use the PlacementHUD's arrows / checkmark / cancel to drive the pending state. On Apple TV the pending anchor follows the reticle and select confirms, as `tv-remote-controls` specifies; a remote select confirms instead of reaching `handleTap(at:)`. This prevents the common "tap to dismiss the menu then accidentally move the ghost" failure mode.

#### Scenario: handleTap is suppressed while a placement is pending

- **WHEN** `pendingPlacement?.anchor == (3, 4)` and the player taps tile `(7, 7)`
- **THEN** `pendingPlacement?.anchor` remains `(3, 4)`, no command is enqueued, and `selectedTool` is unchanged

#### Scenario: ghostState reads from pendingPlacement when set

- **WHEN** `pendingPlacement?.anchor == (3, 4)` and `pendingPlacement?.kind == .house`
- **THEN** `ghostState()` returns a `GhostPreview` with `tile == TileCoordinate(x: 3, y: 4)` and `kind == .house` regardless of `hoveredTile`

### Requirement: Palette-armed buildings route through pending placement on iOS

On iOS, when the player taps a world tile with a build tool armed via the `BuildPaletteView`, the tap SHALL enter pending-placement mode for that building kind at the tapped tile (matching the long-press → menu → pick flow), EXCEPT when the armed tool is `.place(.road)` or `.demolish`. Road and demolish MUST continue to commit immediately on tap / drag (paint behavior). A drag with a non-road building armed MUST NOT paint buildings, and a drag pans the camera in that case. On macOS, palette-armed taps MUST commit immediately on click for every kind, including non-road buildings. On Apple TV, arming a building SHALL enter pending placement at the reticle tile at once, without waiting for a tap, as `tv-remote-controls` specifies.

The rule is the session flag `GameSession.confirmsBuildingPlacement`, on by default on iOS and Apple TV and off on macOS, so every behaviour is testable on any platform.

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

#### Scenario: Building placement is confirmed by default on Apple TV

- **WHEN** a `GameSession` is created with the Apple TV defaults
- **THEN** `confirmsBuildingPlacement` is on
