---
source = "svg"
---
## Function

Non-walkable forest tile. Lumberjack huts extract wood from adjacent
forest tiles; carriers route around them. Buildings cannot place on
forest.

## Visual identity

The tile's ground is grass, drawn by the grass tiles and the macro field, which darkens the forest floor. Over it stands one tree clump per tile, ray-cast by `scripts/art/flora.py` (through `scripts/art/terrain_objects.py`) from spheres and lit like the IsoKit rig: broadleaf crowns of leaf clumps round a trunk, spruces as tiered cones of needle clumps, a shrub or two at the foot, each clump with its own cast shadow. Autumn turns the broadleaf crowns ochre and russet; winter leaves bare limbs and puts snow on the spruces. A clump keeps its trees all year. The renderer picks the density from the distance to the forest's edge: sparse at the edge, medium on the next ring, dense inside.

## Sheet

Grid: 36 cols × 1 rows. 144×132-point cells with the tile centre 56 points from the left and 112 from the top, rendered at @1x and @2x.

- (0, 0): `terrain-forest-sparse` — sparse clump, spring, variant 0
- (0, 1): `terrain-forest-sparse-v1` — sparse clump, spring, variant 1
- (0, 2): `terrain-forest-sparse-v2` — sparse clump, spring, variant 2
- (0, 3): `terrain-forest-sparse-v3` — sparse clump, spring, variant 3
- (0, 4): `terrain-forest-sparse-autumn` — sparse clump, autumn, variant 0
- (0, 5): `terrain-forest-sparse-autumn-v1` — sparse clump, autumn, variant 1
- (0, 6): `terrain-forest-sparse-autumn-v2` — sparse clump, autumn, variant 2
- (0, 7): `terrain-forest-sparse-autumn-v3` — sparse clump, autumn, variant 3
- (0, 8): `terrain-forest-sparse-winter` — sparse clump, winter, variant 0
- (0, 9): `terrain-forest-sparse-winter-v1` — sparse clump, winter, variant 1
- (0, 10): `terrain-forest-sparse-winter-v2` — sparse clump, winter, variant 2
- (0, 11): `terrain-forest-sparse-winter-v3` — sparse clump, winter, variant 3
- (0, 12): `terrain-forest-medium` — medium clump, spring, variant 0
- (0, 13): `terrain-forest-medium-v1` — medium clump, spring, variant 1
- (0, 14): `terrain-forest-medium-v2` — medium clump, spring, variant 2
- (0, 15): `terrain-forest-medium-v3` — medium clump, spring, variant 3
- (0, 16): `terrain-forest-medium-autumn` — medium clump, autumn, variant 0
- (0, 17): `terrain-forest-medium-autumn-v1` — medium clump, autumn, variant 1
- (0, 18): `terrain-forest-medium-autumn-v2` — medium clump, autumn, variant 2
- (0, 19): `terrain-forest-medium-autumn-v3` — medium clump, autumn, variant 3
- (0, 20): `terrain-forest-medium-winter` — medium clump, winter, variant 0
- (0, 21): `terrain-forest-medium-winter-v1` — medium clump, winter, variant 1
- (0, 22): `terrain-forest-medium-winter-v2` — medium clump, winter, variant 2
- (0, 23): `terrain-forest-medium-winter-v3` — medium clump, winter, variant 3
- (0, 24): `terrain-forest-dense` — dense clump, spring, variant 0
- (0, 25): `terrain-forest-dense-v1` — dense clump, spring, variant 1
- (0, 26): `terrain-forest-dense-v2` — dense clump, spring, variant 2
- (0, 27): `terrain-forest-dense-v3` — dense clump, spring, variant 3
- (0, 28): `terrain-forest-dense-autumn` — dense clump, autumn, variant 0
- (0, 29): `terrain-forest-dense-autumn-v1` — dense clump, autumn, variant 1
- (0, 30): `terrain-forest-dense-autumn-v2` — dense clump, autumn, variant 2
- (0, 31): `terrain-forest-dense-autumn-v3` — dense clump, autumn, variant 3
- (0, 32): `terrain-forest-dense-winter` — dense clump, winter, variant 0
- (0, 33): `terrain-forest-dense-winter-v1` — dense clump, winter, variant 1
- (0, 34): `terrain-forest-dense-winter-v2` — dense clump, winter, variant 2
- (0, 35): `terrain-forest-dense-winter-v3` — dense clump, winter, variant 3

## Animation

Static — no animation loop.

## Recipe

- Objects: `scripts/art/flora.py` through `scripts/art/terrain_objects.py`, embedded in SVG by `scripts/art/svg_sprites.py`
