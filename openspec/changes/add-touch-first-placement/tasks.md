## 1. M1 — Intent extension and IsoDirection (CityRender2D)

- [x] 1.1 Tests-first: translate `#### Scenario: IsoDirection NE moves ghost up-right by one tile`, `#### Scenario: IsoDirection SE moves ghost down-right by one tile`, `#### Scenario: IsoDirection SW moves ghost down-left by one tile`, `#### Scenario: IsoDirection NW moves ghost up-left by one tile`, and `#### Scenario: Long-press point translates to long-press intent at the tile under the touch` into failing tests in `CityRender2DTests`. Confirm red.
- [x] 1.2 Implement to green: add `IsoDirection` enum with `tileOffset` property; extend `Intent` with `.longPressTile(TileCoordinate)`, `.confirmPlacement`, `.cancelPlacement`, `.nudgePlacement(direction: IsoDirection)`; add `InputTranslator.longPressIntent(atScreenPoint:mapWidth:mapHeight:)` paralleling `tapIntent`.
- [x] 1.3 Refactor under a green bar.

## 2. M2 — Long-press recognizer on iOS scene (CityRender2D)

- [x] 2.1 Tests-first: translate `#### Scenario: Long-press inside map bounds dispatches longPressTile intent` and `#### Scenario: Long-press outside map bounds dispatches no intent` into failing tests in `CityRender2DTests` that exercise the gesture-recognizer callback directly (no live UIKit; call the dispatch path with a fake touch location).
- [x] 2.2 Implement to green: in `IsoWorldScene` add a `UILongPressGestureRecognizer` to the SKView on `didMove(to:)` with `minimumPressDuration = 0.4`. Wire its `.began` action to call `dispatchLongPress(at:)` which uses the existing `tile(forScene:mapWidth:mapHeight:)` helper and emits `.longPressTile(coord)` via `intentSink`. Mac code path unchanged.
- [x] 2.3 Refactor under a green bar.

## 3. M3 — PendingPlacement state on GameSession (CityUI)

- [x] 3.1 Tests-first: translate `#### Scenario: beginPendingPlacement sets the pending state with the requested kind and anchor`, `#### Scenario: nudgePendingPlacement moves the anchor along the iso direction`, `#### Scenario: nudgePendingPlacement is clamped to map bounds`, `#### Scenario: confirmPendingPlacement enqueues a place command at the pending anchor`, `#### Scenario: confirmPendingPlacement clears the pending state`, `#### Scenario: cancelPendingPlacement clears the pending state without enqueuing`, `#### Scenario: handleTap is suppressed while a placement is pending`, and `#### Scenario: ghostState reads from pendingPlacement when set` into failing tests in `CityUITests`. Confirm red.
- [x] 3.2 Implement to green: add `PendingPlacement` struct and `GameSession.pendingPlacement` property; implement `beginPendingPlacement(kind:at:)`, `nudgePendingPlacement(_:)`, `confirmPendingPlacement()`, `cancelPendingPlacement()`; gate `handleTap` to no-op while pending; route `ghostState()` through `pendingPlacement.anchor` when set; ensure `selectedTool` is unchanged by the new methods.
- [x] 3.3 Refactor under a green bar.

## 4. M4 — Tile context menu view-model (CityUI)

- [x] 4.1 Tests-first: translate `#### Scenario: Menu lists all building kinds except road as separate entries`, `#### Scenario: Road menu entry arms the place tool without entering pending state`, `#### Scenario: Unaffordable buildings appear disabled in the menu`, `#### Scenario: Demolish entry appears only when tile holds a player-owned building`, and `#### Scenario: Menu emits dismiss for inspect entry` into failing tests in `CityUITests`. Confirm red.
- [x] 4.2 Implement to green: add `TileMenuViewModel` that takes `(tile: TileCoordinate, world: World, money: Int64)` and produces an array of `TileMenuItem` values (`.build(BuildingKind, enabled: Bool)`, `.demolish`, `.dismiss`); add `TileMenuChoice` for the selection callback (`.build(BuildingKind)`, `.demolish`, `.dismiss`); wire menu choices through `GameSession.applyMenuChoice(_:at:)` which calls either `beginPendingPlacement`, sets `selectedTool = .place(.road)`, enqueues `.demolish`, or no-ops for dismiss.
- [x] 4.3 Refactor under a green bar.

## 5. M5 — Long-press intent → menu presentation (CityUI)

