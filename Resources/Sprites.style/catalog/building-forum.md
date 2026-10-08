---
source = "procedural"
---
## Function

Mediterranean culture signature. Houses within 8 tiles of an operational forum pay 1 extra tax per resident, or 2 while it is served wine.

## Visual identity

A paved square framed on its two back sides by white colonnades under terracotta tiles, a bronze statue on a plinth, a fountain, amphorae and a cypress. Drawn by the procedural building kit in the register pinned by
`world.md` § Building register.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-forum` — canonical idle base (unserved)
- (0, 1): `building-forum-constructing-0` — stone pad
- (0, 2): `building-forum-constructing-1` — timber frame
- (0, 3): `building-forum-constructing-2` — walls with scaffolding
- (1, 0): `building-forum-operational-0` — striped market stalls, fountain sparkling
- (1, 1): `building-forum-operational-1` — stall stripes swapped, fountain sparkling
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1. Played only while served.
