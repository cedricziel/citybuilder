---
source = "procedural"
---
## Function

Mediterranean luxury producer. Carriers bring grapes; every 50 ticks the winery turns 2 grapes into 1 wine for patrician houses.

## Visual identity

A whitewashed winery under a low terracotta hip roof with an arched cellar door and shuttered windows, a wooden basket wine press, casks, amphorae and a cypress. Drawn by the procedural building kit in the register pinned by
`world.md` § Building register.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-winery` — canonical operational base
- (0, 1): `building-winery-constructing-0` — stone pad
- (0, 2): `building-winery-constructing-1` — timber frame
- (0, 3): `building-winery-constructing-2` — walls with scaffolding
- (1, 0): `building-winery-operational-0` — operational frame 0
- (1, 1): `building-winery-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.
