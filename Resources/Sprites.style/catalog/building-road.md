---
source = "procedural"
---
## Function

Walkable ground overlay that speeds carrier movement and connects
buildings. Roads ship with four art variants; the renderer selects one
deterministically per tile coordinate so a long road avoids visible
tiling. No operational animation.

## Visual identity

Dirt road compacted to a hard-packed surface, edges crumbling into
adjacent grass. Each variant differs only in dither pattern and small
wear features (cart ruts, stone outcrop, puddle, plain) — silhouette
and overall tone stay identical so variants blend along a path.
Palette anchors: `#5C3F28` mid-loam, `#3D2A1D` rut shadow, sparse
`#8C6A45` highlight at sunlit edges. No paving stones — these are
unpaved village tracks, not Roman roads.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size. Construction stages on
row 0 to the right of base; art variants laid out on row 1.

- (0, 0): `building-road` — canonical variant 0 (operational)
- (0, 1): `building-road-constructing-0` — staked-out track (rope
  markers, no compaction)
- (0, 2): `building-road-constructing-1` — half-cleared (turf removed
  on the centre line, edges still grassy)
- (0, 3): `building-road-constructing-2` — almost finished (compacted
  surface, edges trimmed)
- (1, 0): `building-road-v1` — variant 1 (cart-rut pattern)
- (1, 1): `building-road-v2` — variant 2 (stone outcrop pattern)
- (1, 2): `building-road-v3` — variant 3 (puddle / shallow ditch
  pattern)
- (1, 3): spare

## Animation

Construction-stage progression — not a loop.

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.

Drawn locally by `scripts/generate_sprites_ai/procedural.py` as packed earth that fills the
whole diamond, so neighbouring road tiles join into one path. The per-cell roles above
describe the original AI sprites.
