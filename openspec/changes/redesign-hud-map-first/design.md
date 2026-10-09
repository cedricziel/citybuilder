## Context

See proposal.md (Why). The target is direction B ("Map-first") of the Claude Design project's `HUD Redesign.html`, refined by the handoff bundle `design_handoff_hud_map_first/` (its `README.md` is the spec of record for sizes, materials and behavior). What exists today:

- `CityRootView` stacks `HUDFrameView` (date, money, population, island, always-on stocks row) and `hudButtons` (a 2×3 grid of round buttons) at the top, `BuildPaletteView` (one scrolling row of every kind plus Demolish) below them, the armed caption, and `InspectorView` in the bottom-left corner.
- `GameSession` ticks the world from a 10 Hz `Timer` through `step()`. `ghostState()` computes the material chips only for the hovered tile, so touch players never see them before tapping.
- `PlacementHUDLayout.viewPoint(forTile:camera:viewSize:)` already projects a tile to view coordinates for the placement HUD.
- Building sprites live in the `Buildings` atlas as `building-<rawValue>`; port and shipyard use a facing suffix (`-s`).

## Goals / Non-Goals

**Goals:** the map is the screen. Every HUD piece sits on an edge and the ones that are not always needed (stocks, drawers, tool strip, inspector) appear only when asked for. One layout works on iPhone, iPad and Mac in both orientations.

**Non-Goals:** restyling sheets, banners or the placement HUD; new art; saving the speed.

## Decisions

### D1 — Rail or dock by orientation, not by idiom

`HUDDock.placement(for: CGSize)` returns `.leftRail` when the view is wider than tall and `.bottomDock` otherwise. `CityRootView` reads the size from a `GeometryReader`. A phone in landscape has height to spare at the side and none at the bottom; an iPad in portrait has the reverse. The old `LayoutDecisions.palettePlacement` (`.sidebar` / `.bottomSheet` / `.topBar` by size class) is removed; `LayoutDecisions` keeps its other fields.

- **Alternative — keep size classes.** Rejected: an iPhone in landscape reports compact height and regular width on large models, so the size class does not say where the room is.

### D1a — One `HUDLayout` value

`HUDLayout.make(size:isPhone:isTouch:)` bundles the placement with the idiom rules from the handoff: a phone hides rail labels and the date, uses the single speed button, folds the menus into a More menu in portrait, and uses an 8 pt margin (16 pt elsewhere). Rail width, control height and drawer columns come from it too. It is a pure struct, so every rule is unit-tested; views read it instead of checking the idiom themselves.

### D2 — Three categories from an exhaustive switch

`BuildCategory` has `town`, `gather` and `craft`. `BuildCategory.of(_ kind:)` is an exhaustive `switch` over `BuildingKind` returning nil for road (its own rail item) and the town center (never offered). Gather holds raw producers (lumberjack hut, farm, grain farm, mine, hop garden, vineyard, tea garden, coffee grove); Craft holds processors (sawmill, windmill, quern house, bakery, charcoal burner, smelter, toolsmith, brewery, winery, roastery, steam engine, power plant); Town holds the rest. A new kind fails to compile until it has a category. `kinds(in:isHidden:)` filters `BuildPalette.visibleKinds`, so obsolete and other-culture kinds stay out.

- **Alternative — a category field on `BuildingSpec` in CityCore.** Rejected: the grouping is a UI concern and CityCore stays free of it.

### D3 — `BuildRailModel` holds the drawer

A value type with `openDrawer: BuildCategory?`. `toggle(_:)` opens a category or closes it when it is already open. `arm(_:in:)` hands the tool to `GameSession.selectTool` and closes the drawer; a locked kind does nothing and leaves the drawer open. `GameSession.selectTool` clears the selection whenever it arms a build or demolish tool, so the callout never lingers behind an armed tool. The root view closes the drawer when a sheet opens. `highlightedCategory(armed:)` is the open drawer, or with none open the armed kind's category, so the rail shows where the armed tool came from. The view keeps the model in `@State`.

