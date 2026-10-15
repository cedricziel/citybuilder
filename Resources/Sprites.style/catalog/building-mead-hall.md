---
source = "isokit"
---
## Function

Northern European culture signature. Other buildings within 8 tiles of an operational mead hall pay half their upkeep, or none while it is served beer.

## Visual identity

Rendered by IsoKit in the shared light rig. A long plank hall under a steep shingle roof with crossed gable boards above both ridge ends, red carved door posts, a bench and two barrels.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-mead-hall` — canonical idle base (unserved)
- (0, 1): `building-mead-hall-constructing-0` — stone pad
- (0, 2): `building-mead-hall-constructing-1` — timber frame
- (0, 3): `building-mead-hall-constructing-2` — walls with scaffolding
- (1, 0): `building-mead-hall-operational-0` — operational frame 0
- (1, 1): `building-mead-hall-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

Construction stages are cut from the recipe at rising heights, with scaffold on the visible corners; the operational frames repeat the finished building.

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1. Played only while served.

## Recipe

- Recipe: `building-mead-hall` (IsoKit)
- Cell: 3×3 footprint, 176 pt tall
- Construction stages: 3
- Operational frames: 2
