## Why

The owner played the game and called the terrain ugly (#84). The buildings are lit 3D renders from IsoKit and look like a lived-in period town. The ground under them does not hold up. In-game shots of the seed-0 town and its coast show why:

- **The grid shows.** Every grass, beach and water tile repeats one texture, so the diamond lattice and its periodic pattern are visible everywhere.
- **No large-scale variation.** Grass is one flat green from coast to coast, with no meadows, dry patches or worn ground.
- **Forest is a carpet.** Forest tiles are a flat pattern of round blobs with hard diamond edges. Trees have no height and the forest no gaps.
- **Rock is wallpaper.** Mountain tiles are a busy repeating texture with the same hard zig-zag edge.
- **Coasts zig-zag.** A diagonal coast alternates convex and concave corner tiles, so it reads as a saw blade. Water is one flat colour with no depth near the shore.

## What Changes

- **Ground macro field.** One map-sized sprite, blended `multiplyX2` over the ground tiles, carries smooth low-frequency colour: meadows and dry patches, a darker floor under forest, worn ground round buildings and roads, wet sand, and shallow-to-deep water. The renderer builds it from the terrain grid, occupancy and season, and rebuilds it only when one of those changes.
- **Ground variants.** Full grass tiles get four variants that still join any neighbour, and the renderer picks one per tile.
- **Shores.** Corner-mask chords run straighter, so diagonal coasts read as one line. Wet sand, a foam line and a shallow-water band complete the edge, and the macro field adds the depth gradient. The water keeps its 4 animation frames.
- **Trees.** Each forest tile shows a clump of trees: one depth-sorted sprite with real height, drawn in four densities and four variants. Density falls toward the forest's edge. Clumps stand back from buildings and roads, and a few single trees stand out in the meadow. Seasons give green, autumn colour, and bare broadleaf trees with snowy conifers in winter.
- **Rock.** Each mountain tile shows weathered outcrops and boulders over a scree cover layer. Outcrops grow taller toward the middle of a rock region and thin out toward its edge.
- **BREAKING (art):** forest and mountain tiles stop drawing `terrain-forest*` and `terrain-mountain*` ground textures. They stand on grass, and their character comes from the objects and the macro field. The old sprites are deleted.

Out of scope: elevation and hills, rivers, animated foam, and any change to simulation or placement.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `rendering-2_5d`: gains the ground macro field, terrain objects (trees and outcrops) that depth-sort with buildings, ground variants, and seasonal objects.
- `sprite-asset-pipeline`: the naming grammar gains terrain object sprites (`terrain-forest-<density>[-<season>][-v<n>]`, `terrain-mountain-<density>[-<season>][-v<n>]`). The generators for objects and variants are deterministic.

## Impact

- **Code:**
  - `Packages/CityRender2D`: a new macro-field builder, terrain object selection beside `TerrainTransitionMap`, the terrain sprite spec, the scene factories, and `TextureFiltering` stems.
  - `CityCore` is untouched.
- **Tooling:** new `scripts/art/flora.py` (trees) and `scripts/art/rocks.py` (outcrops), ground variants in `scripts/art/ground.py`, and straighter chords and shore bands in `scripts/art/terrain_tiles.py`. Everything runs in the sprites venv, with no GPU and no image model.
- **Assets:** new object sprites in `Resources/Kit.atlas`, and grass variants. The `terrain-forest*` and `terrain-mountain*` ground sprites are deleted.
- **Performance:** one extra node for the whole map, two for rock regions, and one per visible forest or mountain tile, all on Kit atlas pages. Node counts at the zoom-out limit on the largest map are recorded in the design.
