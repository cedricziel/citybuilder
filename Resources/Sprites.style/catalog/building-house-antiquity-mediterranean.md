---
source = "procedural"
---
## Function

The Antiquity look of the Mediterranean residential dwelling and its two
upgrades. Shown in place of `building-house-mediterranean`, `building-house-tier2-mediterranean` and `building-house-tier3-mediterranean` in the Antiquity age when the player's culture is Mediterranean. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

A Roman domus: blank travertine walls over a Pompeian-red dado, small openings and a low terracotta hip roof. Palette anchors: `#D2C094`/`#A89884` travertine, `#A53329`/`#7A1F1A` dado and roof tiles.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, `age_style("mediterranean", "antiquity")`: the `mediterranean` culture style with the antiquity age's materials and shapes) in the register pinned by `world.md` § Building register. Same 2×2 footprint and bottom anchor as
`building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-antiquity-mediterranean` — canonical operational base: small domus with a red dado and a low tiled roof
- (0, 1): `building-house-tier2-antiquity-mediterranean` — tier 2: domus with an open compluvium over the atrium pool
- (0, 2): `building-house-tier3-antiquity-mediterranean` — tier 3: domus with a four-column temple-front portico and a peristyle garden open to the sky
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None. Construction uses the shared `building-house-constructing-*`
frames.
