## Context

The current input pipeline is:

```
UITouch / NSEvent → IsoWorldScene → InputTranslator → Intent
                                                        │
                                                        ▼
                                          GameSession.handle*(at:)
                                                        │
                                                        ▼
                                            world.enqueue(Command)
                                                        │
                                                        ▼ (next tick)
                                              World.applyPlace
```

`Intent` is the platform-neutral seam. `GameSession` owns the tool state (`selectedTool: BuildTool`), the inspector selection (`selectedTile`), and the hover state (`hoveredTile`). The ghost preview is computed lazily from `(selectedTool, hoveredTile, world)`. The renderer's only role is geometry — translate screen points to tile coordinates and dispatch intents.

This change adds a new piece of UI state — a *pending* placement — between "the player has indicated intent to build here" and "the command queue has accepted a `.place`." On iOS, that state is reached via long-press → context menu → pick a building kind. The player then nudges the ghost with iso-aligned arrows and confirms with a checkmark.

## Goals / Non-Goals

**Goals:**

- iOS players can place buildings without arming a palette tool first. Long-press a tile, pick a building, nudge if needed, confirm.
- Mis-placements are recoverable without paying the building's cost: the cancel button discards the pending placement before any command is enqueued.
- The interaction model is touch-native: visible affordances (highlight, arrows, checkmark), large hit areas (≥44 pt), no hover dependence.
- Mac users keep their existing palette + click + hover flow. No regression.
- Road and demolish keep their paint / drag flow. Tile-by-tile confirmation would be miserable for repeated operations.

**Non-Goals:**

- Replacing the palette entirely. The palette stays for Mac parity and as a power-user shortcut on iOS.
- Undo for committed placements. Once `.place` is enqueued, the building is built and consumes materials. Demolish remains the only "undo" for committed placements (and it's still material-free per `add-build-materials-cost` D5).
- Multi-tile drag-place for buildings other than road. Buildings have footprints ≥ 1×1 but they're singletons — a player paints roads, not houses.
- Apple Pencil / hover-pen interactions. iPad pencil hover is supported as `hoverTile` per existing `rendering-2_5d` Input mapping, but long-press is finger-only in this change.
- XCUITest coverage of the menu / HUD views. Logic tests on the ViewModels cover the state machine; visual / hit-target testing waits for a broader UI-test pass.
- Reordering or restyling the BuildPaletteView. The palette is unchanged in this scope.

## Decisions

### D1. Long-press → context menu (chosen over single-tap → action sheet)

The two viable touch-first models are:

- **Long-press → menu** (chosen). Tap selects (inspects). Long-press opens a context menu of verbs anchored to the tile.
- **Single-tap → action sheet.** Every tap pops a sheet with Build / Demolish / Cancel. Inspect requires its own button on the sheet.

Long-press wins on three axes:

1. **Inspect is the most common action.** Tapping to passively read the inspector should not require dismissing a modal. Single-tap-as-action-sheet adds a tap to every inspection.
2. **iOS conventions.** Maps, Files, and Photos all use long-press for "show me what I can do with this object." Players bring that mental model.
3. **Composability.** Long-press chains cleanly: long-press → Build → House → tap arrows → ✓. Single-tap-as-action-sheet requires dismissing a sheet between every selection.

Discoverability is the cost. Long-press is invisible. Mitigated by:

- A first-run coach mark ("Long-press a tile to build") shown once.
- An always-visible "Actions ⋯" button in the inspector that opens the same menu — players who tap to inspect can discover the verbs from there.

**Alternatives considered:**

- *Hold + drag from palette to tile.* Rejected — pulls the gesture into the palette, doesn't help with mis-placement, and is non-obvious on a small-screen iPhone.
- *Always show a floating action button anchored to the selected tile.* Rejected — clutters the world view, doesn't scale to multiple tiles, and competes for the same screen real estate as the inspector.
- *Force-touch / 3D-Touch.* Rejected — Apple deprecated the API on newer devices; long-press is the supported replacement Apple itself shipped.

### D2. Iso-aligned arrows, not screen-cardinal arrows

The placement HUD's four nudge arrows are positioned along the **iso axes** (NE / SE / SW / NW from the player's view of the tile), not along screen cardinal directions (up / down / left / right). The arrows visually point along the rendered diamond's edges.

