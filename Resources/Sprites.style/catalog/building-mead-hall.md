---
source = "procedural"
---
## Function

Northern European culture signature. Other buildings within 8 tiles of an operational mead hall pay half their upkeep, or none while it is served beer.

## Visual identity

A long log hall under a steep shingle roof whose carved gable boards cross above both ridge ends, a smoke hood on the ridge, red and gold carved door posts, a bench and two barrels. Drawn by the procedural building kit in the register pinned by
`world.md` § Building register.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-mead-hall` — canonical idle base (unserved)
- (0, 1): `building-mead-hall-constructing-0` — stone pad
- (0, 2): `building-mead-hall-constructing-1` — timber frame
- (0, 3): `building-mead-hall-constructing-2` — walls with scaffolding
- (1, 0): `building-mead-hall-operational-0` — smoke from the ridge, doorway lit (left)
- (1, 1): `building-mead-hall-operational-1` — smoke from the ridge, doorway lit (right)
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1. Played only while served.
