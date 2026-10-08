---
source = "procedural"
---
## Function

Grows coffee cherries for the roastery. Middle Eastern towns only.

## Visual identity

Dark, glossy coffee shrubs studded with red cherries, behind a low fence; a small sandstone shed with a flat parapet roof, a date palm and a sack of cherries. Drawn by the procedural building kit in the register pinned by
`world.md` § Building register.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-coffee-grove` — canonical operational base
- (0, 1): `building-coffee-grove-constructing-0` — stone pad
- (0, 2): `building-coffee-grove-constructing-1` — timber frame
- (0, 3): `building-coffee-grove-constructing-2` — walls with scaffolding
- (1, 0): `building-coffee-grove-operational-0` — operational frame 0
- (1, 1): `building-coffee-grove-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.
