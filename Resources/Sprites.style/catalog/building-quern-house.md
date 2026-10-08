---
source = "procedural"
---
## Function

The Antiquity flour mill: grinds 2 grain into 1 flour every 80 ticks by
hand. Available from the start and made obsolete by Milling, which
brings the windmill.

## Visual identity

A small mud-brick workshop under a pale thatch gable roof, a hand quern
in the yard (two stacked millstones on a stone block, turned by an
upright wooden handle, flour spilling from the lower stone) and grain
sacks by the wall. Palette anchors: `#8C6A45`/`#5C3F28` mud brick,
`#D2C094`/`#8B5A2B` thatch, `#A89884`/`#7A6B59`/`#5C5046` millstones.
Drawn by the procedural building kit in the register pinned by
`world.md` § Building register.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-quern-house` — canonical operational base
- (0, 1): `building-quern-house-constructing-0` — stone pad
- (0, 2): `building-quern-house-constructing-1` — timber frame
- (0, 3): `building-quern-house-constructing-2` — walls with scaffolding
- (1, 0): `building-quern-house-operational-0` — handle on the left of the millstone
- (1, 1): `building-quern-house-operational-1` — handle on the right of the millstone
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1. The building
  stays pixel-identical; only the quern handle moves, so the stone
  reads as turning.
