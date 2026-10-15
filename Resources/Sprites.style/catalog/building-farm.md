---
source = "isokit"
---
## Function

Food producer. Grows grain on its 2×2 footprint with no inputs; a
carrier hauls the harvest to the nearest road-connected goods buffer,
where houses draw it to satisfy their food need.

## Visual identity

Rendered by IsoKit in the shared light rig. A plank barn under a thatch roof in the back corner, cabbage beds in dark soil filling the front, a crate and a barrel by the door.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-farm` — canonical operational base (ripe field, roofed barn)
- (0, 1): `building-farm-constructing-0` — tilled soil, stone pad for the barn
- (0, 2): `building-farm-constructing-1` — seedlings, barn timber frame
- (0, 3): `building-farm-constructing-2` — green crops, barn walls without roof
- (1, 0): `building-farm-operational-0` — ripe wheat, wind band at rest
- (1, 1): `building-farm-operational-1` — ripe wheat, wind band rolled forward
- (1, 2): spare
- (1, 3): spare

## Animation

Two animation loops: construction (one-shot) and operational (forever).

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

## Recipe

- Recipe: `building-farm` (IsoKit)
- Cell: 2×2 footprint, 112 pt tall
- Construction stages: 3
- Operational frames: 2
