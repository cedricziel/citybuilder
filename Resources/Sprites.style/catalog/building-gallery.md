---
source = "isokit"
---
## Function

Renaissance age signature. A paid commission inspires houses within 8 tiles to grow faster for 1,200 ticks; the banner only flies while a commission runs.

## Visual identity

Rendered by IsoKit in the shared light rig. An ochre palazzo over a three-arched stone arcade, a statue niche between the upper windows, a travertine cornice under a low tile roof, and a red banner on a pole.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-gallery` — canonical idle base
- (0, 1): `building-gallery-constructing-0` — stone pad
- (0, 2): `building-gallery-constructing-1` — timber frame
- (0, 3): `building-gallery-constructing-2` — walls with scaffolding
- (1, 0): `building-gallery-operational-0` — operational frame 0
- (1, 1): `building-gallery-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

Construction stages are cut from the recipe at rising heights, with scaffold on the visible corners; the operational frames repeat the finished building.

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

## Recipe

- Recipe: `building-gallery` (IsoKit)
- Cell: 2×2 footprint, 144 pt tall
- Construction stages: 3
- Operational frames: 2
