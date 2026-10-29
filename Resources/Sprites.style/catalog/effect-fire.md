---
source = "isokit"
---
## Function

The flames on a burning building: a cluster of flame tongues the renderer
sets on the roof, sized to the footprint, flickering through three frames
(still on frame 0 under Reduce Motion). The smoke column and the glow are
particles and a light sprite in the game. Spec: `rendering-2_5d` / Seasonal
events are drawn on the map.

## Visual identity

Rendered by IsoKit with the self-lit flame finish, the one finish that
ignores the light rig, so a fire reads the same by day and at night. Each
tongue is three nested cones, dark red outside, orange, and a pale yellow
core, leaning with the wind; no cast shadow. Design canvas:
https://claude.ai/artifact/NfTHPHsBMu4gKzjgvxYfz5 (Fire, option A).

## Sprites

- `effect-fire-0`
- `effect-fire-1`
- `effect-fire-2`

## Recipe

- Recipe: `effect-fire` (IsoKit)
- Cell: 80×64 pt, cluster base at (40, 8) pt
- Frames: 3
- Moving part: flames
