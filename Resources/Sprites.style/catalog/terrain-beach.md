## Function

Walkable sand band one tile wide between grass interior and water.
Carriers cross beach freely; shore buildings (port, shipyard) anchor on
the inland-side of a beach tile.

## Visual identity

Pale warm sand with a hint of pebble dither near the water edge.
Slight tonal banding suggests gentle wave-line erosion. Palette anchors:
`#C9A671` sand core, `#8C6A45` damp-sand shadow at the seaward edge,
`#A8CCDD` thin foam line (only on animation cells). No driftwood, no
shells.

## Sheet

Grid: 3 cols × 1 rows. Cells 512×512 sheet pixels on a 1536×512 canvas.

- (0, 0): `terrain-beach` — canonical static base
- (0, 1): `terrain-beach-0` — animation frame 0 (foam line low)
- (0, 2): `terrain-beach-1` — animation frame 1 (foam line crest)

## Animation

Foam line lap loop at ~0.45s per frame.

- Foam lap: `(0, 1)` → `(0, 2)`. Adjacent on row 0.
