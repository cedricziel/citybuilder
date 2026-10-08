---
source = "procedural"
---
## Function

Sailing-ship unit sprite. Ships emit from shipyards and traverse water
between ports. Rendered in 8 isometric facings (`n`, `ne`, `e`, `se`,
`s`, `sw`, `w`, `nw`) × 2 animation frames = 16 cells. The renderer
selects facing from the ship's velocity direction.

## Visual identity

Single-masted clinker-built cog with a square cream-linen sail, dark
timber hull below the waterline, lighter timber strakes above. Slight
hull-shadow band where the strakes meet the water. Palette anchors:
`#4A2F1A` hull below waterline, `#6E4A2A` strakes above, `#A07C50`
deck and mast, `#D2C094` sail cream, `#A8CCDD` foam bow-wave (max
2 canonical px). The 2-frame animation shows a gentle sail luff: the
sail eases between two slack positions — no shape inversion, no
rope-detail change.

The catalog uses front-matter `sheet_size = "3072x1024"` and
`cell_grid = "8x2"` so cell pixel dimensions stay at 384×512 to match
walker cells.

## Sheet

Grid: 8 cols × 2 rows. Front-matter overrides: `sheet_size =
"3072x1024"`, `cell_grid = "8x2"`. All 16 cells used.

- (0, 0): `ship-n-0` — facing north, sail luff frame 0
- (0, 1): `ship-n-1` — facing north, sail luff frame 1
- (0, 2): `ship-ne-0` — facing north-east, frame 0
- (0, 3): `ship-ne-1` — facing north-east, frame 1
- (0, 4): `ship-e-0` — facing east, frame 0
- (0, 5): `ship-e-1` — facing east, frame 1
- (0, 6): `ship-se-0` — facing south-east, frame 0
- (0, 7): `ship-se-1` — facing south-east, frame 1
- (1, 0): `ship-s-0` — facing south, frame 0
- (1, 1): `ship-s-1` — facing south, frame 1
- (1, 2): `ship-sw-0` — facing south-west, frame 0
- (1, 3): `ship-sw-1` — facing south-west, frame 1
- (1, 4): `ship-w-0` — facing west, frame 0
- (1, 5): `ship-w-1` — facing west, frame 1
- (1, 6): `ship-nw-0` — facing north-west, frame 0
- (1, 7): `ship-nw-1` — facing north-west, frame 1

## Animation

Eight independent 2-frame sail-luff cycles, one per facing.

- N luff: `(0, 0)` → `(0, 1)`. Adjacent on row 0.
- NE luff: `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- E luff: `(0, 4)` → `(0, 5)`. Adjacent on row 0.
- SE luff: `(0, 6)` → `(0, 7)`. Adjacent on row 0.
- S luff: `(1, 0)` → `(1, 1)`. Adjacent on row 1.
- SW luff: `(1, 2)` → `(1, 3)`. Adjacent on row 1.
- W luff: `(1, 4)` → `(1, 5)`. Adjacent on row 1.
- NW luff: `(1, 6)` → `(1, 7)`. Adjacent on row 1.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`,
`units.py`) in the register pinned by `world.md` § Building register.
Operational frames keep the finished building and add a rising smoke plume.
The per-cell roles above describe the original AI sprites.
