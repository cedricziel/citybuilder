## Why

The HUD covers too much of the map. A full-width stats panel with a scrolling stocks row sits at the top, a 2×3 grid of round buttons next to it, one long scrolling row with every building below that, and the inspector in the bottom-left corner, far from the building it describes. On an iPhone in landscape the world shows through a thin band in the middle. The "HUD Redesign" mock in Claude Design (direction B, "Map-first") moves every piece to the edges and makes most of them appear only when needed.

## What Changes

- **Status pill:** one capsule at the top center holds the date, money, population, island name and the speed control. Tapping the island name opens and closes the island's stocks tray under the pill. The stocks row no longer shows all the time.
- **Menus:** Goals, Research, Standings, Routes and Settings sit in one row at the top right.
- **Game speed:** the speed control offers pause, 1×, 2× and 3×. On a phone one button steps through the speeds. At speed n each timer firing advances the world n ticks.
- **Build rail and dock:** in landscape the build controls are a rail on the left edge; in portrait they are a dock at the bottom. Both hold three categories (Town, Gather, Craft), then Road and Demolish. A category opens a drawer of building tiles (sprite, name, cost, lock). Picking a tile arms the tool and closes the drawer. On the Mac, 1, 2 and 3 open the drawers, R arms the road and X arms demolish.
- **Tool strip:** while a tool is armed, a strip at the bottom shows its sprite, name, cost, a one-line hint, the material chips for the island under the camera, and a cancel button. It replaces the armed caption and the hover-only cost row.
- **Inspector callout:** the inspector is a callout next to the selected building, to its right in landscape and below it in portrait, kept on screen. It shows the building's name and its key lines, Details shows the rest, and Demolish removes the building.
- **BREAKING (spec):** `platform-shells` / Adaptive HUD per idiom now picks rail or dock by orientation instead of "sidebar on iPad, bottom sheet on iPhone".

Out of scope: the placement HUD, rejection banner, session banner and sheets keep their current look; no new art; the 3D portrait renderer is untouched.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `platform-shells`: adaptive HUD layout by orientation, status pill and stocks tray, game speed, build categories with rail, dock and drawers, rail hotkeys, tool strip, inspector callout.

## Impact

- **CityUI:** new status pill, build rail/dock/drawer, tool strip and inspector callout views; `BuildCategory`, `BuildRailModel`, `GameSpeed`, `HUDDock`, `InspectorCalloutLayout`, `BuildingIconLoader`; `GameSession.speed`, `armedCostBreakdown`, `demolishSelection()`; `InspectorViewModel.title` and `keyLines`; `HUDViewModel` stocks tray state. `CityRootView` is re-laid out. `HUDFrameView` and `BuildPaletteView` are replaced.
- **CityCore, CityRender2D, CityPersistence, Apps:** none. Speed is session state and is never saved.
- No new build-time tools.
