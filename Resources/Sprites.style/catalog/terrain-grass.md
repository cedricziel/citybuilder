---
source = "svg"
---
## Function

Walkable grassland tile, the dominant ground texture of the island
interior. Buildings and roads place freely on grass.

## Visual identity

Painted by `scripts/art/ground.py`. A sunlit meadow of clumps and blade stipple, in four variants that join any neighbour; the renderer's macro field lays the broad light and dark patches across tiles; frames 0 and 1 shift the stipple for a breeze. Grass meeting beach blends through the `grass-beach` transition tiles, with a dry-grass fringe along the edge. Lit like the IsoKit rig (warm sun from the upper left, cool sky) and repeating once per tile in (u, v), so any two tiles join without a seam.

## Sheet

Grid: 26 cols × 1 rows. 64×32 point tiles, rendered at @1x and @2x.

- (0, 0): `terrain-grass` — canonical static base
- (0, 1): `terrain-grass-0` — animation frame 0 (slight blade flutter)
- (0, 2): `terrain-grass-1` — animation frame 1 (blade flutter peak)
- (0, 3): `terrain-grass-beach-t1` — transition, mask 1
- (0, 4): `terrain-grass-beach-t2` — transition, mask 2
- (0, 5): `terrain-grass-beach-t3` — transition, mask 3
- (0, 6): `terrain-grass-beach-t4` — transition, mask 4
- (0, 7): `terrain-grass-beach-t5` — transition, mask 5
- (0, 8): `terrain-grass-beach-t6` — transition, mask 6
- (0, 9): `terrain-grass-beach-t7` — transition, mask 7
- (0, 10): `terrain-grass-beach-t8` — transition, mask 8
- (0, 11): `terrain-grass-beach-t9` — transition, mask 9
- (0, 12): `terrain-grass-beach-t10` — transition, mask 10
- (0, 13): `terrain-grass-beach-t11` — transition, mask 11
- (0, 14): `terrain-grass-beach-t12` — transition, mask 12
- (0, 15): `terrain-grass-beach-t13` — transition, mask 13
- (0, 16): `terrain-grass-beach-t14` — transition, mask 14
- (0, 17): `terrain-grass-v1` — variant 1, its own clumps inside the tile; joins any variant
- (0, 18): `terrain-grass-v1-0` — variant 1, animation frame 0
- (0, 19): `terrain-grass-v1-1` — variant 1, animation frame 1
- (0, 20): `terrain-grass-v2` — variant 2, its own clumps inside the tile; joins any variant
- (0, 21): `terrain-grass-v2-0` — variant 2, animation frame 0
- (0, 22): `terrain-grass-v2-1` — variant 2, animation frame 1
- (0, 23): `terrain-grass-v3` — variant 3, its own clumps inside the tile; joins any variant
- (0, 24): `terrain-grass-v3-0` — variant 3, animation frame 0
- (0, 25): `terrain-grass-v3-1` — variant 3, animation frame 1

## Animation

Two-frame wind-blade flutter looping at ~0.6s per frame.

- Wind flutter: `(0, 1)` → `(0, 2)`. Frames are placed in adjacent cells
  on row 0.

## Recipe

- SVG generator: `scripts/art/terrain_tiles.py` (`full`, `grass_beach`)
- Texture: `scripts/art/ground.py` (`grass`)
