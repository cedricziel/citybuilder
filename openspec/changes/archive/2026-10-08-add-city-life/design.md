## Context

See proposal.md (Why). The date is derived from `tickCount`; the scene reconciles sprites from snapshots each frame and already animates carriers with walker sprites (`walker-<facing>-<frame>`).

## Decisions

### D1 — Time of day is derived

`TimeOfDay(tick:)` is `(tickCount % 1200) / 1200 + 0.35`, wrapped to 0…1 (0 = midnight), so a new game opens mid-morning rather than in the dark — the first runtime check started at midnight. `TimeOfDay.phase` maps it to night (< 0.2 or ≥ 0.85), dawn (0.2–0.3), day (0.3–0.75) and dusk (0.75–0.85). `TimeOfDay.darkness` is 0 by day, 0.55 at night, and ramps linearly through dawn and dusk. No stored state, so saves don't change.

### D2 — Night overlay

One `SKSpriteNode` the size of the view, parented to the camera, coloured deep blue with `alpha = darkness` and `blendMode = .alpha`, above terrain and buildings but below badges. It's a single node, so cost is constant.

### D3 — Lit windows

Inhabited houses get a child node named `window-glow`: a small warm additive sprite over the facade whose alpha follows `darkness / 0.55`. Added in `makeBuildingNode` when the house has residents; the alpha is updated each frame for present house nodes.

### D4 — Strollers are render-side

`StrollerPlanner.strollers(in: snapshot)` returns, for each inhabited house with an adjacent road, `min(3, residents / 3)` strollers when the phase is day or dusk. Each stroller walks back and forth along the road tiles within 3 tiles of its house; its position is a pure function of `(houseID, index, tickCount)`. The scene keeps a pool of walker nodes keyed by `(houseID, index)` and moves them each frame. Strollers use the existing walker sprites.

### D5 — Resident names

`ResidentNames.list(for: Culture)` holds 24 given names per culture. `World.residentNames(for: house, count:)` picks names by hashing the house's entity ID with the slot index, so a house keeps its residents across saves and launches.

### D6 — Wishes

`HousePopulation.wish(in: Culture) -> Good?` is the first need in `tier.needs(in:)` that is not satisfied. The inspector shows "Astrid · Merchants · wants bread" or "… · content", using the culture's tier name.

## Risks / Trade-offs

- **[Risk] Strollers clutter busy roads** → capped at 3 per house and absent at night.
- **[Risk] The overlay darkens the UI** → it lives in the SpriteKit scene only; SwiftUI HUD stays unaffected.
