---
source = "procedural"
---
## Function

The autumn look of the grass tile. The renderer swaps it in for
`terrain-grass` while the calendar is in autumn.

## Visual identity

Grass gone to straw: light-loam patches between remaining leaf-green
tufts, wheat-coloured blade tips, shadow-green hollows. Same dither and
rim shading as `terrain-grass`.

## Sheet

Grid: 3 cols × 1 rows. Cells are 512×512 sheet pixels each on a
1536×512 canvas; downsamples to a 64×32 iso ground tile.

- (0, 0): `terrain-grass-autumn` — canonical static base
- (0, 1): `terrain-grass-autumn-0` — animation frame 0
- (0, 2): `terrain-grass-autumn-1` — animation frame 1

## Animation

Two-frame wind-blade flutter, same timing as `terrain-grass`.

- Wind flutter: `(0, 1)` → `(0, 2)`.