```
   Screen-cardinal (rejected)        Iso-aligned (chosen)

            ▲                              ▲
            │                            ╱   ╲
       ◄────┼────►                     ◄       ►
            │                            ╲   ╱
            ▼                              ▼

       moves ghost 2 tiles            moves ghost 1 tile
       diagonally in iso              along visible edge
       space — confusing              — matches the eye
```

`IsoDirection` enumerates the four iso axes:

```swift
public enum IsoDirection: Hashable, Sendable {
    case ne, se, sw, nw

    public var tileOffset: (dx: Int, dy: Int) {
        switch self {
        case .ne: return (dx:  0, dy: -1)
        case .se: return (dx:  1, dy:  0)
        case .sw: return (dx:  0, dy:  1)
        case .nw: return (dx: -1, dy:  0)
        }
    }
}
```

`(dx, dy)` are tile-grid offsets. The mapping to iso names is: `ne` decreases the y-coordinate (visually moves up-right on the screen), `se` increases the x-coordinate (visually moves down-right), and so on. The renderer's iso math is unchanged — `IsoDirection` is purely an input-side enum naming the four single-tile moves.

**Alternatives considered:**

- *Two-axis pad (4 cardinal + 4 diagonal = 8 arrows).* Rejected — 8 small targets on a touch screen is cramped; players don't need 8-way fine positioning for tile-by-tile snap.
- *Free drag of the ghost.* Rejected — fine for a single building but loses the "snap to tile" affordance and competes with camera pan. Could ship later as a secondary mode.

### D3. Pending-placement state on `GameSession`, not on the renderer

`pendingPlacement` lives on `GameSession`, not on `IsoWorldScene` or in `CityRender2D`. Reasoning:

- `GameSession` already owns `selectedTool`, `selectedTile`, `hoveredTile` — every other piece of input-derived UI state. Pending placement is the same kind of state.
- The renderer is a pure consumer of snapshots + the ghost-provider closure. Pulling pending state into the renderer would couple the SpriteKit scene to a state machine it doesn't otherwise need.
- The `PlacementHUD` view is a SwiftUI overlay on `worldView`, anchored to the pending tile's screen position. SwiftUI reads `pendingPlacement` directly from `GameSession`; no detour through the renderer.

```swift
public struct PendingPlacement: Equatable, Sendable {
    public let kind: BuildingKind
    public var anchor: TileCoordinate
    /// Tile the player long-pressed, kept for analytics / future undo
    /// of nudges. Not currently consumed.
    public let origin: TileCoordinate
}

@MainActor
public final class GameSession {
    public var pendingPlacement: PendingPlacement?

    public func beginPendingPlacement(kind: BuildingKind, at tile: TileCoordinate) {
        pendingPlacement = PendingPlacement(kind: kind, anchor: tile, origin: tile)
    }

    public func nudgePendingPlacement(_ direction: IsoDirection) {
        guard var pending = pendingPlacement else { return }
        let (dx, dy) = direction.tileOffset
        let next = TileCoordinate(x: pending.anchor.x + dx, y: pending.anchor.y + dy)
        guard isInBounds(next) else { return }
        pending.anchor = next
        pendingPlacement = pending
    }

    public func confirmPendingPlacement() {
        guard let pending = pendingPlacement else { return }
        world.enqueue(.place(pending.kind, at: pending.anchor))
        pendingPlacement = nil
    }

    public func cancelPendingPlacement() {
        pendingPlacement = nil
    }
}
```

While `pendingPlacement` is non-nil, `handleTap(at:)` ignores world taps (they don't commit, they don't change the anchor — the player must use the arrows or the HUD buttons). This prevents the common "I tapped to dismiss the menu and accidentally moved the ghost" failure mode.

