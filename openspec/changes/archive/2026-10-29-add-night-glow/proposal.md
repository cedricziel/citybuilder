## Why

At night only house windows light up. Working workshops go as dark as idle ones, and the fire trades show no fire at all. Option A ("Night — Windows and forge glow") on the liveliness design canvas. Part of #127.

## What Changes

- From dusk to dawn, a warm glow flickers at the hearth of every working fire trade: the bakery oven, the smelter furnace, the toolsmith forge and the charcoal pile. "Working" follows the smoke rule: the player's buildings with no issue. The glow brightens with the darkness and flickers slowly, seeded by building id. With Reduce Motion on, the glow is steady.
- Lit windows get a lookup for code-free art. A building lights at night when it is inhabited (houses) or working (other kinds, or a rival's operational building). It shows its `<sprite stem>-lights` texture, additively, when the atlas has one. Houses without one keep today's two panes. The art agent can render `-lights` masks from IsoKit, which knows where the windows are. Workshops light up as those masks land, with no code change.

## Capabilities

### Modified Capabilities
- `rendering-2_5d`: "Night falls on the scene" gains workshop windows and the lights lookup, and "Fire trades glow at night" is added.

## Impact

- **CityRender2D:**
  - The new `FireGlow.swift` holds the hearth table, the code-drawn glow texture and the per-tick reconcile.
  - `updateWindowGlow` covers workshops and the `-lights` lookup, and now runs once per tick.
- **CityCore:** no change.
