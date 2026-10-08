---
source = "procedural"
---
## Function

Middle Eastern luxury producer. Carriers bring coffee cherries; every 50 ticks the roastery turns 2 coffee cherries into 1 coffee for merchant houses.

## Visual identity

A sandstone roastery with a parapet roof and a blue-tiled dome, a striped awning, an iron roasting drum on a brick firebox with a crank, coffee sacks and a date palm. Drawn by the procedural building kit in the register pinned by
`world.md` § Building register.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-roastery` — canonical operational base
- (0, 1): `building-roastery-constructing-0` — stone pad
- (0, 2): `building-roastery-constructing-1` — timber frame
- (0, 3): `building-roastery-constructing-2` — walls with scaffolding
- (1, 0): `building-roastery-operational-0` — operational frame 0
- (1, 1): `building-roastery-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.
