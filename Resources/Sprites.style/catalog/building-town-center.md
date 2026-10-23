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

## Sprites

- `building-town-center` — canonical operational base (flag
  at rest)
- `building-town-center-constructing-0` — foundation (stone
  plinth, no walls)
- `building-town-center-constructing-1` — walls up (no tower,
  no roof)
- `building-town-center-constructing-2` — roof + tower
  scaffolded (tower in scaffold; flag pole present but no flag)
- `building-town-center-operational-0` — flag furled (low,
  hugging pole)
- `building-town-center-operational-1` — flag unfurled
  (extended south-east, mid-ripple)

## Recipe

- Recipe: `building-town-center` (IsoKit)
- Cell: 3×3 footprint, 192 pt tall
- Construction stages: 3
- Operational frames: 2
- Moving part: flag, 2 frames, sweeps right
