---
source = "procedural"
---
## Function

East Asian culture signature. Houses of citizens and above within 6 tiles of an operational temple garden add 1 extra knowledge per resident every 100 ticks, or 2 while it is served tea.

## Visual identity

Raked gravel around a small shrine on a stone plinth under a dark flared roof, a red gate, a tall stone lantern, a pond and a wind-shaped pine. Drawn by the procedural building kit in the register pinned by
`world.md` § Building register.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-temple-garden` — canonical idle base (unserved)
- (0, 1): `building-temple-garden-constructing-0` — stone pad
- (0, 2): `building-temple-garden-constructing-1` — timber frame
- (0, 3): `building-temple-garden-constructing-2` — walls with scaffolding
- (1, 0): `building-temple-garden-operational-0` — incense smoke, lantern glowing
- (1, 1): `building-temple-garden-operational-1` — incense smoke swaying, lantern glowing
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1. Played only while served.
