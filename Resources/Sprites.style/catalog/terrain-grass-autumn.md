---
source = "svg"
---
## Function

The autumn look of the grass tile. The renderer swaps it in for
`terrain-grass` while the calendar is in autumn.

## Visual identity

Painted by `scripts/art/ground.py`. The meadow in autumn: olive and ochre patches, same forms and breeze as spring. Its shore uses the autumn set of `grass-beach` transitions. Lit like the IsoKit rig (warm sun from the upper left, cool sky) and repeating once per tile in (u, v), so any two tiles join without a seam.

## Sheet

Grid: 17 cols × 1 rows. 64×32 point tiles, rendered at @1x and @2x.

- (0, 0): `terrain-grass-autumn` — canonical static base
- (0, 1): `terrain-grass-autumn-0` — animation frame 0
- (0, 2): `terrain-grass-autumn-1` — animation frame 1
- (0, 3): `terrain-grass-beach-t1-autumn` — transition, mask 1
- (0, 4): `terrain-grass-beach-t2-autumn` — transition, mask 2
- (0, 5): `terrain-grass-beach-t3-autumn` — transition, mask 3
- (0, 6): `terrain-grass-beach-t4-autumn` — transition, mask 4
- (0, 7): `terrain-grass-beach-t5-autumn` — transition, mask 5
- (0, 8): `terrain-grass-beach-t6-autumn` — transition, mask 6
- (0, 9): `terrain-grass-beach-t7-autumn` — transition, mask 7
- (0, 10): `terrain-grass-beach-t8-autumn` — transition, mask 8
- (0, 11): `terrain-grass-beach-t9-autumn` — transition, mask 9
- (0, 12): `terrain-grass-beach-t10-autumn` — transition, mask 10
- (0, 13): `terrain-grass-beach-t11-autumn` — transition, mask 11
- (0, 14): `terrain-grass-beach-t12-autumn` — transition, mask 12
- (0, 15): `terrain-grass-beach-t13-autumn` — transition, mask 13
- (0, 16): `terrain-grass-beach-t14-autumn` — transition, mask 14

## Animation

Two-frame wind-blade flutter, same timing as `terrain-grass`.

- Wind flutter: `(0, 1)` → `(0, 2)`.

## Recipe

- SVG generator: `scripts/art/terrain_tiles.py` (`full`, `grass_beach`)
- Texture: `scripts/art/ground.py` (`grass`)
