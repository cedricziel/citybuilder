---
source = "svg"
---
## Function

Non-walkable mountain tile. Mountains block carriers, ships, and
building placement. The renderer assigns one of four visual variants
deterministically per tile coordinate so a mountain range reads as
varied rock rather than a row of clones.

## Visual identity

The tile's ground is grass under a soft scree cover from the macro field. Over it stands one outcrop per tile, ray-cast by `scripts/art/rocks.py` (through `scripts/art/terrain_objects.py`) and lit like the IsoKit rig. Each stone is an ellipsoid cut by planes: at the region's rim (`sparse`, `medium`) many shallow cuts make rounded, weathered tors and boulders; inside (`dense`, `peak`) fewer, deeper cuts make angular crags up to 7 m tall, so a region rises to a summit. Every tile leaves gaps where grass and scree show. The stone leans cool so the warm sun leaves it a neutral warm grey. Flat tops carry lichen, or snow in winter.

## Sheet

Grid: 32 cols × 1 rows. 144×132-point cells with the tile centre 56 points from the left and 112 from the top, rendered at @1x and @2x.

- (0, 0): `terrain-mountain-sparse` — sparse outcrop, all but winter, variant 0
- (0, 1): `terrain-mountain-sparse-v1` — sparse outcrop, all but winter, variant 1
- (0, 2): `terrain-mountain-sparse-v2` — sparse outcrop, all but winter, variant 2
- (0, 3): `terrain-mountain-sparse-v3` — sparse outcrop, all but winter, variant 3
- (0, 4): `terrain-mountain-sparse-winter` — sparse outcrop, winter, variant 0
- (0, 5): `terrain-mountain-sparse-winter-v1` — sparse outcrop, winter, variant 1
- (0, 6): `terrain-mountain-sparse-winter-v2` — sparse outcrop, winter, variant 2
- (0, 7): `terrain-mountain-sparse-winter-v3` — sparse outcrop, winter, variant 3
- (0, 8): `terrain-mountain-medium` — medium outcrop, all but winter, variant 0
- (0, 9): `terrain-mountain-medium-v1` — medium outcrop, all but winter, variant 1
- (0, 10): `terrain-mountain-medium-v2` — medium outcrop, all but winter, variant 2
- (0, 11): `terrain-mountain-medium-v3` — medium outcrop, all but winter, variant 3
- (0, 12): `terrain-mountain-medium-winter` — medium outcrop, winter, variant 0
- (0, 13): `terrain-mountain-medium-winter-v1` — medium outcrop, winter, variant 1
- (0, 14): `terrain-mountain-medium-winter-v2` — medium outcrop, winter, variant 2
- (0, 15): `terrain-mountain-medium-winter-v3` — medium outcrop, winter, variant 3
- (0, 16): `terrain-mountain-dense` — dense outcrop, all but winter, variant 0
- (0, 17): `terrain-mountain-dense-v1` — dense outcrop, all but winter, variant 1
- (0, 18): `terrain-mountain-dense-v2` — dense outcrop, all but winter, variant 2
- (0, 19): `terrain-mountain-dense-v3` — dense outcrop, all but winter, variant 3
- (0, 20): `terrain-mountain-dense-winter` — dense outcrop, winter, variant 0
- (0, 21): `terrain-mountain-dense-winter-v1` — dense outcrop, winter, variant 1
- (0, 22): `terrain-mountain-dense-winter-v2` — dense outcrop, winter, variant 2
- (0, 23): `terrain-mountain-dense-winter-v3` — dense outcrop, winter, variant 3
- (0, 24): `terrain-mountain-peak` — peak outcrop, all but winter, variant 0
- (0, 25): `terrain-mountain-peak-v1` — peak outcrop, all but winter, variant 1
- (0, 26): `terrain-mountain-peak-v2` — peak outcrop, all but winter, variant 2
- (0, 27): `terrain-mountain-peak-v3` — peak outcrop, all but winter, variant 3
- (0, 28): `terrain-mountain-peak-winter` — peak outcrop, winter, variant 0
- (0, 29): `terrain-mountain-peak-winter-v1` — peak outcrop, winter, variant 1
- (0, 30): `terrain-mountain-peak-winter-v2` — peak outcrop, winter, variant 2
- (0, 31): `terrain-mountain-peak-winter-v3` — peak outcrop, winter, variant 3

## Animation

Static — no animation loop. The variant cells are art alternates, not frames.

## Recipe

- Objects: `scripts/art/rocks.py` through `scripts/art/terrain_objects.py`, embedded in SVG by `scripts/art/svg_sprites.py`
