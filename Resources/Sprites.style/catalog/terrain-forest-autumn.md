---
source = "svg"
---
## Function

The autumn look of the forest tile. The renderer swaps it in for
`terrain-forest` while the calendar is in autumn.

## Visual identity

Painted by `scripts/art/ground.py`. The canopy in autumn: muted ochre, gold and russet broadleaf crowns among dark conifers. Lit like the IsoKit rig (warm sun from the upper left, cool sky) and repeating once per tile in (u, v), so any two tiles join without a seam.

## Sprites

- `terrain-forest-autumn` — canonical static tile

## Recipe

- SVG generator: `scripts/art/terrain_tiles.py` (`full`)
- Texture: `scripts/art/ground.py` (`forest`)
