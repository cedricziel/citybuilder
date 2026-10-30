import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/visible-distribution (rendering-2_5d / Market porters render).

private func snapshot(tick: UInt64, porters: [Porter]) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 10, height: 10, fill: .grass, seed: 1).snapshot()
    return WorldSnapshot(
        tickCount: tick, simulatedTime: base.simulatedTime, mapWidth: 10, mapHeight: 10,
        terrainGrid: base.terrainGrid, occupiedTiles: [:], buildings: [:], carriers: [], porters: porters,
        economy: base.economy, totalPopulation: 0, camera: base.camera
    )
}

private let path = [TileCoordinate(x: 1, y: 1), TileCoordinate(x: 2, y: 1), TileCoordinate(x: 3, y: 1)]

private func porter(at index: Int, returning: Bool) -> Porter {
    Porter(
        id: EntityID(raw: 7), hub: EntityID(raw: 1), house: EntityID(raw: 2), path: returning ? path.reversed() : path,
        pathIndex: index, basket: returning ? [] : [Porter.Load(good: .food, units: 2)], returning: returning
    )
}

@MainActor
@Test("scenario: A loaded porter shows full baskets")
func loadedPorterShowsFullBaskets() throws {
    let scene = IsoWorldScene()
    scene.reconcileCarriers(with: snapshot(tick: 1, porters: [porter(at: 0, returning: false)]), now: 0)
    let visual = try #require(scene.carrierVisuals[EntityID(raw: 7)])
    #expect(visual.look.figure == .porter(empty: false))
    #expect(visual.look.facing == .se)
    #expect(visual.walking)
}

@MainActor
@Test("scenario: A returning porter shows empty baskets")
func returningPorterShowsEmptyBaskets() throws {
    let scene = IsoWorldScene()
    scene.reconcileCarriers(with: snapshot(tick: 1, porters: [porter(at: 0, returning: true)]), now: 0)
    let visual = try #require(scene.carrierVisuals[EntityID(raw: 7)])
    #expect(visual.look.figure == .porter(empty: true))
    #expect(visual.look.facing == .nw)
    scene.reconcileCarriers(with: snapshot(tick: 2, porters: []), now: 0.1)
    #expect(scene.carrierVisuals.isEmpty)
}

@Test("the porter's frames are their own walk cycles, filled and empty")
func porterFrames() {
    #expect(SpriteAnimation.assetName(for: .porter(.ne, empty: false), frame: 0) == "porter-ne-0")
    #expect(SpriteAnimation.assetName(for: .porter(.sw, empty: true), frame: 7) == "porter-empty-sw-7")
    #expect(SpriteAnimation.entry(for: .porter(.se, empty: true))?.frameCount == 8)
    #expect(SpriteAtlasRouting.atlasName(for: "porter-empty-ne-0") == SpriteAtlasRouting.kitAtlasName)
}
