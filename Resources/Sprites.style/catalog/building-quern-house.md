---
source = "isokit"
---
## Function

The Antiquity flour mill: grinds 2 grain into 1 flour every 80 ticks by
hand. Available from the start and made obsolete by Milling, which
brings the windmill.

## Visual identity

Rendered by IsoKit in the shared light rig. A rubble-walled workshop under a thatch roof, a hand quern of two millstones on a stone block with an upright handle in the yard, and flour sacks.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-quern-house` — canonical operational base
- (0, 1): `building-quern-house-constructing-0` — stone pad
- (0, 2): `building-quern-house-constructing-1` — timber frame
- (0, 3): `building-quern-house-constructing-2` — walls with scaffolding
- (1, 0): `building-quern-house-operational-0` — handle on the left of the millstone
- (1, 1): `building-quern-house-operational-1` — handle on the right of the millstone
- (1, 2): spare
- (1, 3): spare

## Animation

Construction stages are cut from the recipe at rising heights, with scaffold on the visible corners; the operational frames repeat the finished building.

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1. The building
  stays pixel-identical; only the quern handle moves, so the stone
  reads as turning.

## Recipe

- Recipe: `building-quern-house` (IsoKit)
- Cell: 2×2 footprint, 112 pt tall
- Construction stages: 3
- Operational frames: 2
