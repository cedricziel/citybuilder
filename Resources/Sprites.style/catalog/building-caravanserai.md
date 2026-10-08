---
source = "procedural"
---
## Function

Middle Eastern culture signature. Every 100 ticks a caravan sells up to 4 goods (8 while served coffee) at base price, the chosen export good first.

## Visual identity

A sandstone courtyard: two-storey arcaded wings with parapets on the back sides, a blue-tiled corner dome, a mashrabiya, a tall arched gate in the low front wall, a palm, sacks and a resting camel. Drawn by the procedural building kit in the register pinned by
`world.md` § Building register.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-caravanserai` — canonical idle base (unserved)
- (0, 1): `building-caravanserai-constructing-0` — stone pad
- (0, 2): `building-caravanserai-constructing-1` — timber frame
- (0, 3): `building-caravanserai-constructing-2` — walls with scaffolding
- (1, 0): `building-caravanserai-operational-0` — coffee awning and pots, brazier smoke rising
- (1, 1): `building-caravanserai-operational-1` — coffee awning and pots, brazier smoke drifting
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1. Played only while served.
