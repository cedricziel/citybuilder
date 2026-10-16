---
source = "isokit"
---
## Function

The East Asian look of the low-tier residential dwelling and its two
upgrades. Shown in place of `building-house`, `building-house-tier2`
and `building-house-tier3` when the player's culture is East Asian.
Construction stages stay shared with `building-house`. No operational
animation.

## Visual identity

Rendered by IsoKit in the shared light rig. Pale plaster halls between dark timber posts on a stone base, under wide-eaved slate hip roofs, with a sliding plank door and a lit window. Same 2×2 footprint and bottom anchor as `building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-east-asian` — a single-storey hall under a slate hip roof, straw bales in the yard
- (0, 1): `building-house-tier2-east-asian` — artisans: two storeys, a pent roof skirting the ground floor and a hip roof above
- (0, 2): `building-house-tier3-east-asian` — scholars: three storeys over a dark slate plinth wall, two pent roofs, red-lacquered posts and a crown roof
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None: finished sprites only. Construction uses the shared `building-house-constructing-*` frames.

## Recipe

- Recipe: `building-house-east-asian` (IsoKit)
- Also renders: `building-house-tier2-east-asian`, `building-house-tier3-east-asian`
- Cell: 2×2 footprint, 112 pt tall (tier 2 144 pt, tier 3 176 pt)
- Construction stages: 0
- Operational frames: 0
