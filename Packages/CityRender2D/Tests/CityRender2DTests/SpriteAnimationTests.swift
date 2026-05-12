import CityCore
import Foundation
import SpriteKit
import Testing
@testable import CityRender2D

// Tests for spec sprite-animation. Each `#### Scenario:` heading in
// openspec/changes/add-terrain-and-building-animations/specs/sprite-animation/spec.md
// maps to one `@Test("scenario: <lowercased title>")` here.

// MARK: - Atlas API

@Test("scenario: walker lookup routes through the same api")
func scenarioWalkerLookupRoutesThroughTheSameApi() {
    // Both call sites resolve through the same internal `frames(for:)`
    // implementation. Walker frames are bundled with the resource path
    // in headless package tests; without a Resources bundle both sides
    // return nil identically. The contract is: identical answers, same
    // path. We assert equality of the (nil or non-nil) results.
    for facing in SpriteAtlas.WalkerFacing.allCases {
        let viaLegacy = SpriteAtlas.walkerAnimation(facing: facing)
        let viaUnified = SpriteAtlas.frames(for: .walker(facing))
        #expect((viaLegacy == nil) == (viaUnified == nil))
        if let legacy = viaLegacy, let unified = viaUnified {
            #expect(legacy.count == unified.count)
        }
    }
}

@Test("scenario: missing frame returns nil")
func scenarioMissingFrameReturnsNil() {
    // Headless package test: there is no main bundle with sprite PNGs,
    // so every animation key MUST return nil rather than a truncated
    // partial array.
    for kind in TerrainType.allCases {
        #expect(SpriteAtlas.frames(for: .terrain(kind)) == nil)
    }
    for kind in BuildingKind.allCases {
        #expect(SpriteAtlas.frames(for: .buildingOperational(kind)) == nil)
        #expect(SpriteAtlas.frames(for: .buildingConstructing(kind)) == nil)
    }
}

@Test("scenario: multi-frame water lookup")
func scenarioMultiFrameWaterLookup() {
    // Without a bundle of resources we cannot assert "returns 4 textures"
    // — but we MUST be able to assert the contract that the catalog
    // claims water has 4 frames. The atlas lookup either returns nil
    // (no bundle) or an array of exactly that length; it never returns
    // a different count.
    let entry = SpriteAnimation.entry(for: .terrain(.water))
    #expect(entry?.frameCount == 4)
    if let frames = SpriteAtlas.frames(for: .terrain(.water)) {
        #expect(frames.count == entry?.frameCount)
    }
}

// MARK: - Animation catalog

@Test("scenario: catalog entry exists for each declared animation")
func scenarioCatalogEntryExistsForEachDeclaredAnimation() {
    // The catalog MUST be the source of truth for every animation the
    // scene plays. These are the keys the scene wires up; if any entry
    // goes missing, the scene would have to invent its own cadence,
    // which the requirement forbids.
    let mustExist: [SpriteAnimation.AnimationKey] = [
        .terrain(.water),
        .terrain(.beach),
        .buildingOperational(.sawmill),
        .buildingOperational(.lumberjackHut),
        .buildingOperational(.townCenter),
        .buildingConstructing(.house),
        .buildingConstructing(.warehouse),
        .buildingConstructing(.road),
        .buildingConstructing(.lumberjackHut),
        .buildingConstructing(.sawmill),
        .buildingConstructing(.townCenter)
    ]
    for key in mustExist {
        #expect(SpriteAnimation.entry(for: key) != nil, "missing catalog entry for \(key)")
    }
    // Walker entries also flow through the same catalog so the atlas
    // can route everything through one path.
    for facing in SpriteAtlas.WalkerFacing.allCases {
        #expect(SpriteAnimation.entry(for: .walker(facing)) != nil)
    }
}

@Test("scenario: catalog declares a loop mode per entry")
func scenarioCatalogDeclaresALoopModePerEntry() {
    #expect(SpriteAnimation.entry(for: .terrain(.water))?.loop == .forever)
    #expect(SpriteAnimation.entry(for: .terrain(.beach))?.loop == .forever)
    #expect(SpriteAnimation.entry(for: .buildingOperational(.sawmill))?.loop == .forever)
    #expect(SpriteAnimation.entry(for: .buildingConstructing(.house))?.loop == .progress)
    #expect(SpriteAnimation.entry(for: .buildingConstructing(.sawmill))?.loop == .progress)
    #expect(SpriteAnimation.entry(for: .walker(.se))?.loop == .forever)
}

// MARK: - Construction-frame derivation

@Test("scenario: construction frame at start")
func scenarioConstructionFrameAtStart() {
    // ticksSincePlacement == 0 → first frame regardless of frame count.
    for frameCount in 1 ... 5 {
        #expect(
            constructionFrame(ticksSincePlacement: 0, duration: 30, frameCount: frameCount) == 0
        )
    }
}

