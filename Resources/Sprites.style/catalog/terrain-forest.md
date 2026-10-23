---
source = "svg"
---
## Function

Non-walkable forest tile. Lumberjack huts extract wood from adjacent
forest tiles; carriers route around them. Buildings cannot place on
forest.

## Visual identity

Painted by `scripts/art/ground.py`. A loose canopy of broadleaf crowns in five greens and three sizes among darker conifers, scattered so the tile repeat is hard to see, with small clearings where the floor shows. Shallow relief keeps it light enough to read next to the grass. Lit like the IsoKit rig (warm sun from the upper left, cool sky) and repeating once per tile in (u, v), so any two tiles join without a seam.

## Sprites

- `terrain-forest` — canonical static tile
- `terrain-forest-single` — single clump, spring, variant 0
- `terrain-forest-single-v1` — single clump, spring, variant 1
- `terrain-forest-single-v2` — single clump, spring, variant 2
- `terrain-forest-single-v3` — single clump, spring, variant 3
- `terrain-forest-single-autumn` — single clump, autumn, variant 0
- `terrain-forest-single-autumn-v1` — single clump, autumn, variant 1
- `terrain-forest-single-autumn-v2` — single clump, autumn, variant 2
- `terrain-forest-single-autumn-v3` — single clump, autumn, variant 3
- `terrain-forest-single-winter` — single clump, winter, variant 0
- `terrain-forest-single-winter-v1` — single clump, winter, variant 1
- `terrain-forest-single-winter-v2` — single clump, winter, variant 2
- `terrain-forest-single-winter-v3` — single clump, winter, variant 3
- `terrain-forest-sparse` — sparse clump, spring, variant 0
- `terrain-forest-sparse-v1` — sparse clump, spring, variant 1
- `terrain-forest-sparse-v2` — sparse clump, spring, variant 2
- `terrain-forest-sparse-v3` — sparse clump, spring, variant 3
- `terrain-forest-sparse-autumn` — sparse clump, autumn, variant 0
- `terrain-forest-sparse-autumn-v1` — sparse clump, autumn, variant 1
- `terrain-forest-sparse-autumn-v2` — sparse clump, autumn, variant 2
- `terrain-forest-sparse-autumn-v3` — sparse clump, autumn, variant 3
- `terrain-forest-sparse-winter` — sparse clump, winter, variant 0
- `terrain-forest-sparse-winter-v1` — sparse clump, winter, variant 1
- `terrain-forest-sparse-winter-v2` — sparse clump, winter, variant 2
- `terrain-forest-sparse-winter-v3` — sparse clump, winter, variant 3
- `terrain-forest-medium` — medium clump, spring, variant 0
- `terrain-forest-medium-v1` — medium clump, spring, variant 1
- `terrain-forest-medium-v2` — medium clump, spring, variant 2
- `terrain-forest-medium-v3` — medium clump, spring, variant 3
- `terrain-forest-medium-autumn` — medium clump, autumn, variant 0
- `terrain-forest-medium-autumn-v1` — medium clump, autumn, variant 1
- `terrain-forest-medium-autumn-v2` — medium clump, autumn, variant 2
- `terrain-forest-medium-autumn-v3` — medium clump, autumn, variant 3
- `terrain-forest-medium-winter` — medium clump, winter, variant 0
- `terrain-forest-medium-winter-v1` — medium clump, winter, variant 1
- `terrain-forest-medium-winter-v2` — medium clump, winter, variant 2
- `terrain-forest-medium-winter-v3` — medium clump, winter, variant 3
- `terrain-forest-dense` — dense clump, spring, variant 0
- `terrain-forest-dense-v1` — dense clump, spring, variant 1
- `terrain-forest-dense-v2` — dense clump, spring, variant 2
- `terrain-forest-dense-v3` — dense clump, spring, variant 3
- `terrain-forest-dense-autumn` — dense clump, autumn, variant 0
- `terrain-forest-dense-autumn-v1` — dense clump, autumn, variant 1
- `terrain-forest-dense-autumn-v2` — dense clump, autumn, variant 2
- `terrain-forest-dense-autumn-v3` — dense clump, autumn, variant 3
- `terrain-forest-dense-winter` — dense clump, winter, variant 0
- `terrain-forest-dense-winter-v1` — dense clump, winter, variant 1
- `terrain-forest-dense-winter-v2` — dense clump, winter, variant 2
- `terrain-forest-dense-winter-v3` — dense clump, winter, variant 3

## Tree clumps (change `terrain-v2`)

Ray-cast by `scripts/art/flora.py` (through `scripts/art/terrain_objects.py`) from spheres and lit
like the IsoKit rig: broadleaf crowns of leaf clumps round a trunk, spruces as tiered cones of needle
clumps, a shrub or two at the foot, each clump with its own cast shadow. Autumn turns the broadleaf
crowns ochre and russet; winter leaves bare limbs and puts snow on the spruces. A clump keeps its
trees all year. The renderer draws one per forest tile, its density from the distance to the
forest's edge; `single` is a lone tree out in the meadow.

## Recipe

- SVG generator: `scripts/art/terrain_tiles.py` (`full`)
- Texture: `scripts/art/ground.py` (`forest`)
