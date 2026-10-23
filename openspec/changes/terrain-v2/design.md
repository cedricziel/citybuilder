## Context

Terrain today is one SpriteKit node per tile at z 0. `art.ground` paints each terrain as a lit, tile-periodic heightfield. Grass, beach and water blend through corner-mask transitions (`TerrainCorners`, design D6 of `replace-generative-sprites-with-isokit`); forest and mountain keep their own full-tile textures. Buildings are 1 node each at z `10 + depth × 0.01`, where depth is the iso depth of the footprint centre.

The before shots (Mac app, `-uiTestSeedTown` and `-uiTestSeedShore`) show the problems listed in the proposal: the tile lattice repeats, grass is flat, forest and rock are hard-edged carpets, and coasts zig-zag.

The maps are 96 × 96 (single island) and 300 × 300 (archipelago). The camera zooms from 0.25 to 4.

## Exploration

A compositor lays out the seed-0 town exactly as `IsoWorldScene` does, from the committed atlas: same corner rule, same anchors, same depth order. Its render of `main` matches the in-game screenshot to a mean of 1.4/255. Three options were mocked on it (`exploration/options-town.jpg`, top left is the in-game before shot):

- **A. Per-tile tint and variants.** Each tile is tinted by world-space noise sampled at its centre, through `SKSpriteNode.color`, at no node cost. The tint is flat over each tile, so neighbours step in colour and the map quilts. Forest and rock are unchanged.
- **B. Macro field and terrain objects.** One map-sized colour field, interpolated below tile size, multiplies over the ground. Trees and rock outcrops are depth-sorted sprites, one per tile.
- **C. One baked map-sized ground texture.** The archipelago is 19,200 pt across. A 4096 px texture, which is already 64 MB in RGBA, holds about 0.2 px per point, so the ground blurs at any useful zoom. It still needs the object sprites for height.

**Chosen: B.** It is the only option that gives trees and rocks height, and all of its ground variation is smooth below tile size. A costs nothing but quilts and leaves forest and rock as they are. C costs memory that iPhone and Apple TV do not have, and looks worse up close. The owner approved B and asked for:

- stronger meadow, dry and worn variation in the grass;
- rounder, weathered rock with gaps, varied heights and a soft edge;
- thinner forest edges;
- the dark forest floor kept.

`exploration/shore-before-after.jpg` shows the coast before and with B's first pass: straighter chords, a shallow band and the depth gradient.

## Goals / Non-Goals

**Goals:**
- No visible tile lattice on grass, beach or water at any zoom.
- Forest reads as trees with height, gaps and soft edges; rock reads as outcrops over scree.
- Coasts read as one line, with wet sand, foam and a shallow-water band.
- Every season keeps its look.
- 60 fps on the baseline devices, with node counts recorded at the zoom-out limit on the archipelago.

**Non-Goals:**
- Terrain elevation, rivers or cliffs.
- Changes to simulation, placement or the terrain grid.
- A custom shader. `SKShader` would allow per-pixel splatting, but atlas sub-textures cannot repeat, and a shader adds a compile step per platform that the sprite gate cannot check.

## Decisions

### D1. A ground macro field, multiplied over the ground

The renderer builds a colour per map vertex, then fills a screen-space texture over the map's bounding rectangle by interpolating the vertices bilinearly. The texture has one texel per 16 pt: 4 per tile across and 2 down. One `SKSpriteNode` draws it at z 1, above the ground tiles (z 0) and below objects and buildings (z ≥ 10), with `.multiplyX2` blending. A value of 0.5 grey is neutral, and the margin outside the map is neutral too.

A vertex's colour is the product of these terms:
- **Meadow:** value noise of world position, with features about 7 tiles across, between lush (darker, cooler) and dry (lighter, yellower), with a little brown at the dry end. Ground only; not water.
- **Mottling:** value noise with features about 1.5 tiles across, ±8 %. This and the meadow term break up the tile period.
- **Forest floor:** a darker, cooler shade weighted by the share of forest tiles round the vertex, blurred over about half a tile.
- **Worn ground:** browner where a vertex is within one tile of an occupied tile.
- **Wet sand:** darker on beach vertices next to water.
- **Water depth:** a brighter teal at distance 1 from land, fading to a deep blue at distance 5 and beyond. Distance comes from a breadth-first search over the grid.
- **Season:** autumn shifts the meadow toward straw; winter flattens it to a faint ±4 % on snow and drops the worn term.

Noise is a deterministic integer hash of the vertex and a fixed salt, so a map always looks the same. The field is rebuilt when the terrain grid, the occupancy or the season changes. For the 300 × 300 archipelago that is 1200 × 600 texels.

Alternative: put the vertex grid itself in the texture and let the GPU interpolate. That needs the sprite rotated 45° in a parent squashed to half height. It is cheaper, but the transform is easy to get subtly wrong, and the CPU build costs a few milliseconds only when something changes.

### D2. Grass variants that still join

Full grass tiles ship 4 variants: `terrain-grass[-<season>]-v<n>`, with variant 0 as the canonical stem, each with its sway frames. A variant adds noise windowed by `(sin πu · sin πv)²` to the shared periodic texture, so every variant still joins every neighbour (skill: Ground textures). The renderer picks one with `SpriteAtlas.variantIndex`. The broad patch noise that repeated once per tile moves out of the texture: the macro field does that job across the whole map.

### D3. Terrain objects: one sprite per forest or mountain tile

