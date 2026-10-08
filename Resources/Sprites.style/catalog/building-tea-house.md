---
source = "procedural"
---
## Function

East Asian luxury producer. Carriers bring tea leaves; every 50 ticks the tea house turns 2 tea leaves into 1 tea for scholar houses.

## Visual identity

A post-and-beam pavilion on a stone plinth with a timber deck, red lacquered veranda posts under a wide, upturned dark roof, red paper lanterns and a steaming kettle on the veranda. Drawn by the procedural building kit in the register pinned by
`world.md` § Building register.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-tea-house` — canonical operational base
- (0, 1): `building-tea-house-constructing-0` — stone pad
- (0, 2): `building-tea-house-constructing-1` — timber frame
- (0, 3): `building-tea-house-constructing-2` — walls with scaffolding
- (1, 0): `building-tea-house-operational-0` — operational frame 0
- (1, 1): `building-tea-house-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.
