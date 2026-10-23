---
source = "svg"
---
## Function

The autumn look of the grass tile. The renderer swaps it in for
`terrain-grass` while the calendar is in autumn.

## Visual identity

Painted by `scripts/art/ground.py`. The meadow in autumn: olive and ochre patches, same forms and breeze as spring. Its shore uses the autumn set of `grass-beach` transitions. Lit like the IsoKit rig (warm sun from the upper left, cool sky) and repeating once per tile in (u, v), so any two tiles join without a seam.

## Sprites

- `terrain-grass-autumn` — canonical static base
- `terrain-grass-autumn-0` — animation frame 0
- `terrain-grass-autumn-1` — animation frame 1
- `terrain-grass-beach-t1-autumn` — transition, mask 1
- `terrain-grass-beach-t2-autumn` — transition, mask 2
- `terrain-grass-beach-t3-autumn` — transition, mask 3
- `terrain-grass-beach-t4-autumn` — transition, mask 4
- `terrain-grass-beach-t5-autumn` — transition, mask 5
- `terrain-grass-beach-t6-autumn` — transition, mask 6
- `terrain-grass-beach-t7-autumn` — transition, mask 7
- `terrain-grass-beach-t8-autumn` — transition, mask 8
- `terrain-grass-beach-t9-autumn` — transition, mask 9
- `terrain-grass-beach-t10-autumn` — transition, mask 10
- `terrain-grass-beach-t11-autumn` — transition, mask 11
- `terrain-grass-beach-t12-autumn` — transition, mask 12
- `terrain-grass-beach-t13-autumn` — transition, mask 13
- `terrain-grass-beach-t14-autumn` — transition, mask 14
- `terrain-grass-autumn-v1` — variant 1, its own clumps inside the tile; joins any variant
- `terrain-grass-autumn-v1-0` — variant 1, animation frame 0
- `terrain-grass-autumn-v1-1` — variant 1, animation frame 1
- `terrain-grass-autumn-v2` — variant 2, its own clumps inside the tile; joins any variant
- `terrain-grass-autumn-v2-0` — variant 2, animation frame 0
- `terrain-grass-autumn-v2-1` — variant 2, animation frame 1
- `terrain-grass-autumn-v3` — variant 3, its own clumps inside the tile; joins any variant
- `terrain-grass-autumn-v3-0` — variant 3, animation frame 0
- `terrain-grass-autumn-v3-1` — variant 3, animation frame 1

## Recipe

- SVG generator: `scripts/art/terrain_tiles.py` (`full`, `grass_beach`)
- Texture: `scripts/art/ground.py` (`grass`)