A forest tile draws a tree clump and a mountain tile an outcrop, as a child of its terrain node. The object is part of the terrain sprite key, so the reconciler swaps it when it changes.

**Density** comes from the tile's distance to the region's edge. A breadth-first search over 4-neighbours runs once per terrain grid, next to the transition map.

| Distance | Forest | Mountain |
| --- | --- | --- |
| 1 (edge) | `sparse`, or `medium` for 1 in 3 tiles by hash | `sparse` |
| 2 | `medium` | `medium` |
| 3 and more | `dense` | `dense`, or `peak` where world noise is high |

A tile next to an occupied tile drops one class (`dense` → `medium` → `sparse`). An occupied tile draws no object, so trees and rocks never stand on a footprint or a road.

**No meadow trees:** single trees out in the meadow were tried and dropped. A tree the player sees on a grass tile reads as forest that lumberjacks and foresters ignore. They return with a design that the forestry rules can see.

**Variant:** `SpriteAtlas.variantIndex(coord, 4)`.

### D4. Objects depth-sort with buildings

An object's global z is `10 + (c + r + 1) × 0.01`, the value a 1 × 1 building at that tile gets. The object node is a child of the terrain node at z 0, and SpriteKit adds a child's z to its parent's. Trees in front of a house hide its lower wall, and trees behind it stay behind it.

Each object sprite carries its own cast shadow, like kit buildings. The sun lies to the screen left, so the shadow falls right, into the same row of tiles.

### D5. Objects are ray-cast from simple solids, in numpy

The objects are generated in code, with no image model and no GPU:

- `art.flora` builds every tree from spheres. Broadleaf crowns are clouds of leaf clumps in an ellipsoid. Conifers are cones of clumps that droop in tiers. Bare winter trees are limbs that fork down to twigs.
- `art.rocks` builds outcrops from convex polytopes. A boulder is an ellipsoid cut by about 20 planes and leaned a little. A crag is ledges stacked into a rounded, weathered profile.

Both are cast per pixel through the IsoKit camera (2:1, 30° down, 11.31 pt per metre) and lit with `art.ground`'s rig: warm sun with soft shadows through the canopy, a cool sky scaled by depth into the crown, and leaf facets from a world-space hash. They are rendered at 4 px per point and box-filtered to @2× and @1×. A sprite is 144 × 132 pt, anchored 56 pt from its left and 112 pt from its top at the tile centre.

The PNGs enter the existing SVG step as embedded images. `make sprites` and `art.compare` then treat them like every other terrain sprite. The output is byte-stable, because there is no GPU and no SSAO noise.

### D6. Names and seasons

`terrain-forest-<density>[-<season>][-v<n>]`, with density `sparse`, `medium` or `dense`, and seasons `autumn` and `winter` (spring and summer use the plain name).

`terrain-mountain-<density>[-winter][-v<n>]`, with density `sparse`, `medium`, `dense` or `peak`. Autumn rock uses the plain name.

The season sits before the variant, so `TextureFiltering.stem` strips the variant and keeps a seasonal stem, as it does for `terrain-grass-autumn`. A missing seasonal sprite falls back to the plain one. A season change redraws every tile with an object.

### D7. Straighter shore chords and the shore bands

In `terrain_tiles.curve`, a boundary between adjacent edges now bulges 0.14 tile instead of 0.3. Along a diagonal coast the convex and concave corner tiles then line up into one wobbling line instead of a saw blade. Boundaries between opposite edges keep their 0.36.

The tile-local bands stay narrow, so they never step at a plain neighbour: wet sand, a bright foam line, and a pale shallow band. The wide gradients are the macro field's job.

### D8. A scree cover under rock

A second map-sized sprite, built with the macro field and alpha-blended at z 0.5, lays a grey-brown scree over mountain ground. Its alpha follows the share of mountain tiles round each vertex, blurred over a third of a tile, so the grass shows through at the region's edge. The macro field multiplies over the cover too.

### D9. Performance budget

Terrain is already 1 node per visible tile. This change adds:
- 2 nodes for the whole map: the macro field and the cover;
- 1 node per visible forest or mountain tile.

Every texture comes from Kit atlas pages. The trees PR records node counts and frame times at zoom 0.25 on the archipelago. If they exceed the budget, the fallback is:
1. Cull to the screen's diamond in tile space instead of its bounding box. That halves the tile nodes.
2. Below zoom 0.5, draw no objects on `sparse` tiles.

## Risks / Trade-offs

- **Tall trees hide what stands behind them.** Clumps thin next to buildings, and the inspector still selects by tile. → If playtests find units or buildings lost behind forest, cap tree height near occupied tiles.
- **A macro rebuild costs a few milliseconds.** It runs on change, not per frame. → If placing buildings shows a hitch, rebuild only the dirty rectangle.
- **One clump per tile repeats.** There are 4 variants per density, picked by hash, and the macro field varies the floor under them. → If repetition shows on large forests, add variants: each is one more PNG pair.

## Migration Plan

One PR per step against `main`, each with an in-game before and after shot and `Refs #84`:
1. This change.
2. Macro field (D1).
3. Grass variants and shores (D2, D7).
4. Trees (D3–D6 for forest, D9 numbers); delete `terrain-forest*`.
5. Rocks and scree cover (D3–D6 for mountain, D8); delete `terrain-mountain*`.

Each step works without the next. Until step 4 lands, forest tiles keep their old sprite.

## Open Questions

- Should foam animate with the water's 4 frames? Static foam ships first.
