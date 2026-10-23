---
source = "svg"
---
## Function

Non-walkable mountain tile. Mountains block carriers, ships, and
building placement. The renderer assigns one of four visual variants
deterministically per tile coordinate so a mountain range reads as
varied rock rather than a row of clones.

## Visual identity

Painted by `scripts/art/ground.py`. Grey rock in big rounded forms with a little ridged detail, lit so the relief reads. Variants 1 to 3 add boulders inside a window that fades out before the tile edges, so every variant joins every neighbour. Lit like the IsoKit rig (warm sun from the upper left, cool sky) and repeating once per tile in (u, v), so any two tiles join without a seam.

## Sprites

- `terrain-mountain` — canonical variant 0
- `terrain-mountain-v1` — variant 1
- `terrain-mountain-v2` — variant 2
- `terrain-mountain-v3` — variant 3

## Recipe

- SVG generator: `scripts/art/terrain_tiles.py` (`full`)
- Texture: `scripts/art/ground.py` (`rock`)
