---
source = "svg"
---
## Function

Walkable sand band one tile wide between grass interior and water.
Carriers cross beach freely; shore buildings (port, shipyard) anchor on
the inland-side of a beach tile.

## Visual identity

Painted by `scripts/art/ground.py`. Pale sand with wind ripples, darker damp patches and the odd pebble; frames 0 and 1 vary the grain. Beach meeting water blends through the `beach-water` transition tiles: wet sand, a thin foam line and lighter shallows. Lit like the IsoKit rig (warm sun from the upper left, cool sky) and repeating once per tile in (u, v), so any two tiles join without a seam.

## Sprites

- `terrain-beach` — canonical static base
- `terrain-beach-0` — animation frame 0 (sand grain A)
- `terrain-beach-1` — animation frame 1 (sand grain B)
- `terrain-beach-water-t1` — transition, mask 1
- `terrain-beach-water-t2` — transition, mask 2
- `terrain-beach-water-t3` — transition, mask 3
- `terrain-beach-water-t4` — transition, mask 4
- `terrain-beach-water-t5` — transition, mask 5
- `terrain-beach-water-t6` — transition, mask 6
- `terrain-beach-water-t7` — transition, mask 7
- `terrain-beach-water-t8` — transition, mask 8
- `terrain-beach-water-t9` — transition, mask 9
- `terrain-beach-water-t10` — transition, mask 10
- `terrain-beach-water-t11` — transition, mask 11
- `terrain-beach-water-t12` — transition, mask 12
- `terrain-beach-water-t13` — transition, mask 13
- `terrain-beach-water-t14` — transition, mask 14

## Recipe

- SVG generator: `scripts/art/terrain_tiles.py` (`full`, `beach_water`)
- Texture: `scripts/art/ground.py` (`beach`)
