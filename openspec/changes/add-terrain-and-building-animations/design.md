## Context

CityRender2D already plays a 2-frame walk cycle for carriers via `SpriteAtlas.walkerAnimation(facing:) -> [SKTexture]?` and a single `SKAction.animate(with:timePerFrame:)` driven by `SKAction.repeatForever`. The path is proven; it is just not generalized. Terrain tiles and buildings are bound 1:1 to a single PNG (`terrain-<kind>.png`, `building-<kind>.png`) and never animate, so the world feels static once the carriers stop moving. Build state is already exposed (`BuildingState.constructing | .operational`) and `Building.ticksSincePlacement` is on the snapshot, so we have everything we need to drive deterministic construction-progress frames from `WorldSnapshot` alone — no simulation changes required.

The renderer's snapshot-reconciler/culling pipeline is the load-bearing constraint: any animation we add must respect it (off-screen tiles never run actions) and must survive node add/remove cycles when the camera pans.

## Goals / Non-Goals

**Goals:**
- Idle looped animations for `terrain-water`, `terrain-beach`, and operational `lumberjackHut`, `sawmill`, and `townCenter`.
- Deterministic scaffold-rise animation for every building in `.constructing` state, where the visible scaffold stage is derived from `ticksSincePlacement / buildDurationTicks` so two clients see the same stage at the same tick.
- One generalized `SpriteAtlas` API for multi-frame lookup that the walker animation also routes through.
- A single tunable catalog of animation cadence (`SpriteAnimation`).
- Preserve 60 fps on the baseline iPad target — no measurable regression vs. the static-sprite baseline.

**Non-Goals:**
- No directional or wind-driven smoke (smoke is one column, looped).
- No procedural shader-based water — frame-flipped PNGs only.
- No simulation/CityCore changes. No save-format changes.
- No animation for `road`, `house`, `warehouse`, `terrain-grass`, `terrain-forest`, `terrain-mountain` in this change (they remain static).
- No per-tile randomized phase offsets (would defeat the shared-`SKAction` optimization). Optional follow-up.
- No 3D / SceneKit work.

## Decisions

### D1. Generalize the atlas: one `frames(for:)` API; walker becomes a consumer

`SpriteAtlas` currently exposes `walkerAnimation(facing:)` as a one-off. We add:

```swift
public enum AnimationKey: Hashable {
    case terrain(TerrainType)
    case buildingOperational(BuildingKind)
    case buildingConstructing(BuildingKind)
    case walker(SpriteAtlas.WalkerFacing)
}

public static func frames(for key: AnimationKey) -> [SKTexture]?
```

`walkerAnimation(facing:)` becomes a thin wrapper that calls `frames(for: .walker(facing))` so the existing carrier code path is unchanged. Single-frame sprites (e.g., `terrain-grass`, `road`) return a 1-element array so callers can use one code path; the scene only arms an `SKAction.animate` when `frames.count > 1`.

**Alternatives considered:**
- *Keep separate functions per category.* Rejected — duplicates cache logic and bundle-lookup branching, and we want a single registry so the catalog can drive everything.
- *Use `SKTextureAtlas`.* Rejected — works against the current per-PNG asset pipeline and adds Xcode-time atlas generation. Our PNG count is small (~40 with this change); per-texture caching is fine.

### D2. Animation catalog as a Swift constant table

A new `SpriteAnimation` enum in CityRender2D maps each `AnimationKey` to `(frameCount: Int, timePerFrame: TimeInterval, loop: AnimationLoop)`. Same pattern as `BuildingCatalog` so it's discoverable and easy to tune.

```swift
public enum AnimationLoop { case forever; case progress }  // .progress = construction
```

`forever` arms `SKAction.repeatForever(SKAction.animate(...))`; `progress` selects a single frame via the function in D3 and updates it on each reconcile.

**Alternatives considered:**
- *Per-PNG metadata sidecar (`.json` next to each PNG).* Rejected — overkill for ~6 entries and complicates the asset pipeline.
- *Frame counts inferred from PNGs on disk.* Rejected — non-deterministic at boot, fragile to missing frames; an explicit table fails loudly.

### D3. Construction progress is a pure function of the snapshot

Construction scaffold frame is derived inside CityRender2D from `Building.ticksSincePlacement` and `BuildingCatalog.spec(for: kind).buildDurationTicks`:

```swift
func constructionFrame(ticksSincePlacement: UInt64, duration: UInt64, frameCount: Int) -> Int {
    guard duration > 0, frameCount > 0 else { return 0 }
    let progress = min(1.0, Double(ticksSincePlacement) / Double(duration))
    let idx = Int(progress * Double(frameCount - 1) + 0.5)
    return min(idx, frameCount - 1)
}
```

Pure, no RNG, no clock. Two replays of the same save show the same scaffold at the same tick. This stays in CityRender2D so CityCore's framework-free invariant is preserved (no SpriteKit types leak in, and no scaffold-state field is added to `Building`). The reconciler reads `ticksSincePlacement` from the existing snapshot field; no new fields, no save-format change.

**Alternatives considered:**
- *Add a `constructionProgressFrame` field to `Building` in CityCore.* Rejected — pushes a presentation concern into the simulation core and changes the save format. The derivation is trivial; keep it on the render side.
- *Time-based construction frames (wall-clock).* Rejected — breaks determinism for screenshots / replay tests and looks wrong on a paused game.