The ghost-preview pipeline reads `pendingPlacement.anchor` when set, falling back to `hoveredTile` otherwise. So the existing green/red affordance, cost breakdown, and shore-rule checks all just work through the same `ghostState()` path.

**Alternatives considered:**

- *Make `selectedTool` itself carry the pending anchor.* Rejected — overloads a tool-arming enum with positional state and forces an awkward `BuildTool.placePending(BuildingKind, TileCoordinate)` case that has to be mapped back through every switch.
- *Treat pending placement as a separate scene-graph node managed by IsoWorldScene.* Rejected — couples renderer to UI state, complicates testing, and forces duplicate state in the SwiftUI overlay.

### D4. Roads and demolish bypass the pending step

Picking `.road` from the context menu, or arming `.demolish`, transitions `selectedTool` directly with NO pending state. The player then taps or drags to paint.

Reasoning: roads are painted in long runs (10-30 tiles at a stretch is common). Forcing a confirmation per tile would make the painting flow miserable, and per-tile money cost already provides feedback. Demolish is reversible by re-placing (modulo cost) and is typically aimed at obvious targets the player can already see.

The asymmetry is documented in the menu itself: "Build › Road" and "Demolish" don't show the placement HUD, while every other building entry does.

```
                  Long-press menu items
                  ──────────────────────
                       Build  ▶
                          Road           → arms .place(.road), tap/drag paints
                          House          → enters pending placement
                          Warehouse      → enters pending placement
                          Sawmill        → enters pending placement
                          Lumberjack     → enters pending placement
                          Port           → enters pending placement
                          Shipyard       → enters pending placement
                          Town Center    → enters pending placement
                       Demolish          → arms .demolish, tap removes
                       Inspect           → dismiss, keep tile selected
```

**Alternatives considered:**

- *Confirm-every-tile for everything including road.* Rejected — playtest gut says this would tank road-laying UX.
- *Drag-to-paint for buildings.* Rejected — buildings have non-trivial footprints and material costs; painting an entire row of houses by accident is exactly what this change is trying to prevent.

### D5. Mac shell stays on the old model

The iOS-specific paths (`UILongPressGestureRecognizer`, `TileContextMenu`, `PlacementHUD`) are conditioned on `#if os(iOS)`. The Mac shell continues to use:

- Palette to arm a tool.
- Hover for the ghost preview.
- Click commits.

Reasoning: Mac users have a precise pointer, hover already gives them the preview-before-commit affordance the iOS flow is trying to recover, and the palette is more discoverable on a wide screen. Adding long-press equivalents on Mac (right-click context menu?) would double the surface area for a problem Mac doesn't have. Out of scope.

The Intent extension cases (`.longPressTile`, `.confirmPlacement`, etc.) are still defined platform-neutrally so the headless CLI / tests can drive the new flow. Only the *gesture wiring* is gated on iOS.

**Alternatives considered:**

- *Right-click → context menu on Mac as a parallel path.* Deferred. Useful but not necessary for the iOS goal, and Mac players have palette already.
- *Drop the palette on iOS in this change.* Rejected — too big a blast radius for one PR; do it once the new flow has proven itself with playtesting.

### D6. Menu presentation: SwiftUI confirmationDialog with attached menu sections

The `TileContextMenu` uses `.confirmationDialog(titleVisibility: .hidden, ...)` for the outer container, with a `Menu` for the "Build ▶" submenu (the building list is long enough that a flat dialog would scroll). This matches iOS's native pattern for "primary destructive vs. multi-option-secondary."

```swift
struct TileContextMenuPresenter: View {
    @Binding var presented: TileMenuRequest?
    let onSelect: (TileMenuChoice) -> Void

    var body: some View {
        EmptyView()
            .confirmationDialog(
                "Tile actions",
                isPresented: Binding(
                    get: { presented != nil },
                    set: { if !$0 { presented = nil } }
                ),
                titleVisibility: .hidden,
                presenting: presented
            ) { request in
                ForEach(buildableKinds(at: request.tile), id: \.self) { kind in
                    Button(buildLabel(for: kind, at: request.tile)) {
                        onSelect(.build(kind))
                    }
                    .disabled(!isAffordable(kind, at: request.tile))
                }
                if hasPlayerBuilding(at: request.tile) {
                    Button("Demolish", role: .destructive) {
                        onSelect(.demolish)
                    }
                }
                Button("Cancel", role: .cancel) {
                    onSelect(.dismiss)
                }
            }
    }
}
```

