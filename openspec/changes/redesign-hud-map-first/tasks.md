## 1. M1 — HUD models (CityUI)

- [ ] 1.1 Tests-first: translate every platform-shells scenario in this change into failing `CityUITests`; rewrite the "iPad sidebar HUD" and "iPhone compact HUD" tests against `HUDDock`. Confirm red.
- [ ] 1.2 Implement to green: `HUDDock` placement by view size; drop `LayoutDecisions.palettePlacement` (design D1).
- [ ] 1.3 Implement to green: `BuildCategory`, `BuildPalette` (renamed from `BuildPaletteView`'s statics), `BuildRailModel`, rail hotkeys (design D2, D3).
- [ ] 1.4 Implement to green: `GameSpeed`, `GameSession.speed` and `timerFired()` (design D4).
- [ ] 1.5 Implement to green: `GameSession.armedCostBreakdown`, tool strip hint text (design D5).
- [ ] 1.6 Implement to green: `InspectorViewModel.title` and `keyLines`, `InspectorCalloutLayout`, `GameSession.demolishSelection()` (design D6).
- [ ] 1.7 Implement to green: `HUDViewModel` stocks tray state (design D7).

## 2. M2 — Views (CityUI)

- [ ] 2.1 Add `BuildingIconLoader` (design D8).
- [ ] 2.2 Add the status pill with speed control and the stocks tray; move the menu buttons into one top-right row.
- [ ] 2.3 Add the build rail, dock and drawer with hotkeys.
- [ ] 2.4 Add the tool strip; remove the armed caption.
- [ ] 2.5 Add the inspector callout; remove the bottom-left inspector.
- [ ] 2.6 Re-lay out `CityRootView` around the new pieces; delete `HUDFrameView` and `BuildPaletteView`.
- [ ] 2.7 Refactor under a green bar.

## 3. M3 — Verification

- [ ] 3.1 Runtime check on the iOS simulator in landscape and portrait: open each drawer, arm a house and read the tool strip chips, place it, select it and read the callout, Demolish from the callout, open and close the stocks tray, switch speeds.
- [ ] 3.2 Run lint, format, `make test`, `make test-scenarios`, `openspec validate redesign-hud-map-first --strict` and the iOS simulator `xcodebuild`.
