---
source = "isokit"
---
## Function

The East Asian look of the research building. Shown in place of
`building-library` when the player's culture is East Asian.

## Visual identity

Rendered by IsoKit in the shared light rig. A pale hall on a stone plinth behind a row of red lacquered posts, under one big hipped slate roof.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-library-east-asian` — canonical operational base
- (0, 1): spare
- (0, 2): spare
- (0, 3): spare
- (1, 0): `building-library-east-asian-operational-0` — operational frame 0
- (1, 1): `building-library-east-asian-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

The operational frames repeat the finished building.

- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1. Frames keep the
  finished building pixel-identical and add a rising smoke plume.
- Construction uses the shared `building-library-constructing-*` frames.

## Recipe

- Recipe: `building-library-east-asian` (IsoKit)
- Cell: 2×2 footprint, 144 pt tall
- Construction stages: 0
- Operational frames: 2
