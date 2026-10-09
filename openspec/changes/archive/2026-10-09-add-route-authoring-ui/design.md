## Context

See proposal.md (Why). What exists today:

- `RouteAuthoringViewModel` (CityUI): `inProgressWaypoints`, `redSegments` (the same 0.25-tile land sampler as `World.validate(route:)`), `rejectedTapFeedback` with `consumeRejectedTapFeedback()`, `manifest` with `setManifest(_:forPort:)`, `commit()` (rejects with `.fewerThanTwoPorts` or `.landCrossingSegment`, otherwise sends `createRoute` to its `commandSink` and resets), `cancel()`. It needs a `snapshot` to validate.
- `RouteAuthoringTapTarget.resolve(tile:in:)` classifies a tile as `.port(id:)` (a port of any owner), `.water` or `.land`.
- `RouteListViewModel`: `routes` sorted by ID, `selectedRouteID`, `select`, `delete`, `pause`, `resume`.
- `ManifestEditorModel` (`add-rival-trade`): Load/Unload or Buy/Sell labels and per-good price and offer rows.
- `RoutePolylineProjector` and `RouteLayerZPosition` (CityRender2D): waypoint → scene point, routes layer between terrain (0) and buildings (10).
- `GameSession.handleTap(at:)` selects a tile or places/demolishes by armed tool. The renderer is plugged in through `SnapshotRendererRegistry.factory`, which takes closures (snapshot, tap, drag, hover, long-press, ghost, selection) so CityUI never imports CityRender2D. Each app maps CityUI values (e.g. `GhostPreview`) into scene values (`IsoWorldScene.GhostState`).
- Shipyards emit `.idle` player ships at their sea face. Nothing in the app assigns them, and `IsoWorldScene` never draws ships.

## Goals / Non-Goals

**Goals:** a player on an iPhone can build a route from their port to a rival port with a manifest, put a ship on it, watch it sail, and pause or delete the route.

**Non-Goals:** editing an existing route, new art, Mac polish, a speed control, route validation of the closing leg.

## Decisions

### D1 — Route mode is session state

`GameSession` gains `routeAuthoring: RouteAuthoringViewModel?` (non-nil means route mode is on) and `routeList: RouteListViewModel` (always present; its selection drives the overlay). Both are transient and never saved.

- `beginRouteAuthoring(from port: EntityID? = nil)` clears a pending placement, the tile menu request and the route selection, resets the tool to inspect, creates the view-model with a fresh snapshot, and adds `port` as the first stop when given. Its `commandSink` enqueues commands.
- `commitRouteAuthoring()` calls `commit()`, which returns whether it sent `createRoute`; only then does route mode end. `cancelRouteAuthoring()` ends the mode.
- `handleTap(at:)` sends the tap to the view-model while route mode is on: it resolves the tile against the view-model's snapshot with `RouteAuthoringTapTarget.resolve` and calls `tapHandler(target:)`. The tool, selection and command queue are untouched. `handleLongPress(at:)` does nothing in route mode.
- `step()` hands each tick's snapshot to `routeList` and `routeAuthoring`. The world only changes inside a tick, so taps and commits never see a stale snapshot, and nothing takes an extra one.

- **Alternative — a separate `BuildTool.route` case.** Rejected: the tool enum drives the palette, pan mask and ghost; route mode needs none of them and has its own overlay.

### D2 — Entry points

- **HUD Routes button** (SF Symbol `ferry.fill`) next to Standings, shown when the player owns a port or a ship, or the world has a route. It opens the route list sheet, which offers New Route.
- **Route from here** on the inspector of any port (player or rival) starts route mode with that port as the first stop. This is the shortest path on a phone: tap your port, Route from here, tap the rival port, Commit.

### D3 — Overlay

While route mode is on, the root view hides the build palette, armed caption and inspector, and shows a bottom panel:

- A hint, "Tap ports and water to add stops.", replaced by "Ships can't stop on land." after a rejected land tap (until the next accepted tap), and by the rejection reason after a failed commit:
  - `.fewerThanTwoPorts` → "A route needs at least two ports."
  - `.landCrossingSegment` → "A red leg crosses land. Add water stops around it."
- A horizontal row of stop chips, numbered in order. Port chips read "Your port (x, y)" or "<Rival>'s port" and open the manifest editor; they show the number of manifest actions. Sea chips read "Sea".
- Undo (removes the last stop and the manifest of a port no longer in the route), Cancel and Commit.

The view-model gains `removeLastWaypoint()` and `rejectedLandTile` (set by a land tap, cleared by the next accepted tap, by undo and by reset).

### D4 — Manifest editor

A sheet per port stop. `ManifestDraft` (value type) holds the port's ordered actions, seeded from the view-model's manifest:

