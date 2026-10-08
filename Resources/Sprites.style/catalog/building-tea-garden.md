---
source = "procedural"
---
## Function

Grows tea leaves for the tea house. East Asian towns only.

## Visual identity

Rows of clipped, rounded tea bushes forming hedges, behind a low fence; a small paper-walled hut with dark posts under an upturned slate roof, a stone lantern and a basket of leaves. Drawn by the procedural building kit in the register pinned by
`world.md` § Building register.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-tea-garden` — canonical operational base
- (0, 1): `building-tea-garden-constructing-0` — stone pad
- (0, 2): `building-tea-garden-constructing-1` — timber frame
- (0, 3): `building-tea-garden-constructing-2` — walls with scaffolding
- (1, 0): `building-tea-garden-operational-0` — operational frame 0
- (1, 1): `building-tea-garden-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.
