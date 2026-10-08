---
source = "procedural"
---
## Function

The Renaissance look of the Mediterranean residential dwelling and its two
upgrades. Shown in place of `building-house-mediterranean`, `building-house-tier2-mediterranean` and `building-house-tier3-mediterranean` in the Renaissance age when the player's culture is Mediterranean. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

Ochre stucco palazzi: a rusticated stone base, a pale cornice under a low terracotta hip roof and regular rows of shuttered windows. Palette anchors: `#D4A86A`/`#A07C50` stucco, `#A89884`/`#7A6B59` base, `#3F6E94` shutters.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, `age_style("mediterranean", "renaissance")`: the `mediterranean` culture style with the renaissance age's materials and shapes) in the register pinned by `world.md` § Building register. Same 2×2 footprint and bottom anchor as
`building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-renaissance-mediterranean` — canonical operational base: two-storey palazzetto with a stone base and cornice
- (0, 1): `building-house-tier2-renaissance-mediterranean` — tier 2: three storeys over an arcaded ground floor
- (0, 2): `building-house-tier3-renaissance-mediterranean` — tier 3: palazzo with pilasters, an arched portal and a roof-top loggia tower
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None. Construction uses the shared `building-house-constructing-*`
frames.
