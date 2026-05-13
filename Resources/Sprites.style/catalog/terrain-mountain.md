## Function

Non-walkable mountain tile. Mountains block carriers, ships, and
building placement. The renderer assigns one of four visual variants
deterministically per tile coordinate so a mountain range reads as
varied rock rather than a row of clones.

## Visual identity

Grey-brown rocky outcrop with sharp shadow-side faces. Each variant
shows a different peak silhouette and dither pattern so neighbouring
tiles never twin. Palette anchors: `#7A6B59` weathered stone mid-tone,
`#5C5046` shadow stone, `#3D2A1D` deep crevice shadow, sparse
`#FFE9C8` sun-warm highlight on west-facing peaks. No snow caps.

## Sheet

Grid: 4 cols × 1 rows. Cells 512×512 sheet pixels on a 2048×512 canvas
(front-matter `sheet_size = "2048x512"` override).

- (0, 0): `terrain-mountain` — canonical variant 0
- (0, 1): `terrain-mountain-v1` — variant 1
- (0, 2): `terrain-mountain-v2` — variant 2
- (0, 3): `terrain-mountain-v3` — variant 3

## Animation

Static — no animation loop. The variant cells are art alternates, not
frames. Each variant must be self-consistent (same silhouette outline
weight, same shadow direction) so adjacent tiles unify into a range.
