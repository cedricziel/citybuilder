---
source = "procedural"
---
## Function

Generic land-walking unit sprite used by every walker class (carrier,
lumberjack, etc.) at this milestone. Renders in 4 isometric facings
(`ne`, `se`, `sw`, `nw`) × 2 animation frames = 8 cells. The renderer
selects facing from the walker's velocity direction.

## Visual identity

Stylised peasant figure: brown tunic, grey trousers, soft cap. Built
from 4–6 visible canonical pixels tall (silhouette over detail). Face
is implied — never rendered with eyes or mouth. Palette anchors:
`#6E4A2A` tunic, `#5C5046` trousers, `#A89884` skin tint, `#8B5A2B`
cap. Outline `#1A1410` on the south and east edges of the silhouette.
The two animation frames show a left-leg / right-leg step cycle.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size. All 8 cells used.

- (0, 0): `walker-ne-0` — facing north-east, step frame 0
- (0, 1): `walker-ne-1` — facing north-east, step frame 1
- (0, 2): `walker-se-0` — facing south-east, step frame 0
- (0, 3): `walker-se-1` — facing south-east, step frame 1
- (1, 0): `walker-sw-0` — facing south-west, step frame 0
- (1, 1): `walker-sw-1` — facing south-west, step frame 1
- (1, 2): `walker-nw-0` — facing north-west, step frame 0
- (1, 3): `walker-nw-1` — facing north-west, step frame 1

## Animation

Four independent 2-frame step cycles, one per facing. All frame-pairs
are placed in adjacent cells.

- NE step: `(0, 0)` → `(0, 1)`. Adjacent on row 0.
- SE step: `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- SW step: `(1, 0)` → `(1, 1)`. Adjacent on row 1.
- NW step: `(1, 2)` → `(1, 3)`. Adjacent on row 1.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`,
`units.py`) in the register pinned by `world.md` § Building register.
Operational frames keep the finished building and add a rising smoke plume.
The per-cell roles above describe the original AI sprites.
