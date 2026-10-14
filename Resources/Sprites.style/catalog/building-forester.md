---
source = "procedural"
---
## Function

Forest-planting building. The forester turns open grass within 2 tiles
of its footprint into forest, one tile per cycle, so the lumberjack hut
beside it never runs out of trees. It needs no road and stores no
goods. The operational animation shows a working building from a
distance.

## Visual identity

A small one-room timber shed with a thatch roof, smaller than the
lumberjack hut, in the north corner of its yard. Rows of young
conifers fill the rest of the yard: the nursery the forester plants
from. Palette anchors: `#6E4A2A` timber frame, `#8B5A2B` thatch roof,
`#3F5C26` sapling shade and `#5C8038` sapling light.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-forester` — canonical operational base
- (0, 1): `building-forester-constructing-0` — foundation (stone pad)
- (0, 2): `building-forester-constructing-1` — frame raised (timber
  posts, no roof)
- (0, 3): `building-forester-constructing-2` — walls up under
  scaffolding, no saplings yet
- (1, 0): `building-forester-operational-0` — finished shed and
  nursery
- (1, 1): `building-forester-operational-1` — same, with a smoke wisp
- (1, 2): spare
- (1, 3): spare

## Animation

Two animation loops: construction (one-shot) and operational (forever).

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`,
`units.py`) in the register pinned by `world.md` § Building register.
Operational frames keep the finished building and add a rising smoke plume.
