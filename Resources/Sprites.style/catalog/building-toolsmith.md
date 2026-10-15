---
source = "isokit"
---
## Function

Forges tools from iron and planks for merchant houses.

## Visual identity

Rendered by IsoKit in the shared light rig. A half-timbered smithy under a tile roof with a chimney and a lean-to porch, an anvil on a block, a quench barrel and firewood.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-toolsmith` — canonical operational base
- (0, 1): `building-toolsmith-constructing-0` — stone pad
- (0, 2): `building-toolsmith-constructing-1` — timber frame
- (0, 3): `building-toolsmith-constructing-2` — walls with scaffolding
- (1, 0): `building-toolsmith-operational-0` — operational frame 0
- (1, 1): `building-toolsmith-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

Construction stages are cut from the recipe at rising heights, with scaffold on the visible corners; the operational frames repeat the finished building.

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

## Recipe

- Recipe: `building-toolsmith` (IsoKit)
- Cell: 2×2 footprint, 128 pt tall
- Construction stages: 3
- Operational frames: 2
