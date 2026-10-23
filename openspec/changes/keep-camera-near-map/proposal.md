## Why

On iOS and macOS the camera can pan without limit; only Apple TV keeps it on the map. Once the whole view is off the map, `Culling.visibleTileRange` builds a range whose lower bound is above its upper bound before its guard can reject it, and the app traps. A player who pans far enough away also loses the island.

## What Changes

- `Culling.visibleTileRange` checks the clamped bounds before it builds a range, so a view wholly off the map culls to nothing.
- On every platform the camera centre stays within 8 tiles of the map (`GameSession.cameraMapMargin`). Apple TV keeps its stricter rule: the centre stays on the map, so the reticle is always on a tile.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `rendering-2_5d`: adds "Camera stays near the map".

## Impact

- **CityRender2D**: `Culling.swift`.
- **CityUI**: `RemoteCamera.swift` (`cameraDidMove` clamps on every platform).
- **Determinism**: none; the simulation is unchanged.
