---
source = "isokit"
---
## Function

The Mediterranean look of the low-tier residential dwelling and its two
upgrades. Shown in place of `building-house`, `building-house-tier2`
and `building-house-tier3` when the player's culture is Mediterranean.
Construction stages stay shared with `building-house`. No operational
animation.

## Visual identity

Rendered by IsoKit in the shared light rig. Whitewashed houses under low terracotta hip roofs, no timber framing, blue-shuttered windows. Same 2×2 footprint and bottom anchor as `building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-mediterranean` — a cottage with a blue door, a whitewashed chimney with a tile cap, and amphorae
- (0, 1): `building-house-tier2-mediterranean` — citizens: two whitewashed storeys over an arcaded ground-floor loggia
- (0, 2): `building-house-tier3-mediterranean` — patricians: three storeys on a stone ground floor, an arched portal, an iron-railed balcony and a belvedere tower with an open loggia
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None: finished sprites only. Construction uses the shared `building-house-constructing-*` frames.

## Recipe

- Recipe: `building-house-mediterranean` (IsoKit)
- Also renders: `building-house-tier2-mediterranean`, `building-house-tier3-mediterranean`
- Cell: 2×2 footprint, 112 pt tall (tier 2 144 pt, tier 3 176 pt)
- Construction stages: 0
- Operational frames: 0
