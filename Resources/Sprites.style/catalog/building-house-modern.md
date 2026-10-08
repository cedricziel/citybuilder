---
source = "procedural"
---
## Function

The Modern look of the Northern European residential dwelling and its two
upgrades. Shown in place of `building-house`, `building-house-tier2` and `building-house-tier3` in the Modern age. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

Rendered concrete villas and apartments: flat roofs, wide blue glass bands, balconies, timber cladding on the ground floor and solar panels on the roof. Palette anchors: `#FFE9C8`/`#A89884` render, `#6FA4C2`/`#3F6E94` glass, `#A07C50` cladding.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, `age_style("northern-european", "modern")`: the `northern-european` culture style with the modern age's materials and shapes) in the register pinned by `world.md` § Building register. Same 2×2 footprint and bottom anchor as
`building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-modern` — canonical operational base: single-storey villa with a glass band and a car port
- (0, 1): `building-house-tier2-modern` — tier 2: L-shaped villa with a three-storey wing
- (0, 2): `building-house-tier3-modern` — tier 3: five-storey apartment block with stacked balconies
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None. Construction uses the shared `building-house-constructing-*`
frames.