The dialog filters: only buildings whose `canPlace` returns `.allowed` (or returns `.rejected(.insufficientMaterials)` but with enough money — the affordable-soon set) appear enabled. Demolish appears only when the tile holds a player-owned building.

**Alternatives considered:**

- *SwiftUI `Menu` directly.* Works but anchors poorly to a touch point — `Menu` defaults to anchoring on its host view (the world), not the press location.
- *Custom popover with arrow pointing at the tile.* Visually nicer but adds non-trivial layout code. Defer to a polish pass if the dialog feels disconnected.

### D7. Long-press parameters

`UILongPressGestureRecognizer.minimumPressDuration = 0.4` (the default is 0.5; 0.4 feels snappier on touch testing). `allowableMovement = 10 pt` (default) so a small finger jitter doesn't cancel. The recognizer fires on `.began`; on `.changed` and `.ended` we do nothing — the menu has already been shown.

Conflict with the existing pan gesture: pan requires `minimumDistance: 1` so it engages on any movement. Long-press requires a *still* finger for 0.4 s. The two compose cleanly — a stationary press for 0.4 s fires long-press; a moving touch engages pan instead. Verified manually on iPad simulator's standard interaction model. We add a `require(toFail:)` from pan to long-press is unnecessary because pan can't fire until movement begins, by which time long-press has either already fired or been cancelled by movement.

The drag-to-paint path on iOS (touchesMoved → dispatchDrag → handleDrag) is untouched. When a build tool is armed and the player long-presses, the menu opens *before* drag would start, so painting a road from a stationary start is unaffected.

## Risks / Trade-offs

- **Discoverability of long-press** → Mitigated by the first-run coach mark and the always-visible "Actions ⋯" button in the inspector. Telemetry hook for "did the player ever long-press in their first session" deferred until we add an analytics surface; for now, playtest observation.
- **Two ways to start a placement (palette + tap, long-press + menu)** → Both flows funnel into the same `beginPendingPlacement(kind:at:)` path on iOS so the post-arm experience is identical. Documented in the Tasks M3 audit step.
- **Mac vs. iOS divergence creeps over time** → The Intent extension stays platform-neutral. Anything that ships only on one platform is a render-layer or view-layer concern; the simulation contract is identical. Re-audit at the next archive review.
- **Pending state survives a re-orient / app foregrounding** → Pending state is `@MainActor` on `GameSession`; SwiftUI keeps it across rotations. App backgrounding doesn't persist it (it's not in the save format). If the player backgrounds the app mid-placement, the ghost is gone when they return. Documented in the spec as "transient session-local state."
- **Long-press fires at the touch-down location, not the lift location** → If the player's finger drifts before the press duration completes, the gesture cancels (movement > allowableMovement). After it fires, lift-location doesn't matter. Matches iOS native conventions.

## Determinism

No simulation change. `World.canPlace`, `World.applyPlace`, the command queue, and the tick loop are unchanged. The pending-placement state lives entirely in `GameSession` and never reaches `CityCore`. Two replays from the same save with the same `Command` sequence produce byte-identical `World` values regardless of which UI gesture produced the commands.

The new `IsoDirection` enum lives in CityRender2D (the rendering / input package), preserving CityCore's framework-free invariant. `IsoDirection` has no simulation effect — it's a labelling convention for the four "move pending ghost by one tile" intents.

## Framework-free invariant

No CityCore changes. `pendingPlacement` and `IsoDirection` are CityUI / CityRender2D concerns. The `scripts/check-no-apple-ui-imports.sh` gate continues to pass: nothing imports SwiftUI or UIKit from CityCore.
