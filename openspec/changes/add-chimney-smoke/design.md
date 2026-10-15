## Context

Liveliness work splits into small renderer-only changes. This is the first of them, and it sets up the shared pieces the later changes reuse: the ambient layer, the zoom budget and Reduce Motion.

## Decisions

### D1: The planner is a pure function of the snapshot

`ChimneyPlanner.sources(in:)` returns one source per smoking building: its id, anchor, kind, texture stem and style (smoke or steam). The rules:
- A house smokes when it is operational and has residents.
- A bakery, smelter, toolsmith or charcoal burner smokes when it is operational and has no building issue.
- A brewery steams under the same rule.

The planner reads nothing but the snapshot, so it never feeds back into the simulation.

### D2: Chimney positions come from a table

The building sprites are lit 3D renders, and a chimney often overlaps its roof in silhouette, so a chimney cannot be found from the alpha mask. `ChimneyAnchors` maps a texture stem to the chimney top as fractions of the sprite (x from the left, y from the top). The values were measured on the IsoKit renders. A stem missing from the table falls back to the top centre of the roof. That fallback covers the legacy culture and age variants, many of which have a smoke hole and no chimney. When IsoKit recipes move a chimney, its row in the table changes with them.

### D3: One ambient layer with a pooled, capped set of emitters

`AmbientLayerNode` sits above the buildings and below the carriers (z 40). It re-plans only when the tick, the visible tile range, the budget or Reduce Motion changes. A pan inside the same tiles costs nothing, because sprites stay put in the scene while the camera moves. The scene keeps an index of building sprites by anchor next to `presentSprites`, so placing a plume does not scan every sprite. Planned sources are culled to the visible tile range and sorted: working buildings first, then by distance to the camera centre, then by id. The list is cut to the budget `clamp(Int(24 × zoom), 8, 40)`. Removed emitters go back to a pool and are reused. Each emitter lives for 3 s at about 3 puffs per second, so the screen never holds more than about 500 puffs.

### D4: Reduce Motion

`IsoWorldScene.reduceMotion` halves the birth rate and the rise speed of every ambient emitter. `IsoWorldView` sets it from `accessibilityReduceMotion`.

### D5: Procedural puff

The puff is a 16 px soft radial gradient drawn with Core Graphics once and cached. Colour and alpha are set per style: warm grey for smoke, near-white for steam. The night overlay tints puffs like everything else.

## Risks

- The table goes stale when house art changes. The fallback still puts smoke on the roof. A follow-up could have IsoKit emit the chimney point as sprite metadata, since the recipe knows where the chimney is.
- Which kinds have a fire is a switch in the renderer. A follow-up could move it into the game-data packs as a building trait.
