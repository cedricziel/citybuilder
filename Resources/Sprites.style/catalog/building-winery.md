---
source = "isokit"
---
## Function

Mediterranean luxury producer. Carriers bring grapes; every 50 ticks the winery turns 2 grapes into 1 wine for patrician houses.

## Visual identity

Rendered by IsoKit in the shared light rig. A whitewashed winery under a low hipped tile roof, a wooden basket press, casks and a cypress.

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

Construction stages are cut from the recipe at rising heights, with scaffold on the visible corners; the operational frames repeat the finished building.

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

## Recipe

- Recipe: `building-winery` (IsoKit)
- Cell: 2×2 footprint, 128 pt tall
- Construction stages: 3
- Operational frames: 2
