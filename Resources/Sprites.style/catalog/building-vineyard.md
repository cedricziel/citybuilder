---
source = "procedural"
---
## Function

Grows grapes for the winery. Mediterranean towns only.

## Visual identity

Rows of low trained vines on stakes with dark red grape clusters, behind a low fence; a small whitewashed hut under a terracotta hip roof, a cypress and amphorae. Drawn by the procedural building kit in the register pinned by
`world.md` § Building register.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-vineyard` — canonical operational base
- (0, 1): `building-vineyard-constructing-0` — stone pad
- (0, 2): `building-vineyard-constructing-1` — timber frame
- (0, 3): `building-vineyard-constructing-2` — walls with scaffolding
- (1, 0): `building-vineyard-operational-0` — operational frame 0
- (1, 1): `building-vineyard-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.
