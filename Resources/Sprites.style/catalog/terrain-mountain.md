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

## Sheet

Grid: 4 cols × 1 rows. 64×32 point tiles, rendered at @1x and @2x.

- (0, 0): `terrain-mountain` — canonical variant 0
- (0, 1): `terrain-mountain-v1` — variant 1
- (0, 2): `terrain-mountain-v2` — variant 2
- (0, 3): `terrain-mountain-v3` — variant 3

## Animation

Static — no animation loop. The variant cells are art alternates, not
frames. Each variant must be self-consistent (same silhouette outline
weight, same shadow direction) so adjacent tiles unify into a range.

## Recipe

- SVG generator: `scripts/art/terrain_tiles.py` (`full`)
- Texture: `scripts/art/ground.py` (`rock`)
