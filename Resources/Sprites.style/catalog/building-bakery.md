---
source = "procedural"
---
## Function

Bread producer. Carriers bring food from a goods buffer; every 50 ticks
the bakery turns 2 food into 1 bread for merchant houses.

## Visual identity

A plastered, half-timbered bakehouse under a terracotta gable roof, with
a domed brick oven and its own stone flue against the east wall, and
flour crates by the door. Drawn by the procedural building kit in the
register pinned by `world.md` § Building register.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-bakery` — canonical operational base
- (0, 1): `building-bakery-constructing-0` — stone pad
- (0, 2): `building-bakery-constructing-1` — timber frame
- (0, 3): `building-bakery-constructing-2` — walls with scaffolding
- (1, 0): `building-bakery-operational-0` — smoke from the flue, frame 0
- (1, 1): `building-bakery-operational-1` — smoke from the flue, frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.
