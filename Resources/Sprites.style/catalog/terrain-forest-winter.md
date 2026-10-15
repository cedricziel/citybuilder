---
source = "svg"
---
## Function

The winter look of the forest tile. The renderer swaps it in for
`terrain-forest` while the calendar is in winter.

## Visual identity

Painted by `scripts/art/ground.py`. The canopy in winter: bare broadleaf crowns as a grey haze of twigs painted onto the snow, with no relief or shadow of their own, and conifers carrying snow on their sunlit side. Lit like the IsoKit rig (warm sun from the upper left, cool sky) and repeating once per tile in (u, v), so any two tiles join without a seam.

## Sheet

Grid: 1 cols × 1 rows. 64×32 point tiles, rendered at @1x and @2x.

- (0, 0): `terrain-forest-winter` — canonical static tile

## Animation

Static — no animation.

## Recipe

- SVG generator: `scripts/art/terrain_tiles.py` (`full`)
- Texture: `scripts/art/ground.py` (`forest`)
