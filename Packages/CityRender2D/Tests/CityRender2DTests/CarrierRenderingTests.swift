import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/add-carrier-glide.

private func snapshot(carriers: [Carrier]) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 10, height: 10, fill: .grass, seed: 1).snapshot()
    return WorldSnapshot(
        tickCount: 1, simulatedTime: base.simulatedTime, mapWidth: 10, mapHeight: 10,
        terrainGrid: base.terrainGrid, occupiedTiles: [:], buildings: [:], carriers: carriers,
        economy: base.economy, totalPopulation: 0, camera: base.camera
    )
}

private func carrier(at index: Int, good: Good = .planks) -> Carrier {
    Carrier(
        id: EntityID(raw: 7),
        path: [TileCoordinate(x: 1, y: 1), TileCoordinate(x: 2, y: 1), TileCoordinate(x: 3, y: 1)],
        pathIndex: index,
        mission: .deliver(good: good, amount: 1, fromProducer: EntityID(raw: 1), toWarehouse: EntityID(raw: 2))
    )
}

@MainActor
@Test("scenario: carrier glides between tiles")
func scenarioCarrierGlidesBetweenTiles() throws {
    let scene = IsoWorldScene()
    scene.reconcileCarriers(with: snapshot(carriers: [carrier(at: 0)]), now: 0)
    let node = try #require(scene.carrierVisuals[EntityID(raw: 7)]?.node)
    let start = node.position
    #expect(node.action(forKey: SKNode.glideKey) == nil)
    var next = snapshot(carriers: [carrier(at: 1)])
    next.tickCount = 2
    scene.reconcileCarriers(with: next, now: 0.1)
    #expect(node.action(forKey: SKNode.glideKey) != nil)
    #expect(node.position == start, "the node moves by action, not by a jump")
    var gone = snapshot(carriers: [])
    gone.tickCount = 3
    scene.reconcileCarriers(with: gone, now: 0.2)
    #expect(scene.carrierVisuals.isEmpty && node.parent == nil)
}

@Test("scenario: load family from the good")
func scenarioLoadFamilyFromTheGood() {
    #expect([Good.planks, .beer, .flour, .tools].map(CarrierLoad.family(of:)) == [.logs, .barrel, .sack, .crate])
    #expect(carrier(at: 0, good: .wine).good == .wine)
}

@Test("scenario: carrier sprite falls back to the walker")
func scenarioCarrierSpriteFallsBackToTheWalker() {
    // Test bundles carry no atlases, so the carrier frames are missing.
    #expect(SpriteAtlas.frames(for: .carrier(.sack, .se)) == nil)
    #expect(SpriteAtlas.carrierAnimation(load: .sack, facing: .se) == SpriteAtlas.walkerAnimation(facing: .se))
    #expect(SpriteAnimation.assetName(for: .carrier(.sack, .se), frame: 1) == "carrier-sack-se-1")
    #expect(SpriteAnimation.entry(for: .carrier(.sack, .se)) == SpriteAnimation.entry(for: .walker(.se)))
    #expect(SpriteAtlasRouting.atlasName(for: "carrier-sack-se-0") == SpriteAtlasRouting.unitsAtlasName)
}
