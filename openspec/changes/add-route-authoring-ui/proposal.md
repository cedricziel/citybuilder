## Why

Players cannot create ship routes in the app. `add-archipelago-and-sea` built the headless chassis (`RouteAuthoringViewModel`, `RouteAuthoringTapTarget`, `setManifest(_:forPort:)`, `RouteListViewModel`, `RoutePolylineProjector`) but left the SwiftUI overlay, manifest editor, route list and scene tap wiring to a sibling change that was never written. `add-rival-trade` then added `ManifestEditorModel` (Buy/Sell labels, prices and offers at rival ports) and rival ports as route-authoring targets, also without a view. Shipyards emit idle ships that nothing can assign, and the scene has never drawn ships. Sea transport and rival trade are unreachable for a player. This change makes them playable end to end on a phone.

## What Changes

- **Routes button and route list:** a HUD button opens a route list sheet: one row per route with its port stops, state and ship count, and Show (draws the route on the map), Pause/Resume, Assign ship and Delete. The list shows how many idle ships the player has and offers New Route.
- **Ship assignment:** Assign ship sends the player's lowest-ID idle ship to the route through the existing `assignShipToRoute` command.
- **Route mode:** New Route, or Route from here on any port's inspector, enters route mode. World taps go to `RouteAuthoringViewModel`: ports of any owner and water tiles add stops, land taps are rejected with a red flash and a short message. A bottom overlay lists the stops and offers Undo, Cancel and Commit, and shows why a commit was rejected. The palette, inspector and long-press menu are off while authoring.
- **Manifest editor:** each port stop opens a sheet that edits that port's ordered manifest: verb, good and quantity, Load/Unload at the player's ports and Buy/Sell with price and offer at rival ports (reusing `ManifestEditorModel`).
- **Scene overlay:** the scene draws the in-progress route (land-crossing legs in red) while authoring, otherwise the route selected in the list, and flashes rejected land taps.
- **Ships on the map:** the scene draws every ship as a sprite with the facing chosen from its heading, as the existing `rendering-2_5d` / Ship sprite rendering requirement already asks.
- **Pausing a route (sim fix):** `RouteListViewModel.pause` sent an `editRoute`, which keeps the route's state, and ships ignored `.paused`, so pausing did nothing. A new `setRoutePaused(id:paused:)` command pauses and resumes a route, and ships on a paused route hold where they are.

Out of scope: editing an existing route's stops or manifest (delete and re-author instead), new art, Mac-specific polish beyond compiling, and the closing leg from the last stop back to the first, which route validation doesn't check today.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `platform-shells`: routes button, route list, ship assignment, route mode overlay, manifest editor sheet, Route from here on the port inspector.
- `rendering-2_5d`: route overlay drawn from the session (in-progress or selected route, red legs, rejected-tap flash).
- `sea-transport`: pausing and resuming a route.

## Impact

- **CityCore:** `Command.setRoutePaused`, paused-route hold in `ShipTick`.
- **CityUI:** `GameSession` route mode (`routeAuthoring`, `routeList`, overlay provider), route list rows and ship assignment, manifest draft, overlay, route list and manifest editor views, inspector button, HUD button. The renderer registry factory gains a route overlay provider.
- **CityRender2D:** route overlay layer and ship sprites in `IsoWorldScene`; `IsoWorldView` takes a route overlay provider.
- **Apps:** both shells pass the route overlay provider to `IsoWorldView`.
- **CityPersistence:** none. Route mode and the selected route are session state and are never saved.
