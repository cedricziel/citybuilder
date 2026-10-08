---
source = "procedural"
---
## Function

The winter look of the grass tile. The renderer swaps it in for
`terrain-grass` while the calendar is in winter.

## Visual identity

Snow cover: cream (sun-warm) snow with foam-blue hollows and south rims,
and a few shadow-green grass tufts poking through.

## Sheet

Grid: 3 cols × 1 rows. Cells are 512×512 sheet pixels each on a
1536×512 canvas; downsamples to a 64×32 iso ground tile.

- (0, 0): `terrain-grass-winter` — canonical static base
- (0, 1): `terrain-grass-winter-0` — animation frame 0
- (0, 2): `terrain-grass-winter-1` — animation frame 1

## Animation

Two-frame flutter of the exposed tufts, same timing as `terrain-grass`.

- Wind flutter: `(0, 1)` → `(0, 2)`.
