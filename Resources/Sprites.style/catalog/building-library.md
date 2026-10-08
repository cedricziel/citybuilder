---
source = "procedural"
---
## Function

Produces knowledge for research: 1 point every 10 ticks while
operational.

## Visual identity

A stone hall with tall narrow windows under a slate gable roof and a
small bell turret. Drawn by the procedural building kit in the register
pinned by `world.md` § Building register.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-library` — canonical operational base
- (0, 1): `building-library-constructing-0` — stone pad
- (0, 2): `building-library-constructing-1` — timber frame
- (0, 3): `building-library-constructing-2` — walls with scaffolding
- (1, 0): `building-library-operational-0` — operational frame 0
- (1, 1): `building-library-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.
