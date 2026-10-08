---
source = "procedural"
---
## Function

The Industrial look of the Mediterranean residential dwelling and its two
upgrades. Shown in place of `building-house-mediterranean`, `building-house-tier2-mediterranean` and `building-house-tier3-mediterranean` in the Industrial age when the player's culture is Mediterranean. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

Brick apartment houses with a stone base and cornice, iron-railed balconies, a low slate hip roof and several chimneys. Palette anchors: `#A53329`/`#7A1F1A` brick, `#A89884` stone trim, `#7A6B59`/`#3F2A26` slate.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, `age_style("mediterranean", "industrial")`: the `mediterranean` culture style with the industrial age's materials and shapes) in the register pinned by `world.md` § Building register. Same 2×2 footprint and bottom anchor as
`building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-industrial-mediterranean` — canonical operational base: two-storey brick house with a balcony
- (0, 1): `building-house-tier2-industrial-mediterranean` — tier 2: three storeys over an arcaded stone ground floor
- (0, 2): `building-house-tier3-industrial-mediterranean` — tier 3: four-storey block with two balcony rows
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None. Construction uses the shared `building-house-constructing-*`
frames.
