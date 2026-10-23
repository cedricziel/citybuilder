---
source = "isokit"
---
## Function

Low-tier residential dwelling. Houses are the population anchor — every
walker spawns from one. They have no operational animation (no smoke,
no working sound).

## Visual identity

Rendered by IsoKit in the shared light rig. Peasants: a one-storey half-timbered cottage of warm plaster under a steep thatch roof, green shutters, a door on the south face, a woodpile, a fenced cabbage plot and a barrel. Citizens (tier 2): an ashlar ground floor with a jettied, timber-framed plaster upper storey, red shutters, a terracotta tile roof, a chimney and a porch over the door. Merchants (tier 3): an ashlar shop floor, two jettied timber-framed storeys with green shutters, a slate hip roof with two chimneys, and a market awning with goods. Construction runs from plinth and bare frame, to plastered walls, to roof boards, to the thatched house.

## Sprites

- `building-house` — canonical operational base
- `building-house-constructing-0` — foundation stage (timber
  sill + corner posts; no walls, no roof)
- `building-house-constructing-1` — framing stage (full
  half-timber skeleton; no plaster, no roof)
- `building-house-constructing-2` — roofing stage (plaster
  filled, roof partly tiled, scaffolding on south face)
- `building-house-tier2` — citizens: stone ground floor, half-timbered upper storey
- `building-house-tier3` — merchants: three storeys under a slate hip roof

## Recipe

- Recipe: `building-house` (IsoKit)
- Also renders: `building-house-tier2`, `building-house-tier3`
- Cell: 2×2 footprint, 112 pt tall (tier 2: 144 pt, tier 3: 176 pt)
- Construction stages: 3
- Operational frames: 0
