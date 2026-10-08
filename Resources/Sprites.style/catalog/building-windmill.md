---
source = "procedural"
---
## Function

Grinds grain into flour.

## Visual identity

A stone tower mill under a thatched hip roof with four turning sails. Drawn by the procedural building kit in the register pinned by
`world.md` § Building register.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-windmill` — canonical operational base
- (0, 1): `building-windmill-constructing-0` — stone pad
- (0, 2): `building-windmill-constructing-1` — timber frame
- (0, 3): `building-windmill-constructing-2` — walls with scaffolding
- (1, 0): `building-windmill-operational-0` — operational frame 0
- (1, 1): `building-windmill-operational-1` — operational frame 1
- (1, 2): `building-windmill-operational-2` — operational frame 2
- (1, 3): `building-windmill-operational-3` — operational frame 3

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)` → `(1, 2)` → `(1, 3)`. Adjacent on row 1.
