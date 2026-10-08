---
source = "procedural"
---
## Function

The Renaissance look of the East Asian residential dwelling and its two
upgrades. Shown in place of `building-house-east-asian`, `building-house-tier2-east-asian` and `building-house-tier3-east-asian` in the Renaissance age when the player's culture is East Asian. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

Two-storey townhouses: a dark lattice shopfront, a pent roof, a white plastered upper storey between dark posts and a dark-tiled gable roof. Palette anchors: `#5C5046`/`#3F2A26` lattice and tiles, `#FFE9C8`/`#D2C094` plaster.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, `age_style("east-asian", "renaissance")`: the `east-asian` culture style with the renaissance age's materials and shapes) in the register pinned by `world.md` § Building register. Same 2×2 footprint and bottom anchor as
`building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-renaissance-east-asian` — canonical operational base: two-storey townhouse with a lattice shopfront
- (0, 1): `building-house-tier2-renaissance-east-asian` — tier 2: townhouse with a white fire-proof storehouse behind it
- (0, 2): `building-house-tier3-renaissance-east-asian` — tier 3: merchant's residence on a stone base under a large upturned tiled roof
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None. Construction uses the shared `building-house-constructing-*`
frames.
