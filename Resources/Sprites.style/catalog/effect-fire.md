---
source = "isokit"
---
## Function

The flames on a burning building: a row of flame tongues along the ridge
that the renderer sets on the roof, sized to the footprint, with a small
copy licking out of a window, flickering through three frames
(still on frame 0 under Reduce Motion). The smoke column and the glow are
particles and a light sprite in the game. Spec: `rendering-2_5d` / Seasonal
events are drawn on the map.

## Visual identity

Rendered by IsoKit with the self-lit flame finish, the one finish that
ignores the light rig, so a fire reads the same by day and at night. Seven
tongues along a ridge running +x, tallest in the middle; each is three flat,
curved, tapering shapes facing the camera (dark red outside, orange, a pale
core), bent with the wind in an S, flickering in height and bend between
frames; flat shading and no cast shadow. Design canvas:
https://claude.ai/artifact/NfTHPHsBMu4gKzjgvxYfz5 (Fire, option A).

## Sprites

- `effect-fire-0`
- `effect-fire-1`
- `effect-fire-2`

## Recipe

- Recipe: `effect-fire` (IsoKit)
- Cell: 80×80 pt, the row's middle at (40, 14) pt
- Frames: 3
- Moving part: flames
