---
source = "svg"
---
## Function

Walkable grassland tile, the dominant ground texture of the island
interior. Buildings and roads place freely on grass.

## Visual identity

Painted by `scripts/art/ground.py`. A sunlit meadow of clumps and blade stipple, in four variants that join any neighbour; the renderer's macro field lays the broad light and dark patches across tiles; frames 0 and 1 shift the stipple for a breeze. Grass meeting beach blends through the `grass-beach` transition tiles, with a dry-grass fringe along the edge. Lit like the IsoKit rig (warm sun from the upper left, cool sky) and repeating once per tile in (u, v), so any two tiles join without a seam.

## Sprites

- `terrain-grass` — canonical static base
- `terrain-grass-0` — animation frame 0 (slight blade flutter)
- `terrain-grass-1` — animation frame 1 (blade flutter peak)
- `terrain-grass-beach-t1` — transition, mask 1
- `terrain-grass-beach-t2` — transition, mask 2
- `terrain-grass-beach-t3` — transition, mask 3
- `terrain-grass-beach-t4` — transition, mask 4
- `terrain-grass-beach-t5` — transition, mask 5
- `terrain-grass-beach-t6` — transition, mask 6
- `terrain-grass-beach-t7` — transition, mask 7
- `terrain-grass-beach-t8` — transition, mask 8
- `terrain-grass-beach-t9` — transition, mask 9
- `terrain-grass-beach-t10` — transition, mask 10
- `terrain-grass-beach-t11` — transition, mask 11
- `terrain-grass-beach-t12` — transition, mask 12
- `terrain-grass-beach-t13` — transition, mask 13
- `terrain-grass-beach-t14` — transition, mask 14
- `terrain-grass-v1` — variant 1, its own clumps inside the tile; joins any variant
- `terrain-grass-v1-0` — variant 1, animation frame 0
- `terrain-grass-v1-1` — variant 1, animation frame 1
- `terrain-grass-v2` — variant 2, its own clumps inside the tile; joins any variant
- `terrain-grass-v2-0` — variant 2, animation frame 0
- `terrain-grass-v2-1` — variant 2, animation frame 1
- `terrain-grass-v3` — variant 3, its own clumps inside the tile; joins any variant
- `terrain-grass-v3-0` — variant 3, animation frame 0
- `terrain-grass-v3-1` — variant 3, animation frame 1

## Recipe

- SVG generator: `scripts/art/terrain_tiles.py` (`full`, `grass_beach`)
- Texture: `scripts/art/ground.py` (`grass`)
