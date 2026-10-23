## Why

At zoom 0.25 on the 300 × 300 archipelago, the scene holds about 25,000 nodes even after #190 stopped rebuilding the sprite set every frame. Most of those nodes are open-water tiles: identical, animated water sprites with no shore edge. The Mac app runs at 37 to 52 fps there (#171).

## What Changes

- Every water tile whose corners are all water is drawn by one map-sized backdrop sprite instead of a sprite each. A shader works out the tile under each pixel, checks a one-texel-per-tile mask of open water, and repeats the water sprites' own pixels with their four animation frames. The sea looks the same.
- Shore transitions, beach, ships and wakes stay ordinary nodes over it, and the macro field still tints it.
- The mask is rebuilt only when the terrain changes.

The rule "Custom tilemap (no SKTileMapNode)" stands: the backdrop is one `SKSpriteNode`. That rule exists because a tile map is too rigid for variable building footprints and isometric layering (archived `add-mvp-foundation`, D4). Open water has neither, but a sprite with a shader avoids the question.

Out of scope: level of detail at low zoom, and fewer nodes for land tiles.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `rendering-2_5d`: adds "Open water is one backdrop".

## Impact

- **CityRender2D**: `DeepWater.swift` (new), `IsoWorldScene+Sprites.swift` (open-water tiles get no sprite), `IsoWorldScene.swift`.
- **Determinism**: none; the simulation is unchanged.