- `add(_ verb:, good:, quantity:)` appends `.loadUpTo` or `.unloadUpTo`; `remove(at:)` drops one.
- Quantities run 5 to 100 in steps of 5 (100 is the default ship capacity), default 20.
- Done stores the draft with `setManifest(_:forPort:)` (an empty draft clears the port's entry); Cancel discards it.

Text comes from `ManifestEditorModel`:

- `line(for:)`: "Load 20 Wood", "Unload 10 Planks" at a player port; "Buy 20 Wood — $5", "Sell 10 Tools — $22" at a rival port (sell price for Buy, buy price for Sell; the price is today's, the trade happens at docking).
- `ManifestGoodRow.title`: "Wood" at a player port; "Wood — $5 — 12" or "Iron — no offer" at a rival port.

The sheet is a `Form`: the action list with swipe-to-delete, then an Add section with a segmented verb picker, a good menu picker, a quantity stepper and an Add button.

### D5 — Route list

`RouteListViewModel` gains display rows and ship assignment:

- `rows`: one `RouteListRow` per route in ID order. Title "Route <n>" by list position; stops are the port stops joined by " → " (sea stops are left out); status "Active", "Paused" or "Broken", then " · <n> ship(s)" counting ships whose `routeID` is the route.
- `idleShipCount` and `assignIdleShip(to:)`: the player's ships that are `.idle` with no route; assignment sends `assignShipToRoute` for the lowest ID. `canAssignShip` is false when there is none, and the button reads "No idle ship".
- `pause` and `resume` send `setRoutePaused` (D7).
- Tapping a row selects it (tapping it again clears the selection). The sheet opens at a medium detent so the selected route's polyline shows on the map above it.

### D6 — Scene overlay and ships

`GameSession.routeOverlay()` returns a `RouteOverlay` (waypoints, red segment indices, flash tile):

- in route mode: the in-progress waypoints and red segments, and the rejected-tap tile (consumed, so it flashes once);
- otherwise the selected route's waypoints with no red segments;
- otherwise nil.

`SnapshotRendererRegistry.factory` gains a route overlay provider; each app maps `RouteOverlay` to `IsoWorldScene.RouteOverlay` and passes it to `IsoWorldView`. The scene keeps a routes layer at `RouteLayerZPosition.routes`; when the overlay changes it rebuilds one `SKShapeNode` per leg (red for red segments, otherwise white) through `RoutePolylineProjector.position`, plus a dot per stop. A flash adds a red tile diamond that fades out over 0.6 s.

Ships: a ships layer reconciles one `SKSpriteNode` per ship inside the view (using `ShipCulling.isVisible`), keyed by ship ID. The texture is `ship-<facing>-<frame>` from `ShipRenderMath.facing(forHeading:)`, with the frame alternating every 5 ticks while sailing; `zRotation` stays 0. A position change runs a 0.1 s move action, so motion is smooth between ticks. Ships sit at z 50 like carriers.

### D7 — Pausing a route (sim)

`Command.setRoutePaused(id: RouteID, paused: Bool)`: an `.active` route becomes `.paused` and a `.paused` route becomes `.active`; a broken route and an unknown ID are left alone. A `.sailing` or `.docked` ship whose route is paused does nothing that tick: it keeps its position, manifest index and dock wait. Idle and returning ships are unaffected.

- **Alternative — let `editRoute` carry the state.** Rejected: it changes an existing command's meaning, and edit keeps state on purpose.

## Risks / Trade-offs

- **[Risk] The closing leg crosses land.** Ships sail from the last stop straight back to the first, and validation doesn't check that leg. → Accepted for this change; the overlay draws the route as authored. A player can end the route with water stops leading home.
- **[Trade-off] The route list refreshes once per tick.** Assigning the snapshot each tick re-renders an open list ten times a second; the list is short.
- **[Risk] A rival port appears late.** In the `add-rival-trade` headless run the first rival port appeared after about 18,600 ticks. The runtime check uses a prepared save.

## Implementation notes

- **Sim change (deviation from "UI only").** Pausing could not work without CityCore: `RouteListViewModel.pause` sent an `editRoute`, which keeps the route's state, and `ShipTick` ignored `.paused`. D7 adds `setRoutePaused` and the hold. Making `.paused` reachable exposed a second spot: port demolition sent home every ship whose route was not `.active`, so demolishing any port would have recalled ships from an unrelated paused route. It now recalls ships whose route is broken or gone (`RouteState.isBroken`), with a test.
- **Ships are drawn.** `IsoWorldScene` had no ship sprites at all, although `rendering-2_5d` / Ship sprite rendering, Ship facing selection and Off-screen ship culling already asked for them. The ships layer implements them, and the scene tests now map the formerly unmapped "Ship zRotation always zero" and "Unselected route does not render polyline". The layer reconciles only when the tick, camera or view size changes, not every frame. `RouteLayerZPosition.ships` moved from 15 to 50: buildings sit at 10 plus depth / 100, which passes 15 on large maps.
- **Route mode feedback.** `RouteAuthoringViewModel` gained `isWarning` so the overlay colours the message without comparing strings, and `commit()` returns a Bool (D1).
- **Manifest sheet prices.** The sheet takes the rival's prices and offers when it opens; they don't refresh while it is open. The trade itself uses the prices at docking.
- **Not built:** editing an existing route's stops or manifest (delete and re-author), and validation of the closing leg.
