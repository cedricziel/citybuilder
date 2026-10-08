---
source = "procedural"
---
## Function

The Antiquity look of the Middle Eastern residential dwelling and its two
upgrades. Shown in place of `building-house-middle-eastern`, `building-house-tier2-middle-eastern` and `building-house-tier3-middle-eastern` in the Antiquity age when the player's culture is Middle Eastern. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

A mud-brick courtyard house: earthen walls, flat roofs behind low parapets, roof-beam ends poking through the walls, small arched openings and a date palm. Palette anchors: `#8C6A45`/`#5C3F28` mud brick, `#C9A671` parapet caps.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, `age_style("middle-eastern", "antiquity")`: the `middle-eastern` culture style with the antiquity age's materials and shapes) in the register pinned by `world.md` § Building register. Same 2×2 footprint and bottom anchor as
`building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-antiquity-middle-eastern` — canonical operational base: single mud-brick block with roof-beam ends
- (0, 1): `building-house-tier2-antiquity-middle-eastern` — tier 2: two flat-roofed wings around a walled courtyard with a palm
- (0, 2): `building-house-tier3-antiquity-middle-eastern` — tier 3: two-storey house fronted by a timber-columned porch (talar)
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None. Construction uses the shared `building-house-constructing-*`
frames.
