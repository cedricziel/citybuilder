---
source = "svg"
---
## Function

Non-walkable water tile. Ships path across water; carriers never enter.
Shore buildings face water on one or more cardinal sides.

## Visual identity

Painted by `scripts/art/ground.py`. Deep teal water with a swell built from a few wave trains and sun glints. The four frames advance every wave by whole periods, so the loop has no jump. Lit like the IsoKit rig (warm sun from the upper left, cool sky) and repeating once per tile in (u, v), so any two tiles join without a seam.

## Sprites

- `terrain-water` — canonical static base
- `terrain-water-0` — animation frame 0 (glint pattern A)
- `terrain-water-1` — animation frame 1 (glint pattern B)
- `terrain-water-2` — animation frame 2 (glint pattern C)
- `terrain-water-3` — animation frame 3 (glint pattern D)

## Recipe

- SVG generator: `scripts/art/terrain_tiles.py` (`full`)
- Texture: `scripts/art/ground.py` (`water`)
