---
source = "isokit"
---
## Function

The Antiquity look of the Northern European residential dwelling and its two
upgrades. Shown in place of `building-house`, `building-house-tier2` and `building-house-tier3` in the Antiquity age. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

Rendered by IsoKit in the shared light rig. A stone longhouse under a deep thatch hip roof, a rubble chimney and a log pile. Same 2×2 footprint and bottom anchor as `building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-antiquity` — a one-room longhouse
- (0, 1): `building-house-tier2-antiquity` — a larger longhouse
- (0, 2): `building-house-tier3-antiquity` — a chieftain's hall with a timber-posted porch
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None: finished sprites only. Construction uses the shared `building-house-constructing-*` frames.

## Recipe

- Recipe: `building-house-antiquity` (IsoKit)
- Also renders: `building-house-tier2-antiquity`, `building-house-tier3-antiquity`
- Cell: 2×2 footprint, 128 pt tall (tier 2 128 pt, tier 3 128 pt)
- Construction stages: 0
- Operational frames: 0
