---
source = "isokit"
---
## Function

The Antiquity look of the Mediterranean residential dwelling and its two
upgrades. Shown in place of `building-house-mediterranean`, `building-house-tier2-mediterranean` and `building-house-tier3-mediterranean` in the Antiquity age when the player's culture is Mediterranean. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

Rendered by IsoKit in the shared light rig. Three steps up: a daub hut under reed thatch, a domus of pale stucco over a Pompeian-red dado under tile behind a yard wall, and a domus with a columned portico. Same 2×2 footprint and bottom anchor as `building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-antiquity-mediterranean` — a daub hut under reed thatch
- (0, 1): `building-house-tier2-antiquity-mediterranean` — a domus with a red dado behind a yard wall
- (0, 2): `building-house-tier3-antiquity-mediterranean` — a domus with a columned portico under tile
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None: finished sprites only. Construction uses the shared `building-house-constructing-*` frames.

## Recipe

- Recipe: `building-house-antiquity-mediterranean` (IsoKit)
- Also renders: `building-house-tier2-antiquity-mediterranean`, `building-house-tier3-antiquity-mediterranean`
- Cell: 2×2 footprint, 112 pt tall (tier 2 112 pt, tier 3 112 pt)
- Construction stages: 0
- Operational frames: 0
