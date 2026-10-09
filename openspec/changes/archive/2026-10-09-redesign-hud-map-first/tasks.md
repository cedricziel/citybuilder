## 1. M1 — HUD models (CityUI)

- [x] 1.1 Tests-first: translate every platform-shells scenario in this change into failing `CityUITests`; rewrite the "iPad sidebar HUD" and "iPhone compact HUD" tests against `HUDDock`. Confirm red.
- [x] 1.2 Implement to green: `HUDDock` placement by view size; drop `LayoutDecisions.palettePlacement` (design D1).
- [x] 1.3 Implement to green: `BuildCategory`, `BuildPalette` (renamed from `BuildPaletteView`'s statics), `BuildRailModel`, rail hotkeys (design D2, D3).
- [x] 1.4 Implement to green: `GameSpeed`, `GameSession.speed` and `timerFired()` (design D4).
- [x] 1.5 Implement to green: `GameSession.armedCostBreakdown`, tool strip hint text (design D5).
- [x] 1.6 Implement to green: `InspectorViewModel.title` and `keyLines`, `InspectorCalloutLayout`, `GameSession.demolishSelection()` (design D6).
- [x] 1.7 Implement to green: `HUDViewModel` stocks tray state (design D7).

## 2. M2 — Views (CityUI)

- [x] 2.1 Add `BuildingIconLoader` (design D8).
- [x] 2.2 Add the status pill with speed control and the stocks tray; move the menu buttons into one top-right row.
- [x] 2.3 Add the build rail, dock and drawer with hotkeys.
- [x] 2.4 Add the tool strip; remove the armed caption.
- [x] 2.5 Add the inspector callout; remove the bottom-left inspector.
- [x] 2.6 Re-lay out `CityRootView` around the new pieces; delete `HUDFrameView` and `BuildPaletteView`.
- [x] 2.7 Refactor under a green bar.

## 3. M3 — Handoff refinements

- [x] 3.1 Tests-first: translate the new and changed scenarios (phone portrait menus, choosing a speed resumes, locked drawer tile, arming clears the selection, tool strip hint, callout key lines, flip and bounds) into failing `CityUITests`. Confirm red.
- [x] 3.2 Implement to green: `HUDLayout`; speed choice resumes; locked tiles and selection clearing; hint text; callout tier, residents fill, key lines and flip-and-clamp placement (design D1a, D3, D4, D6).
- [x] 3.3 Apply the handoff's view details: `.thinMaterial`, margins, pause accent fill, More menu, rejection banner above the tool strip, placement buttons above the HUD, drawer closes on sheets, phone sheet detents.

## 4. M4 — Verification

- [x] 4.1 Runtime check (done in portrait on iPhone 17 Pro Max: Town drawer, house and road armed with the tool strip ("Tap or drag to place road"), planks 5/4 before any tap, stocks tray open and closed, More menu, town center callout under the building with Details, Actions and Demolish, arming clears the selection. Landscape not driven: no Simulator.app to rotate and Mac app access declined; covered by HUDDock/HUDLayout tests) on the iOS simulator in landscape and portrait.
- [x] 4.2 Run lint, format, `make test`, `make test-scenarios`, `openspec validate redesign-hud-map-first --strict` and the iOS simulator `xcodebuild`.
