---
source = "isokit"
---
## Function

The Industrial look of the Northern European residential dwelling and its two
upgrades. Shown in place of `building-house`, `building-house-tier2` and `building-house-tier3` in the Industrial age. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

Rendered by IsoKit in the shared light rig. Red-brick houses with sash windows and brick chimneys under slate. Same 2×2 footprint and bottom anchor as `building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-industrial` — two brick storeys under a slate gable
- (0, 1): `building-house-tier2-industrial` — a three-storey terrace
- (0, 2): `building-house-tier3-industrial` — a three-storey town house with a slate mansard and dormers
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None: finished sprites only. Construction uses the shared `building-house-constructing-*` frames.

## Recipe

- Recipe: `building-house-industrial` (IsoKit)
- Also renders: `building-house-tier2-industrial`, `building-house-tier3-industrial`
- Cell: 2×2 footprint, 144 pt tall (tier 2 176 pt, tier 3 192 pt)
- Construction stages: 0
- Operational frames: 0