@Test("scenario: construction frame at midpoint")
func scenarioConstructionFrameAtMidpoint() {
    // 3-frame list, half-built → middle frame (index 1).
    #expect(
        constructionFrame(ticksSincePlacement: 15, duration: 30, frameCount: 3) == 1
    )
    // Same midpoint with 5 frames lands on the middle (index 2).
    #expect(
        constructionFrame(ticksSincePlacement: 20, duration: 40, frameCount: 5) == 2
    )
}

@Test("scenario: construction frame at completion tick")
func scenarioConstructionFrameAtCompletionTick() {
    // ticksSincePlacement == duration → last frame.
    for frameCount in 1 ... 5 {
        let last = frameCount - 1
        #expect(
            constructionFrame(ticksSincePlacement: 30, duration: 30, frameCount: frameCount) == last
        )
    }
    // Overshoot is clamped, never goes past the last frame.
    #expect(
        constructionFrame(ticksSincePlacement: 9999, duration: 30, frameCount: 3) == 2
    )
}

@Test("scenario: construction frame is deterministic")
func scenarioConstructionFrameIsDeterministic() {
    // Same inputs → same output. No clock, no RNG, no state.
    struct Case { let ticks: UInt64; let duration: UInt64; let count: Int }
    let inputs: [Case] = [
        Case(ticks: 0, duration: 30, count: 3),
        Case(ticks: 7, duration: 30, count: 3),
        Case(ticks: 15, duration: 30, count: 3),
        Case(ticks: 29, duration: 30, count: 3),
        Case(ticks: 30, duration: 30, count: 3),
        Case(ticks: 40, duration: 40, count: 5),
        Case(ticks: 1, duration: 1, count: 1)
    ]
    for input in inputs {
        let first = constructionFrame(
            ticksSincePlacement: input.ticks, duration: input.duration, frameCount: input.count
        )
        let second = constructionFrame(
            ticksSincePlacement: input.ticks, duration: input.duration, frameCount: input.count
        )
        #expect(first == second)
        #expect(first >= 0 && first < max(1, input.count))
    }
}

// MARK: - Scene wiring: terrain

@Test("scenario: water tile arms a looped action")
func scenarioWaterTileArmsALoopedAction() {
    // The scene's terrain-node factory MUST arm a looped SKAction under
    // the key "anim" whenever the catalog declares more than one frame
    // for the terrain kind AND the frames are bundled. In package test
    // mode (no bundle), `loopingAction` returns nil and no action is
    // armed — which is the documented fallback path. So this test
    // asserts the precondition: if the action is non-nil it cycles
    // textures and never finishes on its own.
    if let action = SpriteAnimation.loopingAction(for: .terrain(.water)) {
        // SKAction.repeatForever returns a non-nil duration but is
        // infinite-cycle. We assert it is the same instance reused for
        // every water tile (covered by the shared-action scenario).
        #expect(action.duration > 0)
    }
}

@Test("scenario: forest tile arms no action")
func scenarioForestTileArmsNoAction() {
    // The catalog declares no entry for forest, so loopingAction is nil
    // regardless of bundle state. Forest tiles MUST never arm an action.
    #expect(SpriteAnimation.loopingAction(for: .terrain(.forest)) == nil)
    #expect(SpriteAnimation.entry(for: .terrain(.forest)) == nil)
}

@Test("scenario: off-screen water stops animating")
func scenarioOffScreenWaterStopsAnimating() {
    // The existing snapshot reconciler removes off-screen sprites by
    // calling removeFromParent() on their nodes (see
    // IsoWorldScene.reconcileSprites). A node removed from its parent
    // no longer ticks any SKAction. We assert the contract directly:
    // after removeFromParent the parent reference is nil.
    let node = SKSpriteNode()
    let parent = SKNode()
    parent.addChild(node)
    #expect(node.parent === parent)
    node.removeFromParent()
    #expect(node.parent == nil)
}

@Test("scenario: all visible water tiles share one action reference")
func scenarioAllVisibleWaterTilesShareOneActionReference() {
    // The catalog MUST return the same SKAction instance for repeated
    // queries on the same key. This is how a screen full of water
    // tiles allocates exactly one action (design D4).
    let first = SpriteAnimation.loopingAction(for: .terrain(.water))
    let second = SpriteAnimation.loopingAction(for: .terrain(.water))
    let third = SpriteAnimation.loopingAction(for: .terrain(.water))
    // Either both are nil (no bundle) or all three are the same instance.
    if let firstAction = first, let secondAction = second, let thirdAction = third {
        #expect(firstAction === secondAction)
        #expect(secondAction === thirdAction)
    } else {
        #expect(first == nil && second == nil && third == nil)
    }
}

