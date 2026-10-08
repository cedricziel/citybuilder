---
source = "procedural"
---
## Function

The Modern look of the Middle Eastern residential dwelling and its two
upgrades. Shown in place of `building-house-middle-eastern`, `building-house-tier2-middle-eastern` and `building-house-tier3-middle-eastern` in the Modern age when the player's culture is Middle Eastern. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

Rendered concrete houses with pierced sun screens (a modern mashrabiya), wide glass bands, a sandstone ground floor with a blue band and small blue-tiled domes on the roofs. Palette anchors: `#FFE9C8`/`#A89884` render, `#C9A671` sandstone, `#3F6E94` screens and domes.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, `age_style("middle-eastern", "modern")`: the `middle-eastern` culture style with the modern age's materials and shapes) in the register pinned by `world.md` § Building register. Same 2×2 footprint and bottom anchor as
`building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-modern-middle-eastern` — canonical operational base: single-storey house with a sun screen and a small dome
- (0, 1): `building-house-tier2-modern-middle-eastern` — tier 2: L-shaped house with sun screens
- (0, 2): `building-house-tier3-modern-middle-eastern` — tier 3: five-storey apartment block with screened bays
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None. Construction uses the shared `building-house-constructing-*`
frames.
