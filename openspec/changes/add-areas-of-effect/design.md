## Context

The design canvas for #241 (https://claude.ai/artifact/EGWkZx7VQnvaVKMbbxexN8) compared three styles: ring, wash and spotlight. The coordinator approved A, Ring, with two changes: a dark under-stroke, and trees highlighted on their own nodes instead of marked with diamonds. The approval also covered the count tones and the per-device capsule.

Since #190 the scene keeps node counts low. Plain ground has no sprite, and a tree or rock is one standalone node at its object z. Signature range rings already draw gold diamonds on a layer at z 999.

## Goals / Non-Goals

**Goals:**
- Show a hut's, a forester's and a mine's reach while placing, and a hut's and a forester's reach while selected.
- Keep the overlay's node count fixed, whatever the area's size.
- Take radii from game data.

**Non-Goals:**
- House and market ranges. These come with or after #238 M2.
- Changing any catchment or placement rule.
- Changing the signature range rings.

## Decisions

### D1. The session computes the area; the scene draws it

The open-grass rule needs island ownership, and the mine-site rule needs research and placement checks. Both live on `World`, not on the snapshot. `GameSession.areaOfEffect()` asks the world for the ghost's area, or, with the inspect tool, for the selected building's. The scene polls the result through a new `areaOfEffectProvider`, as it polls the ghost.

The session caches the result by kind, anchor, placing-or-selected and tick, so the 169 site checks for a mine run at most once per tick and cursor move.

Alternative considered: deriving the area in the renderer from the snapshot. That would mean copying the ownership and placement rules into CityRender2D, so it was rejected.

### D2. `AreaOfEffect` in CityCore

`AreaOfEffect` holds two things:
- `tiles`, the set of tiles to outline and tint;
- `targets`, the tiles that count, in row-major order.

Its `count` is the number of targets. For a mine site it is instead the number of terrain-requirement tiles under the ghost's plot, and nil where the plot is not a valid site.

`World.areaOfEffect(of:at:owner:placing:)` builds it:
- **Catchment kind** (`catchmentRadius` set): the tiles are every tile of the footprint grown by the radius, clipped to the map. The targets are the tiles the building would work, the footprint left out, as `catchmentCount` counts them.
- **Terrain-requirement kind while placing:** the tiles are the footprints of every anchor within `AreaOfEffect.siteSearchRadius` (6) of the cursor that passes the site rules. Materials are left out: a short island still shows where the mine could stand. The targets are the tiles of the required terrain among them: the rock a mine could stand on.
- **Any other kind,** or a selected terrain-requirement building: nil.

### D3. Three shape nodes on the ground

`areaLayer` sits at z 4: above the ground backdrop, its shading and the roads (2), and below the routes (5) and everything that stands (10 and up). Trees in front of the area therefore cover its outline, as on the canvas. The layer holds:

1. an under-stroke: the area's outline path, `(20, 14, 0)` at 59% alpha, line width 4;
2. the outline: the same path in the signature ring gold `(1, 0.85, 0.35, 0.8)`, line width 2, filled with gold at 6%;
3. a target fill: one path made of the targets that have no tree or rock on them (a forester's open grass), gold at 16%.

The outline path is the boundary of the tile set: each tile edge with no neighbour in the set, chained into closed loops that keep the area on one side. The loops can be filled, a hole stays unfilled, and the same code serves a rectangle and the ragged union of mine sites.

The paths are rebuilt only when the area changes. An unchanged area costs one `Equatable` check per frame.

### D4. Trees and rock brighten on their own nodes

For each target with a tree or rock on it, the scene finds the object's node, either the tile's own node or its child named `terrain-object`. It gives the node one shared `SKShader` that lifts its colour toward a warm light: colour × 1.3 plus a small warm offset, clamped. A colour blend could only darken the texture, which the first shots showed as no visible change. The shader adds no node; the brightened objects only leave SpriteKit's batch.

Terrain reconcile can rebuild a tile's node, for example on a season change or a pan. So while an area shows, the scene re-applies the shader to every target each frame. For a hut that is at most 32 dictionary lookups. When the area goes or changes, the old targets that are still on screen lose the shader.

Alternative considered: separate marker sprites. These would add nodes, and the canvas showed that marks read as clutter.

### D5. The capsule is SwiftUI, placed over the ghost

`AreaCountCapsule` reads the session's area and the ghost. It places itself with `PlacementHUDLayout.viewPoint`, as the inspector callout and the placement HUD do, centred on the plot and raised by the ghost sprite's height. It is a capsule on `.regularMaterial`, the design system's glass. The sizes are:
- touch: 13 pt, padding 4 × 10;
- Mac: 12 pt, padding 3 × 9;
- Apple TV: 24 pt, padding 8 × 20.

Tones:
- neutral (material) at 5 or more;
- amber (orange at 88%, dark text) at 1–4;
- red (red at 85%, white text) at 0.

The capsule shows only for a ghost whose placement is valid, matching the tool strip's count. It is never interactive (`allowsHitTesting(false)`).

The capsule's bottom sits a fixed roof allowance (`AreaCountCapsuleLayout.roofLift`, 44 pt at zoom 1, plus a 6 pt gap) above the plot's top corner. A 2×2 hut's chimney then clears the capsule, as the shots show.

### D6. Selection keeps its count in the inspector

The inspector callout already shows "Trees in reach: N" next to the building. A selected building therefore shows the ring and the tree highlights but no capsule, which would crowd the callout's pointer.

### D7. Shot flags

`-uiTestPlace lumberjack-hut@34,64` arms the kind. On touch it begins a pending placement at the tile; on the Mac it sets the hovered tile. `-uiTestSelect 36,59` selects the tile with the inspect tool. Both apply after `-uiTestStartGame` commits the session, so before-and-after shots need no input.

## Risks / Trade-offs

- **The Mac pointer can override the hover.** The real pointer's hover replaces the flag's tile once the mouse moves over the window. Shots launch with the pointer elsewhere.
- **The 44 pt roof lift is a constant, not the sprite's height.** Taller buildings put the capsule over their roof. The kinds in scope are all 2×2 workshops of similar height, and the market follow-up can measure the sprite.
- **Brightening lifts the whole clump.** A clump that spans two tiles brightens as one. Each clump belongs to one tile, so a tree out of reach never brightens.
- **Brightened objects leave the batch.** Up to 32 trees for a hut, more rock for a mine's sites, draw outside SpriteKit's batch while the area shows. The rest of the scene is unaffected, and the area shows only while placing or selecting.
