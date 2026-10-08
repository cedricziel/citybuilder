---
source = "procedural"
---
## Function

The Industrial look of the Northern European residential dwelling and its two
upgrades. Shown in place of `building-house`, `building-house-tier2` and `building-house-tier3` in the Industrial age. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

Red-brick terraces: broken brick courses, slate roofs, sash windows under pale lintels and a row of brick chimneys. Palette anchors: `#A53329`/`#7A1F1A` brick, `#7A6B59`/`#3F2A26` slate, `#A89884` lintels.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, `age_style("northern-european", "industrial")`: the `northern-european` culture style with the industrial age's materials and shapes) in the register pinned by `world.md` § Building register. Same 2×2 footprint and bottom anchor as
`building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-industrial` — canonical operational base: pair of terraced cottages under one slate roof with three chimneys
- (0, 1): `building-house-tier2-industrial` — tier 2: three-storey terrace with bay windows
- (0, 2): `building-house-tier3-industrial` — tier 3: tall townhouse with a slate mansard, dormers and three chimneys
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None. Construction uses the shared `building-house-constructing-*`
frames.