- [x] 5.1 Tests-first: translate `#### Scenario: Long-press intent opens the tile menu request on iOS`, `#### Scenario: Menu Build choice for a non-road kind enters pending placement`, and `#### Scenario: Menu Build choice for road arms the road place tool` into failing tests in `CityUITests`.
- [x] 5.2 Implement to green: extend `GameSession` with `tileMenuRequest: TileMenuRequest?` (a published binding for the SwiftUI dialog) and `handleLongPress(at:)` that sets `tileMenuRequest = TileMenuRequest(tile: tile)`. Wire the long-press intent in the renderer-intent dispatcher path (the closure already exists for `tapTile`). Implement `TileContextMenuPresenter` SwiftUI view conditional on `#if os(iOS)` and attach it to `worldView`.

## 6. M6 — Placement HUD with iso arrows and checkmark (CityUI + CityRender2D)

- [ ] 6.1 Tests-first: translate `#### Scenario: PlacementHUD renders four arrow buttons positioned around the pending tile`, `#### Scenario: PlacementHUD checkmark button dispatches confirmPlacement`, `#### Scenario: PlacementHUD cancel button dispatches cancelPlacement`, and `#### Scenario: PlacementHUD arrow button dispatches the matching nudgePlacement direction` into failing tests in `CityUITests`. Cover the HUD as a small ViewModel + scenario assertions on the callback dispatch; do not assert SwiftUI view geometry.
- [x] 6.2 Implement to green: add `PlacementHUDViewModel` exposing `arrows: [IsoDirection]`, `confirmEnabled: Bool`, `cancelEnabled: Bool`, plus selection callbacks. Add `PlacementHUD` SwiftUI view that subscribes to `GameSession.pendingPlacement` and renders four arrow buttons + a central ✓ + a cancel ✕. The view anchors to the pending tile via `IsoMath` conversion of `pendingPlacement.anchor` to scene coordinates and from there to SwiftUI overlay coordinates.
- [x] 6.3 Refactor under a green bar.

## 7. M7 — Palette path also routes through pending placement on iOS (CityUI)

- [x] 7.1 Tests-first: translate `#### Scenario: Palette-armed building tap enters pending placement on iOS` and `#### Scenario: Palette-armed road tap or drag paints immediately on iOS` into failing tests in `CityUITests`.
- [x] 7.2 Implement to green: in `GameSession.handleTap(at:)`, when running on iOS and the armed tool is `.place(kind)` with `kind != .road`, instead of enqueuing immediately call `beginPendingPlacement(kind:at:)`. Road and demolish keep the existing immediate-place behavior. Wrap the new branch in `#if os(iOS)`; macOS continues commit-on-click.

## 8. M8 — First-run coach mark (CityUI)

- [x] 8.1 Tests-first: translate `#### Scenario: First-run coach mark shows once and is dismissable` and `#### Scenario: Coach mark does not show after dismissal flag is set` into failing tests in `CityUITests` that drive the `CoachmarkStore` directly (UserDefaults-backed with an injectable provider).
- [x] 8.2 Implement to green: add a small `CoachmarkStore` with a single `hasSeenTouchPlacementHint: Bool` property backed by `UserDefaults` (injected protocol for tests). On iOS `CityRootView`, show a one-time overlay ("Long-press a tile to build") that flips the flag on dismiss. macOS path skips the coach mark.

## 9. M9 — Audit and update existing tests for the new commit semantics on iOS

- [ ] 9.1 Audit `CityUITests` and `CityRender2DTests` for places that exercise palette-arm-then-tap on iOS. Those tests must either: (a) call `confirmPendingPlacement()` after the tap to drive the new flow end-to-end, or (b) be re-scoped to Mac semantics where commit-on-click still applies, or (c) call the underlying `handleTap` path with the platform-condition disabled. Document the chosen strategy at the top of each updated test file.
- [ ] 9.2 Confirm `make test` passes across every package.

## 10. M10 — Polish + docs

- [ ] 10.1 README: short "Touch placement" section explaining the long-press → menu → arrows → ✓ flow. Cross-link to the BuildPaletteView and to `add-build-materials-cost` for the cost-breakdown story.
- [ ] 10.2 Final `make test && make lint && make format`.
- [ ] 10.3 Visual playtest on iPad simulator: long-press a tile, pick House, nudge, confirm. Long-press a tile, pick Road, drag. Long-press a built tile, pick Demolish. — DEFERRED (interactive).
- [ ] 10.4 Visual playtest on iPhone simulator (portrait + landscape): same flows, verify hit targets ≥ 44 pt and that the PlacementHUD doesn't overlap the inspector or pause button. — DEFERRED (interactive).
- [ ] 10.5 Verify `make test-scenarios` is clean for the rendering-2_5d and buildings-and-construction capabilities after this change.
