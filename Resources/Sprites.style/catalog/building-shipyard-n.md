---
source = "procedural"
---
## Function

Shore-placement ship producer. Consumes wood + planks from the land
side via carriers; emits Ship entities into the sea. This catalog
entry is the **north-facing** shipyard — sea side is south.

## Visual identity

Stone slipway sloping south into the water, open-sided timber
boat-shed on the inland (north) side housing an in-progress hull on
wooden cradles. Larger silhouette than a port. Palette anchors:
`#7A6B59` stone slipway, `#6E4A2A` timber boat-shed framing, `#4A2F1A`
dark timber hull stock, `#A07C50` plank cradles, `#7A1F1A` terracotta
roof. The 2-frame operational animation shows the hull being worked —
a small sliver of plank moves into place on the second frame.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-shipyard-n` — canonical operational base
- (0, 1): `building-shipyard-n-constructing-0` — slipway formwork
  (stones placed dry; no shed)
- (0, 2): `building-shipyard-n-constructing-1` — slipway built + shed
  posts up; no roof
- (0, 3): `building-shipyard-n-constructing-2` — shed roof framed;
  scaffolding visible
- (1, 0): `building-shipyard-n-operational-0` — hull partly planked,
  no worker tools visible
- (1, 1): `building-shipyard-n-operational-1` — hull with one more
  plank fitted; sawdust puff
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Hull work: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`,
`units.py`) in the register pinned by `world.md` § Building register.
Operational frames keep the finished building and add a rising smoke plume.
The per-cell roles above describe the original AI sprites.
