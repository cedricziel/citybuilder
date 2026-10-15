---
source = "isokit"
---
## Function

Grows grain for the windmill.

## Visual identity

Rendered by IsoKit in the shared light rig. A plank barn under a thatch roof, standing grain in narrow drill rows of uneven height, sheaves on the cut headland, and a fence on the visible edges.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-grain-farm` — canonical operational base
- (0, 1): `building-grain-farm-constructing-0` — stone pad
- (0, 2): `building-grain-farm-constructing-1` — timber frame
- (0, 3): `building-grain-farm-constructing-2` — walls with scaffolding
- (1, 0): `building-grain-farm-operational-0` — operational frame 0
- (1, 1): `building-grain-farm-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

## Recipe

- Recipe: `building-grain-farm` (IsoKit)
- Cell: 2×2 footprint, 112 pt tall
- Construction stages: 3
- Operational frames: 2
