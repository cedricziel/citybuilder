## Why

The current input model is "arm-then-tap": the player taps a button in the top-bar palette to arm a tool, then taps a world tile to commit the action. On iOS that flow has three problems.

1. **No hover means no preview before commit.** The ghost preview only renders during a drag, so on iPhone/iPad the player only sees the green / red affordance after they've already started moving the building. The first tap is blind.
2. **Commit-on-tap is destructive-immediate.** One mis-tap costs the building's money plus its material cost (post `add-build-materials-cost`). Demolition is the only undo, and it costs the building.
3. **The palette is the discovery surface.** Players see a horizontal strip of building names, not a "tap the world and decide" affordance — backwards for a touch-first device.

Anno-likes on iPad solve this with a tap-first interaction: tap a tile to *consider* it, long-press (or pop a small action sheet) to *act on* it, and any committing action — placing a building — enters a brief confirmation mode with arrows to nudge position and a checkmark to commit.

This change introduces that flow on iOS while keeping the Mac shell on its existing palette + hover + click model. The seam is at the `Intent` layer (which is already platform-neutral) and `GameSession`'s state machine, which gains a "pending placement" mode between arming a building and enqueuing the `.place` command. Road and demolish keep their paint / drag behavior because tile-by-tile confirmation would be miserable for repeated operations.

## What Changes

- `Intent` gains four new cases: `.longPressTile(coord)`, `.confirmPlacement`, `.cancelPlacement`, `.nudgePlacement(direction: IsoDirection)`. The existing `.tapTile`, `.dragTile`, `.panCamera`, `.pinchZoom`, `.hoverTile` cases are unchanged. (`rendering-2_5d` modified.)
- A new `IsoDirection` enum (`.ne`, `.se`, `.sw`, `.nw`) captures the four iso-grid axes. Nudge arrows render along these axes — they match the rendered tile edges, not screen up/down/left/right. (`rendering-2_5d` modified.)
- `IsoWorldScene` on iOS adds a `UILongPressGestureRecognizer` (minimumPressDuration 0.4 s) that dispatches `.longPressTile(coord)` at the touch-down location. The existing `touchesEnded` path continues to dispatch `.tapTile(coord)`. Mac keeps its current `mouseUp` → `.tapTile` and adds no long-press equivalent — long-press is iOS-only. (`rendering-2_5d` modified.)
- `GameSession` gains a `pendingPlacement: PendingPlacement?` state (nudged with CityUI's `NudgeDirection`, a mirror of `IsoDirection`, since CityUI does not import the renderer). When non-nil, the world view renders the ghost at `pendingPlacement.anchor` with the iso arrow / checkmark overlay; `.tapTile` does NOT commit; `.confirmPlacement` enqueues `.place`; `.cancelPlacement` clears the state. (`rendering-2_5d` modified.)
- A new `TileContextMenu` view (presented as a SwiftUI `.confirmationDialog` or popover anchored to the tapped tile) lists the actionable verbs for a tile: **Build** (the palette's kinds, with obsolete ones hidden and locked or unaffordable ones disabled with a reason — same checks as `canPlace` and the palette), **Demolish** (visible only when the tile holds a player-owned building), **Inspect** (dismisses and keeps the tile selected). Long-press summons it; the inspector also gets an "Actions ⋯" button that opens the same menu, so the gesture stays discoverable. (`rendering-2_5d` modified.)
- Picking a building kind from the context menu transitions `GameSession` into pending-placement mode at the long-pressed tile. Picking **Demolish** enqueues `.demolish` immediately (no confirmation step — demolition is reversible by re-placing). Picking **Inspect** is a dismiss.
- A new `PlacementHUD` view in CityUI renders four iso-aligned arrows around the pending ghost (NE / SE / SW / NW) plus a central checkmark and a cancel "✕". Arrows dispatch `.nudgePlacement(direction:)` which moves `pendingPlacement.anchor` one tile along that iso axis. Checkmark dispatches `.confirmPlacement`. Cancel dispatches `.cancelPlacement`. (`rendering-2_5d` modified.)
- Road and demolish keep their existing drag-to-paint flow on iOS, accessed by tapping the palette and dragging — the new menu / pending-placement flow is for **buildings only** (everything in `BuildingKind` except `.road`). Picking `.road` from the context menu arms `.place(.road)` without entering pending mode; the player then drags to paint, matching existing semantics.
- The top-bar `BuildPaletteView` stays for backward compatibility and Mac parity. On iOS, palette-armed buildings ALSO route through the new pending-placement flow (palette arm + first tap → pending placement at that tile); palette + drag with road or demolish armed keeps existing paint behavior.
- A first-run coach mark on iOS shows "long-press a tile to build" once on first session, dismissable. Stored as a `UserDefaults` flag (`com.cedricziel.citybuilder.coachmark.touchPlacement`). Non-blocking.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `rendering-2_5d`: input mapping extended with long-press, placement-confirm, placement-cancel, and placement-nudge intents; `IsoDirection` added; `PlacementHUD`, tile menu and coach mark requirements added. The pre-commit "pending" phase is UI-only (`World.applyPlace` is unchanged; only the moment the `.place` command is enqueued moves), so `buildings-and-construction` has no delta.

## Impact

- **CityRender2D** — `Intent` enum gains four cases. `InputTranslator` gains a translation helper for long-press points. `IsoWorldScene` (iOS path) adds a `UILongPressGestureRecognizer` and dispatches the new intent.
- **CityUI** — `GameSession` gains `pendingPlacement: PendingPlacement?` plus `confirmPendingPlacement()`, `cancelPendingPlacement()`, `nudgePendingPlacement(_:)` methods. New `TileContextMenu` and `PlacementHUD` views. `BuildPaletteView` unchanged in shape; behavior on iOS routes through pending-placement.
- **CityCore** — no changes. `IsoDirection` lives in CityRender2D (it's input-layer geometry, not simulation state). `World.canPlace` and `World.applyPlace` are unchanged.
- **CityPersistence** — no save-format change. `pendingPlacement` is transient UI state and MUST NOT be persisted. (Confirmed by the existing snapshot model — `GameSession`'s session-local fields like `selectedTile` and `hoveredTile` are already excluded from saves.)
- **Mac shell** — no functional change. Long-press is an iOS-only gesture; the new menu / HUD views are conditioned on `#if os(iOS)` so the Mac binary doesn't pull in unused SwiftUI surface area. Mac keeps palette + click commit-on-click + hover preview.
- **Determinism** — no simulation change. Commands still queue at tick boundaries and `applyPlace` is byte-identical under replay. The new pending phase is purely an input-layer batching step ahead of `enqueue`.
- **Build / lint** — no new third-party runtime dependencies. Long-press recognizer is `UIKit.UILongPressGestureRecognizer`, already in scope on iOS.
- **Test surface** — new scenarios for `Intent` extension, `GameSession.pendingPlacement` lifecycle, and the menu → pending → confirm path. View-level rendering (arrow positions, button hit areas) covered by ViewModel logic tests; no XCUITests added in this change.