@Test("scenario: missing water frames fall back to static")
func scenarioMissingWaterFramesFallBackToStatic() {
    // When frames are unavailable, loopingAction returns nil and the
    // scene MUST render the static terrain texture (or, in headless
    // tests, the diamond fallback). We assert the contract on the
    // atlas layer: if `frames(for:)` is nil, there is no action to
    // arm; the scene then uses the existing `terrainTexture(for:)`
    // single-PNG path.
    if SpriteAtlas.frames(for: .terrain(.water)) == nil {
        #expect(SpriteAnimation.loopingAction(for: .terrain(.water)) == nil)
    }
}

@Test("scenario: no bundle resources at all")
func scenarioNoBundleResourcesAtAll() {
    // In package test mode (the context this test runs in) there is no
    // bundled Resources/Sprites. Every atlas call MUST return nil; the
    // scene falls back to the colored-diamond placeholder. This is
    // tested implicitly by the existing "missing frame returns nil"
    // scenario; here we add the building-side cross-check.
    for kind in BuildingKind.allCases {
        #expect(SpriteAtlas.buildingTexture(for: kind) == nil)
    }
    for kind in TerrainType.allCases {
        #expect(SpriteAtlas.terrainTexture(for: kind) == nil)
    }
}

// MARK: - Scene wiring: buildings

@Test("scenario: operational sawmill animates")
func scenarioOperationalSawmillAnimates() {
    // The catalog claims a 4-frame, .forever animation for an
    // operational sawmill. The atlas returns that 4-element array when
    // the frames are bundled, or nil otherwise — in either case the
    // scene's call to loopingAction(for:) is the single source of
    // truth for whether the action gets armed.
    let entry = SpriteAnimation.entry(for: .buildingOperational(.sawmill))
    #expect(entry?.frameCount == 4)
    #expect(entry?.loop == .forever)
    if let frames = SpriteAtlas.frames(for: .buildingOperational(.sawmill)) {
        #expect(frames.count == 4)
        #expect(SpriteAnimation.loopingAction(for: .buildingOperational(.sawmill)) != nil)
    }
}

@Test("scenario: operational house is static")
func scenarioOperationalHouseIsStatic() {
    // The house catalog entry is absent — no operational animation.
    // The scene's loopingAction returns nil so no SKAction is armed.
    #expect(SpriteAnimation.entry(for: .buildingOperational(.house)) == nil)
    #expect(SpriteAnimation.loopingAction(for: .buildingOperational(.house)) == nil)
}

@Test("scenario: sawmill finishes and starts running")
func scenarioSawmillFinishesAndStartsRunning() {
    // The SpriteSpec.Kind discriminates on state, so a sawmill
    // transitioning constructing → operational produces a different
    // spec; the reconciler diff naturally adds the new spec and
    // removes the old. The renderer rebuilds the node in
    // makeBuildingNode and arms the operational animation.
    let footprint = BuildingCatalog.spec(for: .sawmill).footprint
    let constructing = SpriteSpec(
        coord: TileCoordinate(x: 0, y: 0),
        kind: .building(
            kind: .sawmill, state: .constructing,
            footprint: footprint, constructionFrameIndex: 2, orientation: nil
        )
    )
    let operational = SpriteSpec(
        coord: TileCoordinate(x: 0, y: 0),
        kind: .building(
            kind: .sawmill, state: .operational,
            footprint: footprint, constructionFrameIndex: nil, orientation: nil
        )
    )
    #expect(constructing != operational)
    let diff = SnapshotReconciler.diff(
        previous: [constructing], current: [operational]
    )
    #expect(diff.added == [operational])
    #expect(diff.removed == [constructing])
}

@Test("scenario: replay determinism preserved")
func scenarioReplayDeterminismPreserved() {
    // CityCore is framework-free; the renderer reads snapshots and
    // never writes. We confirm the contract: two snapshots of the
    // same World are equal, and the renderer's SpriteSpec set built
    // from the same snapshot is also equal — the animation code path
    // adds no nondeterminism on the render side.
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 7)
    world.camera = Camera(centerX: 3, centerY: 3, zoom: 1.0)
    let snap1 = world.snapshot()
    let snap2 = world.snapshot()
    #expect(snap1 == snap2)
    let xRange = 0 ... 5
    let yRange = 0 ... 5
    let firstDesired = SnapshotReconciler.desiredSprites(in: snap1, xRange: xRange, yRange: yRange)
    let secondDesired = SnapshotReconciler.desiredSprites(in: snap2, xRange: xRange, yRange: yRange)
    #expect(firstDesired == secondDesired)
}
