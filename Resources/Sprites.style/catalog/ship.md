---
source = "isokit"
---
## Function

Sailing-ship unit sprite. Ships leave shipyards and sail between ports. Eight facings × two frames; the renderer picks the facing from the ship's heading (`ShipRenderMath.facing`) and anchors the sprite at (0.5, 0.3).

## Visual identity

Rendered by IsoKit in the shared light rig. A single-masted cog: a tarred lower hull, dark timber strakes with pointed ends, a plank deck and aft castle, a mast with a yard, and a square cream sail. The hull is about 5 m long, so it fits a tile in every facing. Facings turn the ship, never the camera or the sun.

## Sheet

Grid: 8 cols × 2 rows. All 16 cells used.

- (0, 0): `ship-n-0` — facing north, sail drawing
- (0, 1): `ship-n-1` — facing north, sail easing
- (0, 2): `ship-ne-0` — facing north-east, sail drawing
- (0, 3): `ship-ne-1` — facing north-east, sail easing
- (0, 4): `ship-e-0` — facing east, sail drawing
- (0, 5): `ship-e-1` — facing east, sail easing
- (0, 6): `ship-se-0` — facing south-east, sail drawing
- (0, 7): `ship-se-1` — facing south-east, sail easing
- (1, 0): `ship-s-0` — facing south, sail drawing
- (1, 1): `ship-s-1` — facing south, sail easing
- (1, 2): `ship-sw-0` — facing south-west, sail drawing
- (1, 3): `ship-sw-1` — facing south-west, sail easing
- (1, 4): `ship-w-0` — facing west, sail drawing
- (1, 5): `ship-w-1` — facing west, sail easing
- (1, 6): `ship-nw-0` — facing north-west, sail drawing
- (1, 7): `ship-nw-1` — facing north-west, sail easing

## Animation

Eight independent two-frame sail cycles, one per facing: the sail draws, then eases and slackens aft. The hull stays still.

## Recipe

- Recipe: `ship-<facing>` (IsoKit), one per facing
- Cell: 1×1 footprint, 72 pt tall
- Facings: e, n, ne, nw, s, se, sw, w
- Frames per facing: 2
- Moving part: sail
