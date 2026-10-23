## Why

#202 drew open water as one backdrop, which cut zoom 0.25 on the 300 × 300 archipelago from about 25,400 nodes to 7,500. Most of what is left is plain ground (#205). On a Mac at zoom 0.25 there are 6,314 ground sprites, and only 725 of them have a transition. The rest are plain grass (the floor under forest and rock included), plain beach and the open water #202 already took. Each is its own animated sprite, so zoom 0.25 still runs below 60 fps.

## What Changes

- Every tile whose ground is plain grass, beach or water (no transition) has no sprite of its own. The open-water backdrop from #202 becomes a ground backdrop that draws all of them.
  - A per-tile texture holds each tile's look (grass variant 0 to 3, beach, water) and an animation phase from its tile hash.
  - A small strip holds the season's looks and frames, each composited with its base neighbours.
  - The shader draws the tile's look under each pixel. Each look keeps its sprite's frame timing, and each tile keeps its own phase, as sprites do today. Open water gains per-tile phases too.
- Transition tiles keep their sprites. Tree and rock objects over plain ground become standalone nodes at the same z and column slot, so they sort with buildings and figures as before.
- A season change redraws the strip. Overlays (macro field, scree, night, glow, ghost, selection, tints) are untouched.
- This replaces the change `deep-water-backdrop`, which never archived. Its requirement becomes "Plain ground is one backdrop".
- The rule "Custom tilemap (no SKTileMapNode)" stands: the backdrop is one `SKSpriteNode`.

Out of scope: baking chunks, and level of detail for objects.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `rendering-2_5d`: adds "Plain ground is one backdrop".

## Impact

- **CityRender2D**:
  - `GroundBackdrop.swift` (replaces `DeepWater.swift`);
  - `IsoWorldScene+Sprites.swift` (plain tiles get no ground sprite);
  - `SceneNodeFactories.swift` (an object over plain ground stands alone);
  - `IsoWorldScene.swift` (the strip is redrawn on a season change).
- **Determinism**: none; the simulation is unchanged.
