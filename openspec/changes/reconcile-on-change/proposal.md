## Why

At zoom 0.25 on the 300 × 300 archipelago the Mac app runs at about 12 fps (#175). Every frame, `IsoWorldScene` builds the whole desired sprite set again (one `SpriteSpec` per visible tile, about 24,000), hashes it and diffs it against the scene, even when nothing has changed. That takes about 25 ms per frame in a release build.

## What Changes

- The scene keeps what its sprites were drawn from: the tiles on screen, the terrain and object maps, and the building inputs (buildings, occupancy, road access, house populations and modifiers, rivals). A frame where none of them changed does no sprite work.
- The tiles on screen are one run of columns per row (`VisibleTiles`). A pan adds and removes only the tiles that entered or left the view.
- A building placed or cleared redraws only the tiles whose tree or rock object changed. A terrain change redraws the view, replacing only the tiles whose sprite changed. A season change redraws only the tiles it dropped.
- Building sprites are diffed on their own, and only when their inputs change. Window glow walks the buildings, not every sprite.

Out of scope: fewer nodes for deep water (#171) and level of detail at low zoom.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `rendering-2_5d`: adds "Sprites reconcile only on change".

## Impact

- **CityRender2D**: `IsoWorldScene+Sprites.swift` (new), `VisibleTiles.swift` (new), `IsoWorldScene.swift`, `SnapshotReconciliation.swift` (terrain and building helpers), `TerrainObjects.swift` (`update(occupancy:)` returns the tiles it changed), `CityLifeRendering.swift`.
- **Determinism**: none; the simulation is unchanged.
