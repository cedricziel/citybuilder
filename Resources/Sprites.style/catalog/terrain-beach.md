---
source = "svg"
---
## Function

Walkable sand band one tile wide between grass interior and water.
Carriers cross beach freely; shore buildings (port, shipyard) anchor on
the inland-side of a beach tile.

## Visual identity

Painted by `scripts/art/ground.py`. Pale sand with wind ripples, darker damp patches and the odd pebble; frames 0 and 1 vary the grain. Beach meeting water blends through the `beach-water` transition tiles: wet sand, a thin foam line and lighter shallows. Lit like the IsoKit rig (warm sun from the upper left, cool sky) and repeating once per tile in (u, v), so any two tiles join without a seam.

## Sheet

Grid: 17 cols × 1 rows. 64×32 point tiles, rendered at @1x and @2x.

- (0, 0): `terrain-beach` — canonical static base
- (0, 1): `terrain-beach-0` — animation frame 0 (sand grain A)
- (0, 2): `terrain-beach-1` — animation frame 1 (sand grain B)
- (0, 3): `terrain-beach-water-t1` — transition, mask 1
- (0, 4): `terrain-beach-water-t2` — transition, mask 2
- (0, 5): `terrain-beach-water-t3` — transition, mask 3
- (0, 6): `terrain-beach-water-t4` — transition, mask 4
- (0, 7): `terrain-beach-water-t5` — transition, mask 5
- (0, 8): `terrain-beach-water-t6` — transition, mask 6
- (0, 9): `terrain-beach-water-t7` — transition, mask 7
- (0, 10): `terrain-beach-water-t8` — transition, mask 8
- (0, 11): `terrain-beach-water-t9` — transition, mask 9
- (0, 12): `terrain-beach-water-t10` — transition, mask 10
- (0, 13): `terrain-beach-water-t11` — transition, mask 11
- (0, 14): `terrain-beach-water-t12` — transition, mask 12
- (0, 15): `terrain-beach-water-t13` — transition, mask 13
- (0, 16): `terrain-beach-water-t14` — transition, mask 14

## Animation

Sand grain shimmer at ~0.45s per frame.

- Grain shimmer: `(0, 1)` → `(0, 2)`. Adjacent on row 0.

## Recipe

- SVG generator: `scripts/art/terrain_tiles.py` (`full`, `beach_water`)
- Texture: `scripts/art/ground.py` (`beach`)
