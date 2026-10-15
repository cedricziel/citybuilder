---
source = "isokit"
---
## Function

The first building placed on an island — the population and economic
seed. Town centre acts as a goods buffer and as the visual anchor of a
settlement. The 2-frame operational animation shows a flag waving from
its central tower.

## Visual identity

Rendered by IsoKit in the shared light rig. A long ashlar hall under a slate hip roof, with a tall square tower at its east end under a steep slate spire flying a red flag. The whole 3×3 footprint is a cobbled market square with a covered well, two market stalls (red and cream awnings), barrels and crates. The flag hangs furled in one operational frame and flies in the other.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-town-center` — canonical operational base (flag
  at rest)
- (0, 1): `building-town-center-constructing-0` — foundation (stone
  plinth, no walls)
- (0, 2): `building-town-center-constructing-1` — walls up (no tower,
  no roof)
- (0, 3): `building-town-center-constructing-2` — roof + tower
  scaffolded (tower in scaffold; flag pole present but no flag)
- (1, 0): `building-town-center-operational-0` — flag furled (low,
  hugging pole)
- (1, 1): `building-town-center-operational-1` — flag unfurled
  (extended south-east, mid-ripple)
- (1, 2): spare
- (1, 3): spare

## Animation

Two loops: construction (one-shot) and flag-wave (forever).

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Flag-wave: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`,
`units.py`) in the register pinned by `world.md` § Building register.
Operational frames keep the finished building and add a rising smoke plume.
The per-cell roles above describe the original AI sprites.

## Recipe

- Recipe: `building-town-center` (IsoKit)
- Cell: 3×3 footprint, 192 pt tall
- Construction stages: 3
- Operational frames: 2
- Moving part: flag, 2 frames, sweeps right
