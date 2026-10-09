## 1. M1 — Pausing a route (CityCore)

- [x] 1.1 Tests-first: translate the sea-transport scenarios "Paused route holds its ships", "Resumed route sails on" and "Broken route stays broken" into failing `CityCoreTests`. Confirm red.
- [x] 1.2 Implement to green: `Command.setRoutePaused(id:paused:)`, its apply rule, and the paused-route hold for sailing and docked ships in `ShipTick` (design D7).

## 2. M2 — Session route mode and models (CityUI)

- [x] 2.1 Tests-first: translate the platform-shells scenarios (Routes button and route list, Assigning a ship to a route, Route mode, Manifest editor sheet) and the rendering-2_5d scenario "Session overlay follows route mode and selection" into failing `CityUITests`. Confirm red.
- [x] 2.2 Implement to green: `RouteListViewModel` rows, idle ships, `assignIdleShip(to:)`, pause and resume through `setRoutePaused`; stop labels; `RouteAuthoringViewModel.removeLastWaypoint()` and `rejectedLandTile`; overlay message text (design D3, D5).
- [x] 2.3 Implement to green: `GameSession.routeAuthoring` and `routeList`, `beginRouteAuthoring(from:)`, `commitRouteAuthoring()`, `cancelRouteAuthoring()`, route-mode tap and long-press handling, `routeOverlay()`, Routes button availability, the inspector's route start port (design D1, D2, D6).
- [x] 2.4 Implement to green: `ManifestDraft`, `ManifestEditorModel.line(for:)` and `ManifestGoodRow.title` (design D4).

## 3. M3 — Scene overlay and ships (CityRender2D, apps)

- [x] 3.1 Tests-first: translate the rendering-2_5d scenarios "Red leg in the scene" and "Rejected land tap flashes", plus the existing "Unselected route does not render polyline" and "Ship zRotation always zero", into failing `CityRender2DTests`. Confirm red.
- [x] 3.2 Implement to green: `IsoWorldScene.RouteOverlay`, the routes layer with legs, stop dots and flash, and the ships layer (sprites by facing, culling, move actions) (design D6).
- [x] 3.3 Wire the route overlay provider through `SnapshotRendererRegistry`, `IsoWorldView` and both app shells.

## 4. M4 — SwiftUI views (CityUI)

- [ ] 4.1 Add the HUD Routes button and the route list sheet (medium detent, rows with Show, Pause/Resume, Assign ship, Delete, New Route).
- [ ] 4.2 Add the route-mode overlay (message, stop chips, Undo, Cancel, Commit) and hide the palette, caption and inspector while it is on.
- [ ] 4.3 Add the manifest editor sheet opened from a port chip, and Route from here on the port inspector.

## 5. M5 — Verification

- [ ] 5.1 Runtime check (iPhone 17 Pro Max simulator, portrait, prepared save with a player port, an idle player ship and a rival port): inspect your port, tap Route from here, tap the rival port, open its chip and add "Sell 20 Planks", commit; open Routes, assign the idle ship, watch it sail to the rival port and the balance change when it docks; select the route and see its line on the map; pause and resume it; try a land tap and a one-port commit and read the messages.
- [ ] 5.2 Run lint, format, `make test`, `make test-scenarios`, `openspec validate add-route-authoring-ui --strict` and the iOS simulator `xcodebuild`.
