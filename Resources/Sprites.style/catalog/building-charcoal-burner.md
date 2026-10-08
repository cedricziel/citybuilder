---
source = "procedural"
---
## Function

Burns wood into charcoal for the smelter.

## Visual identity

A small timber hut beside a turf-covered charcoal clamp and stacked logs. Drawn by the procedural building kit in the register pinned by
`world.md` § Building register.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-charcoal-burner` — canonical operational base
- (0, 1): `building-charcoal-burner-constructing-0` — stone pad
- (0, 2): `building-charcoal-burner-constructing-1` — timber frame
- (0, 3): `building-charcoal-burner-constructing-2` — walls with scaffolding
- (1, 0): `building-charcoal-burner-operational-0` — operational frame 0
- (1, 1): `building-charcoal-burner-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.
