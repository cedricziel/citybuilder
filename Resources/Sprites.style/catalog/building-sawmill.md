## Function

Wood-to-planks producer. A sawmill consumes wood from adjacent storage
and emits planks. The 4-frame operational animation shows a vertical
sawblade rising and falling — the most visible "industry is running"
signal in the world.

## Visual identity

Two-storey timber building with a stone lower course. South-facing
open-fronted work shed showing a vertical-saw frame. Pitched terracotta
roof over the milling chamber. Pile of fresh-cut planks (light wood)
neatly stacked east of the building. Palette anchors: `#7A6B59` stone
plinth, `#6E4A2A` timber frame, `#A07C50` plank stack and saw frame
timber, `#5C5046` iron saw-blade, `#7A1F1A` terracotta roof.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size. All 8 cells used.

- (0, 0): `building-sawmill` — canonical operational base (saw at rest,
  centred)
- (0, 1): `building-sawmill-constructing-0` — foundation (stone
  plinth, corner posts)
- (0, 2): `building-sawmill-constructing-1` — frame raised (full
  timber skeleton, no walls)
- (0, 3): `building-sawmill-constructing-2` — walled + roofing (wall
  planks installed, half-tiled roof)
- (1, 0): `building-sawmill-operational-0` — saw blade up (top of
  stroke)
- (1, 1): `building-sawmill-operational-1` — saw blade upper-mid
- (1, 2): `building-sawmill-operational-2` — saw blade lower-mid
- (1, 3): `building-sawmill-operational-3` — saw blade down (cut
  contact; small sawdust puff)

## Animation

Two loops: construction (one-shot) and operational (forever, 4 frames).

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)` → `(1, 2)` → `(1, 3)`. All four
  frames are placed in adjacent cells on row 1.
