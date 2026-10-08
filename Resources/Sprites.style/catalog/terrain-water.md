---
source = "procedural"
---
## Function

Non-walkable water tile. Ships path across water; carriers never enter.
Shore buildings face water on one or more cardinal sides.

## Visual identity

Deep-coastal water in three blue-grey bands: deep mid-tone field, a
slightly lighter horizontal band suggesting current, and a sparse
highlight glint pattern. Palette anchors: `#2A4E6E` deep base, `#3F6E94`
mid, `#6FA4C2` highlight band, `#A8CCDD` glint dots (used sparingly at
≤20% dither). No ships, no foam crests except on the very tile.

## Sheet

Grid: 5 cols × 1 rows. Cells 512×512 sheet pixels on a 2560×512 canvas
(front-matter `sheet_size = "2560x512"` override).

- (0, 0): `terrain-water` — canonical static base
- (0, 1): `terrain-water-0` — animation frame 0 (glint pattern A)
- (0, 2): `terrain-water-1` — animation frame 1 (glint pattern B)
- (0, 3): `terrain-water-2` — animation frame 2 (glint pattern C)
- (0, 4): `terrain-water-3` — animation frame 3 (glint pattern D)

## Animation

Four-frame water glint cycle at ~0.20s per frame.

- Glint cycle: `(0, 1)` → `(0, 2)` → `(0, 3)` → `(0, 4)`. All frames
  are placed in adjacent cells on row 0.
