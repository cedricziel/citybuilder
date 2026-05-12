## ADDED Requirements

### Requirement: Camera center tile exposure

`Camera` SHALL expose a `centerTile() -> TileCoordinate` method that returns the rounded tile-space center of the current view. This is read by `IsoWorldScene` once per camera-driven listener update to inform the audio layer's listener position.

#### Scenario: Camera-center tile is exposed

- **WHEN** the camera has `centerX = 8.4`, `centerY = 6.2`
- **THEN** `centerTile()` returns `TileCoordinate(x: 8, y: 6)`

#### Scenario: Camera-center tile updates as camera pans

- **WHEN** the camera pans from `centerX = 8.4` to `centerX = 9.8`
- **THEN** `centerTile()` returns `TileCoordinate(x: 10, y: 6)` after the pan (rounded)

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
