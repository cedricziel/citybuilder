---
source = "procedural"
---
## Function

The Modern look of the Mediterranean residential dwelling and its two
upgrades. Shown in place of `building-house-mediterranean`, `building-house-tier2-mediterranean` and `building-house-tier3-mediterranean` in the Modern age when the player's culture is Mediterranean. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

White rendered villas and apartments: flat roofs, wide glass bands, balconies, a roof-top pergola, parasol and pool. Palette anchors: `#FFE9C8`/`#A89884` render, `#6FA4C2`/`#3F6E94` glass and pool.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, `age_style("mediterranean", "modern")`: the `mediterranean` culture style with the modern age's materials and shapes) in the register pinned by `world.md` § Building register. Same 2×2 footprint and bottom anchor as
`building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-modern-mediterranean` — canonical operational base: single-storey villa with a roof-top pergola
- (0, 1): `building-house-tier2-modern-mediterranean` — tier 2: L-shaped villa with a roof-top pool
- (0, 2): `building-house-tier3-modern-mediterranean` — tier 3: five-storey apartment block with stacked balconies
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None. Construction uses the shared `building-house-constructing-*`
frames.
