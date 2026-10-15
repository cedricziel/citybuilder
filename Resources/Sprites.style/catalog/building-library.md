---
source = "isokit"
---
## Function

Produces knowledge for research: 1 point every 10 ticks while
operational.

## Visual identity

Rendered by IsoKit in the shared light rig. A stone hall under a slate gable roof with three tall lit windows on its south face and a small slate-capped bell turret on the ridge.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-library` — canonical operational base
- (0, 1): `building-library-constructing-0` — stone pad
- (0, 2): `building-library-constructing-1` — timber frame
- (0, 3): `building-library-constructing-2` — walls with scaffolding
- (1, 0): `building-library-operational-0` — operational frame 0
- (1, 1): `building-library-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

Construction stages are cut from the recipe at rising heights, with scaffold on the visible corners; the operational frames repeat the finished building.

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

## Recipe

- Recipe: `building-library` (IsoKit)
- Cell: 2×2 footprint, 128 pt tall
- Construction stages: 3
- Operational frames: 2
