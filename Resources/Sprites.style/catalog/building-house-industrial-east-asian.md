---
source = "procedural"
---
## Function

The Industrial look of the East Asian residential dwelling and its two
upgrades. Shown in place of `building-house-east-asian`, `building-house-tier2-east-asian` and `building-house-tier3-east-asian` in the Industrial age when the player's culture is East Asian. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

Brick buildings under upturned slate roofs: pale string courses, arched portals and brick chimneys. Palette anchors: `#A53329`/`#7A1F1A` brick, `#7A6B59`/`#3F2A26` roof, `#A89884` trim.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, `age_style("east-asian", "industrial")`: the `east-asian` culture style with the industrial age's materials and shapes) in the register pinned by `world.md` § Building register. Same 2×2 footprint and bottom anchor as
`building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-industrial-east-asian` — canonical operational base: single-storey brick house with a flared roof and chimney
- (0, 1): `building-house-tier2-industrial-east-asian` — tier 2: two storeys with a balcony and two chimneys
- (0, 2): `building-house-tier3-industrial-east-asian` — tier 3: three-storey brick hall with a clock turret on the roof
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None. Construction uses the shared `building-house-constructing-*`
frames.
