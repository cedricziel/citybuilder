---
source = "svg"
---
## Function

The winter look of the grass tile. The renderer swaps it in for
`terrain-grass` while the calendar is in winter.

## Visual identity

Painted by `scripts/art/ground.py`. The meadow under snow: cool white cover with grass showing through in the low patches. Its shore uses the winter set of `grass-beach` transitions. Lit like the IsoKit rig (warm sun from the upper left, cool sky) and repeating once per tile in (u, v), so any two tiles join without a seam.

## Sheet

Grid: 26 cols × 1 rows. 64×32 point tiles, rendered at @1x and @2x.

- (0, 0): `terrain-grass-winter` — canonical static base
- (0, 1): `terrain-grass-winter-0` — animation frame 0
- (0, 2): `terrain-grass-winter-1` — animation frame 1
- (0, 3): `terrain-grass-beach-t1-winter` — transition, mask 1
- (0, 4): `terrain-grass-beach-t2-winter` — transition, mask 2
- (0, 5): `terrain-grass-beach-t3-winter` — transition, mask 3
- (0, 6): `terrain-grass-beach-t4-winter` — transition, mask 4
- (0, 7): `terrain-grass-beach-t5-winter` — transition, mask 5
- (0, 8): `terrain-grass-beach-t6-winter` — transition, mask 6
- (0, 9): `terrain-grass-beach-t7-winter` — transition, mask 7
- (0, 10): `terrain-grass-beach-t8-winter` — transition, mask 8
- (0, 11): `terrain-grass-beach-t9-winter` — transition, mask 9
- (0, 12): `terrain-grass-beach-t10-winter` — transition, mask 10
- (0, 13): `terrain-grass-beach-t11-winter` — transition, mask 11
- (0, 14): `terrain-grass-beach-t12-winter` — transition, mask 12
- (0, 15): `terrain-grass-beach-t13-winter` — transition, mask 13
- (0, 16): `terrain-grass-beach-t14-winter` — transition, mask 14
- (0, 17): `terrain-grass-winter-v1` — variant 1, its own clumps inside the tile; joins any variant
- (0, 18): `terrain-grass-winter-v1-0` — variant 1, animation frame 0
- (0, 19): `terrain-grass-winter-v1-1` — variant 1, animation frame 1
- (0, 20): `terrain-grass-winter-v2` — variant 2, its own clumps inside the tile; joins any variant
- (0, 21): `terrain-grass-winter-v2-0` — variant 2, animation frame 0
- (0, 22): `terrain-grass-winter-v2-1` — variant 2, animation frame 1
- (0, 23): `terrain-grass-winter-v3` — variant 3, its own clumps inside the tile; joins any variant
- (0, 24): `terrain-grass-winter-v3-0` — variant 3, animation frame 0
- (0, 25): `terrain-grass-winter-v3-1` — variant 3, animation frame 1

## Animation

Two-frame flutter of the exposed tufts, same timing as `terrain-grass`.

- Wind flutter: `(0, 1)` → `(0, 2)`.

## Recipe

- SVG generator: `scripts/art/terrain_tiles.py` (`full`, `grass_beach`)
- Texture: `scripts/art/ground.py` (`grass`)
