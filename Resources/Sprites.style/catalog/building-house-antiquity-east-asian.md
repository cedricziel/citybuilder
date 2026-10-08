---
source = "procedural"
---
## Function

The Antiquity look of the East Asian residential dwelling and its two
upgrades. Shown in place of `building-house-east-asian`, `building-house-tier2-east-asian` and `building-house-tier3-east-asian` in the Antiquity age when the player's culture is East Asian. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

A simple timber hall on a stone base: earthen walls between dark posts under a steep thatched roof whose eaves turn up. Palette anchors: `#8C6A45`/`#5C3F28` daub, `#4A2F1A` posts, `#D2C094`/`#8B5A2B` thatch.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, `age_style("east-asian", "antiquity")`: the `east-asian` culture style with the antiquity age's materials and shapes) in the register pinned by `world.md` § Building register. Same 2×2 footprint and bottom anchor as
`building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-antiquity-east-asian` — canonical operational base: thatched hall on a low stone base
- (0, 1): `building-house-tier2-antiquity-east-asian` — tier 2: larger hall beside a granary raised on stilts
- (0, 2): `building-house-tier3-antiquity-east-asian` — tier 3: great hall on a tall stone podium with red columns under a wide dark-tiled roof
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None. Construction uses the shared `building-house-constructing-*`
frames.
