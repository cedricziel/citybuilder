---
source = "procedural"
---
## Function

The Modern look of the East Asian residential dwelling and its two
upgrades. Shown in place of `building-house-east-asian`, `building-house-tier2-east-asian` and `building-house-tier3-east-asian` in the Modern age when the player's culture is East Asian. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

Rendered concrete houses with wide glass bands, a dark panelled ground floor and a flared dark-tiled roof canopy on top. Palette anchors: `#FFE9C8`/`#A89884` render, `#5C5046`/`#3F2A26` panels and roof, `#6FA4C2`/`#3F6E94` glass.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, `age_style("east-asian", "modern")`: the `east-asian` culture style with the modern age's materials and shapes) in the register pinned by `world.md` § Building register. Same 2×2 footprint and bottom anchor as
`building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-modern-east-asian` — canonical operational base: single-storey house under a flared tiled roof
- (0, 1): `building-house-tier2-modern-east-asian` — tier 2: L-shaped house with a flared roof on the tall wing
- (0, 2): `building-house-tier3-modern-east-asian` — tier 3: five-storey apartment block crowned by a flared roof
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None. Construction uses the shared `building-house-constructing-*`
frames.
