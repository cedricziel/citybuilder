---
source = "isokit"
---
## Function

Antiquity age signature. An operational monument works on a 25-stage project fed with wood, planks and bread; once complete, the city's taxes rise by 10%. Until then the construction frames show the project's progress.

## Visual identity

Rendered by IsoKit in the shared light rig. A stepped travertine podium carrying a temple front of six columns under a tiled pediment, with a bronze brazier on the steps.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-monument` — canonical idle base
- (0, 1): `building-monument-constructing-0` — stepped podium
- (0, 2): `building-monument-constructing-1` — columns standing in scaffolding
- (0, 3): `building-monument-constructing-2` — roofless colonnade
- (1, 0): `building-monument-operational-0` — operational frame 0
- (1, 1): `building-monument-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

Construction stages are cut from the recipe at rising heights, with scaffold on the visible corners; the operational frames repeat the finished building.

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

## Recipe

- Recipe: `building-monument` (IsoKit)
- Cell: 3×3 footprint, 160 pt tall
- Construction stages: 3
- Operational frames: 2
