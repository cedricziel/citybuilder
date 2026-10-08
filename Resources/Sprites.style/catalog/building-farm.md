---
source = "procedural"
---
## Function

Food producer. Grows grain on its 2×2 footprint with no inputs; a
carrier hauls the harvest to the nearest road-connected goods buffer,
where houses draw it to satisfy their food need.

## Visual identity

A grain field in iso furrows filling the whole footprint, with a small
thatched barn on the back corner. Ripe wheat in `#D4A86A` with `#A07C50`
stalks and `#8B5A2B` row shadows, dark-loam `#3D2A1D` furrows. The barn
has a lit `#D4A86A` south-west wall, a shaded `#A07C50` south-east wall,
a `#8B5A2B` thatch roof, and a `#4A2F1A` door, outlined in `#1A1410`.
Drawn locally by `scripts/generate_sprites_ai/procedural.py`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-farm` — canonical operational base (ripe field, roofed barn)
- (0, 1): `building-farm-constructing-0` — tilled soil, stone pad for the barn
- (0, 2): `building-farm-constructing-1` — seedlings, barn timber frame
- (0, 3): `building-farm-constructing-2` — green crops, barn walls without roof
- (1, 0): `building-farm-operational-0` — ripe wheat, wind band at rest
- (1, 1): `building-farm-operational-1` — ripe wheat, wind band rolled forward
- (1, 2): spare
- (1, 3): spare

## Animation

Two animation loops: construction (one-shot) and operational (forever).

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.