### D4. Shared `SKAction` per animation key

For terrain, every visible tile of type `water` runs the same shimmer. We build the `SKAction` once per key (lazy, cached) and assign the same `SKAction` reference to every node:

```swift
node.run(SpriteAnimation.action(for: .terrain(.water)), withKey: "anim")
```

SpriteKit accepts the same `SKAction` instance on independent nodes; each node maintains its own playback state. This avoids allocating N actions for a screen full of water tiles.

**Trade-off:** all water tiles animate in phase (no per-tile offset). Acceptable for MVP — Anno 1602 also had in-phase water. If we want offsets later, switch to `SKAction.animate(with:timePerFrame:resize:restore:)` started with a per-node `SKAction.wait(forDuration:)` prefix, but that re-introduces per-tile allocations and we'll evaluate then.

### D5. Off-screen tiles never animate (free via reconciler)

The existing snapshot-reconciler already removes off-screen nodes from the scene tree (`Culling.visibleTileRange` + diff add/remove in `IsoWorldScene.reconcileSprites`). Removed nodes drop their actions. When a tile re-enters the view, `makeTerrainNode` / `makeBuildingNode` re-arms the action. No new culling logic needed.

For buildings whose `state` transitions `constructing → operational` while on-screen, the reconciler treats this as a `SpriteSpec` change (different cases in the discriminator) and replaces the node, which re-arms the right animation. Already validated by how `BuildingState` is part of the `SpriteSpec` key.

### D6. Sprite generation extended in one script

`scripts/generate-sprites.swift` already produces the walker walk cycle and the existing terrain/building PNGs. We extend it with helpers:

- `drawScaffold(stage: Int, totalStages: Int)` — overlay rising scaffold rectangles + tarpaulin on a building base.
- `drawSmoke(frame: Int)` — three small pixel puffs offset upward per frame, alpha-fading.
- `drawSaw(frame: Int)` — sawmill blade rotated 0° / 30° / 60° / 90°.
- `drawWaterShimmer(frame: Int)` — horizontal wave-line shift on the water diamond.

Frames are emitted to `Resources/Sprites/<existing-name>-<state>-<index>.png`. Original static `building-<kind>.png` remains as the operational-frame-0 fallback for kinds we don't animate, so the renderer's fallback path keeps working.

### D7. Determinism

CityCore is unchanged. Construction frame selection is a pure function of `Building.ticksSincePlacement` (already deterministic — incremented once per tick) and the static `buildDurationTicks` constant. Idle looped animations use SpriteKit wall-clock time, which is presentation-only and cannot influence the simulation. The `World` byte-identical-under-replay invariant is preserved.

### D8. Fallback paths

If any frame PNG is missing at runtime (e.g., contributor regenerated assets but forgot a frame), `SpriteAtlas.frames(for:)` returns `nil` and the scene falls back to:
1. The static single-frame PNG if present (e.g., `building-sawmill.png`).
2. The existing colored-diamond fallback if even the static is missing.

This matches the current behavior and ensures headless tests continue to work without bundled resources.

## Risks / Trade-offs

- **[Asset count grows ~2x]** → Mitigation: PNGs are tiny (32–96 px wide), nearest-neighbor; total bundle increase will be measured in tens of KB. Acceptable.
- **[Every-tile water animation could spike GPU on low-end iPads]** → Mitigation: shared `SKAction` (D4), 4 frames max, frame swap only (no shader). Culling keeps the count bounded to ~1k visible tiles. Profile on baseline iPad as part of the perf task; bail to a 2-frame cycle if it doesn't fit the 16.7 ms budget.
- **[Construction transition `constructing → operational` could pop visually]** → Mitigation: scaffold's last frame visually matches the operational building's silhouette; the reconciler replace happens on a tick boundary so it's a single-frame swap rather than mid-animation.
- **[Headless tests / package-only contexts have no bundled PNGs]** → Mitigation: the fallback chain in D8 means tests that don't exercise the renderer still pass. New CityRender2D tests for the catalog use synthetic textures (`SKTexture(imageNamed:)` returns a placeholder when missing; tests assert on catalog metadata, not bitmap content).
- **[Per-tile in-phase water might look uniform]** → Acceptable for the Anno 1602 reference. Per-tile phase offset is a follow-up if it feels off after playtest.
- **[`SpriteAtlas` cache grows]** → Already bounded by the small fixed set of `AnimationKey` values; the existing string-keyed cache continues to work since each PNG is still loaded once.

## Migration Plan

No data migration. No save-format change. No backward-incompatible runtime behavior — older saves load and animate based on `ticksSincePlacement` already in the snapshot. New PNGs ship alongside the existing ones; if a build doesn't include them, the renderer falls back to the static sprite per D8. Rollback is a clean revert of CityRender2D + Resources/Sprites/ commits with no cross-package effects.

## Open Questions

- Should water shimmer also apply to tiles adjacent to land (i.e., beach edge) or only to "deep water" tiles? Decision deferred until we look at the rendered result; trivial to opt-in per-tile via terrain enum.
- Sawmill animation should arguably only play when the building has input goods on its stockpile (`Building.stockpile.contains(.log)`). MVP plays it whenever `state == .operational`; producer-state-aware animation is a follow-up that needs a tiny snapshot accessor.
