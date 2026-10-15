---
source = "isokit"
---
## Function

Grows coffee cherries for the roastery. Middle Eastern towns only.

## Visual identity

Rendered by IsoKit in the shared light rig. A sandstone shed with a parapet roof, dark glossy coffee shrubs with red cherries in rows, and a date palm.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-coffee-grove` — canonical operational base
- (0, 1): `building-coffee-grove-constructing-0` — stone pad
- (0, 2): `building-coffee-grove-constructing-1` — timber frame
- (0, 3): `building-coffee-grove-constructing-2` — walls with scaffolding
- (1, 0): `building-coffee-grove-operational-0` — operational frame 0
- (1, 1): `building-coffee-grove-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

## Recipe

- Recipe: `building-coffee-grove` (IsoKit)
- Cell: 2×2 footprint, 128 pt tall
- Construction stages: 3
- Operational frames: 2
