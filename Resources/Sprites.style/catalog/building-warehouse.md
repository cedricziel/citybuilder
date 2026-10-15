---
source = "isokit"
---
## Function

Bulk-goods storage building used as a central buffer for the carrier
logistics network. Static silhouette — no operational animation.

## Visual identity

Rendered by IsoKit in the shared light rig. A long storehouse with a rubble ground course and a timber-framed upper band under a slate gable roof, two pairs of cargo doors on the south face, and crates and barrels in the yard.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-warehouse` — canonical operational base
- (0, 1): `building-warehouse-constructing-0` — foundation (stone
  course laid; no walls)
- (0, 2): `building-warehouse-constructing-1` — wall framing (timber
  upper frame; roof open)
- (0, 3): `building-warehouse-constructing-2` — roof going on (slate
  half-laid; scaffolding visible)
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

Construction stages are cut from the recipe at rising heights, with scaffold on the visible corners.

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.

## Recipe

- Recipe: `building-warehouse` (IsoKit)
- Cell: 3×3 footprint, 160 pt tall
- Construction stages: 3
- Operational frames: 0
