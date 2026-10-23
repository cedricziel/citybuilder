---
source = "svg"
---
## Function

The winter look of the grass tile. The renderer swaps it in for
`terrain-grass` while the calendar is in winter.

## Visual identity

Painted by `scripts/art/ground.py`. The meadow under snow: cool white cover with grass showing through in the low patches. Its shore uses the winter set of `grass-beach` transitions. Lit like the IsoKit rig (warm sun from the upper left, cool sky) and repeating once per tile in (u, v), so any two tiles join without a seam.

## Sprites

- `terrain-grass-winter` — canonical static base
- `terrain-grass-winter-0` — animation frame 0
- `terrain-grass-winter-1` — animation frame 1
- `terrain-grass-beach-t1-winter` — transition, mask 1
- `terrain-grass-beach-t2-winter` — transition, mask 2
- `terrain-grass-beach-t3-winter` — transition, mask 3
- `terrain-grass-beach-t4-winter` — transition, mask 4
- `terrain-grass-beach-t5-winter` — transition, mask 5
- `terrain-grass-beach-t6-winter` — transition, mask 6
- `terrain-grass-beach-t7-winter` — transition, mask 7
- `terrain-grass-beach-t8-winter` — transition, mask 8
- `terrain-grass-beach-t9-winter` — transition, mask 9
- `terrain-grass-beach-t10-winter` — transition, mask 10
- `terrain-grass-beach-t11-winter` — transition, mask 11
- `terrain-grass-beach-t12-winter` — transition, mask 12
- `terrain-grass-beach-t13-winter` — transition, mask 13
- `terrain-grass-beach-t14-winter` — transition, mask 14
- `terrain-grass-winter-v1` — variant 1, its own clumps inside the tile; joins any variant
- `terrain-grass-winter-v1-0` — variant 1, animation frame 0
- `terrain-grass-winter-v1-1` — variant 1, animation frame 1
- `terrain-grass-winter-v2` — variant 2, its own clumps inside the tile; joins any variant
- `terrain-grass-winter-v2-0` — variant 2, animation frame 0
- `terrain-grass-winter-v2-1` — variant 2, animation frame 1
- `terrain-grass-winter-v3` — variant 3, its own clumps inside the tile; joins any variant
- `terrain-grass-winter-v3-0` — variant 3, animation frame 0
- `terrain-grass-winter-v3-1` — variant 3, animation frame 1

## Recipe

- SVG generator: `scripts/art/terrain_tiles.py` (`full`, `grass_beach`)
- Texture: `scripts/art/ground.py` (`grass`)
