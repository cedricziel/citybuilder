---
source = "isokit"
---
## Function

Grinds grain into flour.

## Visual identity

Rendered by IsoKit in the shared light rig. A tapering stone tower mill under a conical thatch cap, four sails on its east side, a door at the foot and flour sacks by it.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-windmill` — canonical operational base
- (0, 1): `building-windmill-constructing-0` — stone pad
- (0, 2): `building-windmill-constructing-1` — timber frame
- (0, 3): `building-windmill-constructing-2` — walls with scaffolding
- (1, 0): `building-windmill-operational-0` — operational frame 0
- (1, 1): `building-windmill-operational-1` — operational frame 1
- (1, 2): `building-windmill-operational-2` — operational frame 2
- (1, 3): `building-windmill-operational-3` — operational frame 3

## Animation

Construction stages are cut from the recipe at rising heights, with scaffold on the visible corners; the sails turn through 4 overlay frames.

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)` → `(1, 2)` → `(1, 3)`. Adjacent on row 1.

## Recipe

- Recipe: `building-windmill` (IsoKit)
- Cell: 2×2 footprint, 192 pt tall
- Construction stages: 3
- Operational frames: 4
- Moving part: sails, 4 frames, sweeps right
