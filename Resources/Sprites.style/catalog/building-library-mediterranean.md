---
source = "isokit"
---
## Function

The Mediterranean look of the research building. Shown in place of
`building-library` when the player's culture is Mediterranean.

## Visual identity

Rendered by IsoKit in the shared light rig. A whitewashed hall under a low tile gable roof with three tall arched lit windows and a bell gable rising over its east end.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-library-mediterranean` — canonical operational base
- (0, 1): spare
- (0, 2): spare
- (0, 3): spare
- (1, 0): `building-library-mediterranean-operational-0` — operational frame 0
- (1, 1): `building-library-mediterranean-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

The operational frames repeat the finished building.

- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1. Frames keep the
  finished building pixel-identical and add a rising smoke plume.
- Construction uses the shared `building-library-constructing-*` frames.

## Recipe

- Recipe: `building-library-mediterranean` (IsoKit)
- Cell: 2×2 footprint, 160 pt tall
- Construction stages: 0
- Operational frames: 2
