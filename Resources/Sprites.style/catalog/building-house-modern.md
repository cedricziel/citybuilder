---
source = "isokit"
---
## Function

The Modern look of the Northern European residential dwelling and its two
upgrades. Shown in place of `building-house`, `building-house-tier2` and `building-house-tier3` in the Modern age. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

Rendered by IsoKit in the shared light rig. Rendered concrete houses with blue glass bands, timber cladding on the ground floor and solar panels on the flat roof. Same 2×2 footprint and bottom anchor as `building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-modern` — a one-storey villa
- (0, 1): `building-house-tier2-modern` — a three-storey house
- (0, 2): `building-house-tier3-modern` — a five-storey apartment block with balconies
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None: finished sprites only. Construction uses the shared `building-house-constructing-*` frames.

## Recipe

- Recipe: `building-house-modern` (IsoKit)
- Also renders: `building-house-tier2-modern`, `building-house-tier3-modern`
- Cell: 2×2 footprint, 112 pt tall (tier 2 160 pt, tier 3 224 pt)
- Construction stages: 0
- Operational frames: 0
