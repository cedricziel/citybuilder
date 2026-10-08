---
source = "procedural"
---
## Function

The Industrial look of the Middle Eastern residential dwelling and its two
upgrades. Shown in place of `building-house-middle-eastern`, `building-house-tier2-middle-eastern` and `building-house-tier3-middle-eastern` in the Industrial age when the player's culture is Middle Eastern. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

Brick blocks with flat tar roofs behind pale-capped parapets, arched ground-floor openings, sash windows and rows of chimneys. Palette anchors: `#A53329`/`#7A1F1A` brick, `#D2C094` caps, `#5C5046` roof deck.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, `age_style("middle-eastern", "industrial")`: the `middle-eastern` culture style with the industrial age's materials and shapes) in the register pinned by `world.md` § Building register. Same 2×2 footprint and bottom anchor as
`building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-industrial-middle-eastern` — canonical operational base: two-storey brick house with a striped awning
- (0, 1): `building-house-tier2-industrial-middle-eastern` — tier 2: three storeys over an arcade, three chimneys
- (0, 2): `building-house-tier3-industrial-middle-eastern` — tier 3: four storeys with an arcade and a mashrabiya bay
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None. Construction uses the shared `building-house-constructing-*`
frames.
