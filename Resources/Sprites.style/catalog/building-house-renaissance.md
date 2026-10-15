---
source = "isokit"
---
## Function

The Renaissance look of the Northern European residential dwelling and its two
upgrades. Shown in place of `building-house`, `building-house-tier2` and `building-house-tier3` in the Renaissance age. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

Rendered by IsoKit in the shared light rig. A whitewashed stucco town house on a stone ground floor, gable to the street with a stepped gable, green shutters and a tile roof. Same 2×2 footprint and bottom anchor as `building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-renaissance` — a two-storey town house
- (0, 1): `building-house-tier2-renaissance` — a broader merchant's house
- (0, 2): `building-house-tier3-renaissance` — a three-storey guild house
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None: finished sprites only. Construction uses the shared `building-house-constructing-*` frames.

## Recipe

- Recipe: `building-house-renaissance` (IsoKit)
- Also renders: `building-house-tier2-renaissance`, `building-house-tier3-renaissance`
- Cell: 2×2 footprint, 160 pt tall (tier 2 176 pt, tier 3 208 pt)
- Construction stages: 0
- Operational frames: 0
