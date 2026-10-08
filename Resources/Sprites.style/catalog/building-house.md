---
source = "procedural"
---
## Function

Low-tier residential dwelling. Houses are the population anchor — every
walker spawns from one. They have no operational animation (no smoke,
no working sound).

## Visual identity

Half-timber-and-plaster cottage with steeply-pitched terracotta-tile
roof. Two-storey but compact silhouette; one south-facing window with
mullions, one south-facing wooden door. Palette anchors: `#D4A86A`
light-wood plaster panels, `#6E4A2A` timber framing in a vertical-stud
pattern, `#7A1F1A` terracotta tile, `#A53329` south-facing roof
highlight band. Tight `#1A1410` outline on south and east edges.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size (1536×1024). Construction
stages on row 0 (right of base); spare cells on row 1.

- (0, 0): `building-house` — canonical operational base
- (0, 1): `building-house-constructing-0` — foundation stage (timber
  sill + corner posts; no walls, no roof)
- (0, 2): `building-house-constructing-1` — framing stage (full
  half-timber skeleton; no plaster, no roof)
- (0, 3): `building-house-constructing-2` — roofing stage (plaster
  filled, roof partly tiled, scaffolding on south face)
- (1, 0): spare (solid magenta `#FF00FF`)
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

Construction-stage progression — not a loop; runs once over build
duration.

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Frames are placed in
  adjacent cells on row 0.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`,
`units.py`) in the register pinned by `world.md` § Building register.
Operational frames keep the finished building and add a rising smoke plume.
The per-cell roles above describe the original AI sprites.
