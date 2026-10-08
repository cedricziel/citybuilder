---
source = "procedural"
---
## Function

Antiquity age signature. An operational monument works on a 25-stage project fed with wood, planks and bread; once complete, the city's taxes rise by 10%. Until then the construction frames show the project's progress.

## Visual identity

A stepped stone podium carrying a travertine temple front of six columns under a terracotta pediment, with a bronze brazier on the steps. Drawn by the procedural building kit in the register pinned by
`world.md` § Building register.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-monument` — canonical idle base
- (0, 1): `building-monument-constructing-0` — stepped podium
- (0, 2): `building-monument-constructing-1` — columns standing in scaffolding
- (0, 3): `building-monument-constructing-2` — roofless colonnade
- (1, 0): `building-monument-operational-0` — brazier flame leaning east
- (1, 1): `building-monument-operational-1` — brazier flame flaring
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.
