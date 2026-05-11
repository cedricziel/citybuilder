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
