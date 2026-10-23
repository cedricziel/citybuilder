---
source = "isokit"
---
## Function

Sailing-ship unit sprite. Ships leave shipyards and sail between ports. Eight facings × two frames; the renderer picks the facing from the ship's heading (`ShipRenderMath.facing`) and anchors the sprite at (0.5, 0.3).

## Visual identity

Rendered by IsoKit in the shared light rig. A single-masted cog: a tarred lower hull, dark timber strakes with pointed ends, a plank deck and aft castle, a mast with a yard, and a square cream sail. The hull is about 5 m long, so it fits a tile in every facing. Facings turn the ship, never the camera or the sun.

## Sprites

- `ship-n-0` — facing north, sail drawing
- `ship-n-1` — facing north, sail easing
- `ship-ne-0` — facing north-east, sail drawing
- `ship-ne-1` — facing north-east, sail easing
- `ship-e-0` — facing east, sail drawing
- `ship-e-1` — facing east, sail easing
- `ship-se-0` — facing south-east, sail drawing
- `ship-se-1` — facing south-east, sail easing
- `ship-s-0` — facing south, sail drawing
- `ship-s-1` — facing south, sail easing
- `ship-sw-0` — facing south-west, sail drawing
- `ship-sw-1` — facing south-west, sail easing
- `ship-w-0` — facing west, sail drawing
- `ship-w-1` — facing west, sail easing
- `ship-nw-0` — facing north-west, sail drawing
- `ship-nw-1` — facing north-west, sail easing

## Recipe

- Recipe: `ship-<facing>` (IsoKit), one per facing
- Cell: 1×1 footprint, 72 pt tall
- Facings: e, n, ne, nw, s, se, sw, w
- Frames per facing: 2
- Moving part: sail
