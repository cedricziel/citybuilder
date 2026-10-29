import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// add-event-counterplay task 8.2 (rendering-2_5d / Seasonal events are drawn on the map): the watchman
// is a walker with a bucket, never a carrier.

private func snapshot(tick: UInt64, watchmen: [WatchmanWalker]) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 10, height: 10, fill: .grass, seed: 1).snapshot()
    return WorldSnapshot(
        tickCount: tick, simulatedTime: base.simulatedTime, mapWidth: 10, mapHeight: 10,
        terrainGrid: base.terrainGrid, occupiedTiles: [:], buildings: [:], carriers: [],
        economy: base.economy, totalPopulation: 0, camera: base.camera, watchmen: watchmen
    )
}

private let path = [TileCoordinate(x: 1, y: 1), TileCoordinate(x: 2, y: 1), TileCoordinate(x: 3, y: 1)]

private func watchman(at index: Int, dousing: Bool = false) -> WatchmanWalker {
    WatchmanWalker(watch: EntityID(raw: 5), fire: EntityID(raw: 6), path: path, pathIndex: index, isDousing: dousing)
}

@MainActor
@Test("scenario: the watchman walks with his bucket, then stands while he douses")
func watchmanWalksThenStands() throws {
    let scene = IsoWorldScene()
    scene.reconcileCarriers(with: snapshot(tick: 1, watchmen: [watchman(at: 0)]), now: 0)
    let walking = try #require(scene.carrierVisuals[EntityID(raw: 5)])
    #expect(walking.look.figure == .watchman)
    #expect(walking.look.facing == .se)
    #expect(walking.walking)
    scene.reconcileCarriers(with: snapshot(tick: 2, watchmen: [watchman(at: 2, dousing: true)]), now: 0.1)
    let dousing = try #require(scene.carrierVisuals[EntityID(raw: 5)])
    #expect(!dousing.walking)
    // He keeps facing the way he came, toward the fire.
    #expect(dousing.look.facing == .se)
    scene.reconcileCarriers(with: snapshot(tick: 3, watchmen: []), now: 0.2)
    #expect(scene.carrierVisuals.isEmpty)
}

@Test("the watchman's frames are his own walk cycle")
func watchmanFrames() {
    #expect(SpriteAnimation.assetName(for: .watchman(.ne), frame: 0) == "walker-watchman-ne-0")
    #expect(SpriteAtlasRouting.atlasName(for: "walker-watchman-ne-0") == SpriteAtlasRouting.kitAtlasName)
}
