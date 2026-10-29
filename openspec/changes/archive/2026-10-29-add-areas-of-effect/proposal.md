## Why

A lumberjack hut works the forest within 2 tiles of its plot, and a forester plants open grass in the same reach, but the map never shows that reach. Players place a hut, watch it idle and only then learn the trees were one tile too far. A mine needs rock under its plot, and the only feedback is a red ghost. The tool strip names a count, but at the edge of the screen and with no picture of which tiles count. Issue #241 asks the map itself to show what a building reaches, while placing and while selecting.

## What Changes

- **Catchment radius becomes game data.** Buildings get an optional `catchmentRadius` field. The lumberjack hut and the forester set it to 2, which replaces the `World.lumberjackCatchmentRadius` constant. Behaviour is unchanged.
- **One area-of-effect query in CityCore.** For a kind at an anchor, the world returns:
  - the tiles to outline;
  - the tiles that count: trees for a hut, open grass for a forester;
  - while placing a building with a terrain requirement (the mine), every tile of a valid site within 6 tiles of the cursor, with its rock as the tiles that count.
  The query is read-only.
- **Option A, Ring, from the design canvas.**
  - The area lies on the ground under the trees: a gold outline over a dark under-stroke, so it holds on sand and snow, with a 6% gold tint.
  - Trees in reach brighten in place: their existing nodes share one shader that lifts them toward a warm light.
  - A forester's open grass takes a stronger tint.
  - Mine sites get the outline and tint, and their rock brightens like the trees.
  - The whole overlay is at most three shape nodes, never one node per tile, so #190's performance holds.
- **Placing and selecting both show the overlay.** The ghost of an armed hut, forester or mine shows it, and so does a selected hut or forester. The selected building's count stays in the inspector, which already shows it.
- **A count capsule rides on the ghost.**
  - It is a glass capsule just above the ghost's roof: "18 trees in reach", "12 open grass in reach" or "Mine site: 4 rock tiles".
  - Its tone is neutral at 5 or more, amber at 1–4 and red at 0. It warns and never blocks.
  - Type is 13 pt on touch, 12 pt on the Mac and 24 pt on Apple TV.
  - It shows only where the building could go.
- **Debug launch flags for shots.** `-uiTestPlace kind@x,y` arms a building at a tile, and `-uiTestSelect x,y` selects a tile. Before-and-after shots then need no input.
- **Not in this change:** the house and market ranges. They land with or after #238 M2, in a follow-up that adds a teal "serves" style to the same overlay.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `forestry`: adds "Catchment radius is game data".
- `rendering-2_5d`: adds "Areas of effect while placing and selecting".
- `platform-shells`: adds "Count capsule over the ghost".

## Impact

- **Game data:**
  - `GameDataGen` learns `catchmentRadius`: model, loader, schema, validator, emitter, tests and FORMAT.md.
  - `core.yaml` sets it on the hut and the forester.
  - `BuildingKind+Generated.swift` is regenerated.
- **CityCore:**
  - The catchment helpers take the building kind and read its radius.
  - New `World+AreaOfEffect.swift`.
  - `World.lumberjackCatchmentRadius` goes.
- **CityRender2D:**
  - New `IsoWorldScene+AreaOfEffect.swift`.
  - The scene and `IsoWorldView` get an `areaOfEffectProvider`.
  - `GatherWorkers` reads the radius from data.
- **CityUI:**
  - `GameSession.areaOfEffect()`.
  - A new `AreaCountCapsule` overlay in the root view.
  - The renderer factory gets the provider.
  - `UITestSeed` gets the shot flags.
- **Apps:** the three app shells pass the provider through.
- **Determinism and saves:** none. The radius keeps its value, and the queries do not change the world.
