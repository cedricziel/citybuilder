## Function

UI icon for the `wood` good. Used in the goods bar, building tooltips,
and the warehouse buffer indicator. Single static cell.

## Visual identity

A short stack of three rough-cut logs seen at the same 30° south-east
camera tilt as every other sprite. Brown bark exterior with one
cross-section of light pine end-grain visible. No bark texture detail
finer than 2 canonical pixels. Palette anchors: `#6E4A2A` bark,
`#A07C50` pine end-grain, `#5C3F28` bark shadow.

Front-matter override: `sheet_size = "256x256"`, `cell_grid = "1x1"`.
Downsamples to 24×24 canonical pixels using nearest-neighbour (no
anti-alias) per design.md §Q2.

## Sheet

Grid: 1 cols × 1 rows. Cell is 256×256 sheet pixels.

- (0, 0): `good-wood` — static icon

## Animation

Static — no animation loop.
