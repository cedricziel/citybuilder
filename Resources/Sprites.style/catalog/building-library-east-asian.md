---
source = "procedural"
---
## Function

The East Asian look of the research building. Shown in place of
`building-library` when the player's culture is East Asian.

## Visual identity

A long hall on a stone plinth with steps, red-lacquered posts and lattice windows, under one big sweeping slate roof with upturned eaves.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, style `east-asian` in `STYLES`) in the register pinned by `world.md` § Building register. Same 2×2 footprint and bottom anchor as
`building-library`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-library-east-asian` — canonical operational base
- (0, 1): spare
- (0, 2): spare
- (0, 3): spare
- (1, 0): `building-library-east-asian-operational-0` — operational frame 0
- (1, 1): `building-library-east-asian-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1. Frames keep the
  finished building pixel-identical and add a rising smoke plume.
- Construction uses the shared `building-library-constructing-*` frames.