### D4 — Speed is a multiplier on the timer, not on tick length

`GameSession.speed: GameSpeed` (`.normal`, `.double`, `.triple`; raw values 1, 2, 3). The timer calls `timerFired()`, which calls `step()` `speed.rawValue` times. Commands still apply at tick boundaries and the 10 Hz tick stays 10 Hz of game time, so the world after n ticks is the same at any speed. `GameSpeed.next` steps 1 → 2 → 3 → 1 for the phone's single button. `GameSession.choose(speed:)` and `stepSpeed()` also clear `isPaused`, as the handoff asks. Pause stays `isPaused`, which opens the pause menu as before.

**Determinism:** speed only changes how many ticks run per wall-clock second. The tick function and its inputs are unchanged, so replay produces byte-identical worlds.

### D5 — Material chips without hover

`GameSession.armedCostBreakdown` is `ghostState()?.costBreakdown` when the pointer hovers, otherwise the breakdown at the camera-center tile. The tool strip shows it on touch devices before the first tap. Nil for road, demolish and inspect.

### D6 — The callout is positioned in SwiftUI from the existing projection

`InspectorCalloutLayout.place(anchor:buildingHalfSize:calloutSize:bounds:placement:)` returns the callout's origin and the side it sits on. In the rail layout it tries the building's right edge + 14 pt, vertically centered, and flips to the left edge when it would cross `bounds`; in the dock layout it tries 12 pt below the building and flips above. The result is then clamped into `bounds`, the area the pill, menus, rail and dock leave free inside the safe area. The anchor and the building's half size come from `PlacementHUDLayout.viewPoint` for the footprint's corner tiles, so the callout follows the camera.

`InspectorViewModel` gains `title` ("House"), `tier` and `residentsFill` for houses, and `keyLines`: residents and needs for a house, otherwise state and road. The callout shows title, tier, a residents meter and key lines; Details (state kept on `CityRootView`, so it survives selection changes) adds every other bullet; the commission, export, market and route controls stay visible. Demolish calls `GameSession.demolishSelection()`, which enqueues `.demolish(at:)` for the selected tile and clears the selection. Rival buildings get no Demolish.

- **Alternative — publish a selection rect from `SnapshotHostView`** (the handoff's suggestion). Rejected for now: CityUI already owns the same projection, and the renderer factory would need another closure through both app shells. If the 3D renderer ever drives this view, revisit.

### D7 — Stocks tray state lives on `HUDViewModel`

`isStocksTrayOpen` plus `toggleStocksTray()`; `stocksTray` is `stocksRow` while open and empty while closed. Keeping it on the view-model makes the toggle testable and survives view rebuilds.

### D8 — Sprites through a `BuildingIconLoader`

Mirrors `GoodIconLoader`: the `Buildings` atlas, `building-<rawValue>` (`-s` for port and shipyard), nearest-neighbor interpolation, and an SF Symbol fallback (`building.2.fill`, `road.lanes` for the road) when the atlas lacks the texture, which is always the case in package tests.

## Risks / Trade-offs

- [Callout hides the map next to the building] → it is 220 pt wide and only shows while a building is selected; tapping empty ground clears it.
- [Triple speed runs three ticks per timer firing on slow devices] → a tick is well under a millisecond on current hardware; the perf overlay shows tick time if it ever matters.
- [Players used to the long palette row] → hotkeys 1/2/3, R and X on the Mac, and the drawers show every kind with its cost.
- [iPhone landscape sheets are not the handoff's 380 pt trailing panel] → SwiftUI has no trailing sheet; phones get `.presentationDetents([.fraction(0.62), .large])`, which landscape shows full height.
- [Removing `palettePlacement` breaks callers] → only `PlatformLayoutTests` read it; they move to `HUDDock`.
