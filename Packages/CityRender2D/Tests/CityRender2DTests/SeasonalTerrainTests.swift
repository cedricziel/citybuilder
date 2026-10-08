import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/add-calendar-and-events.

@MainActor
private final class FixedSnapshot: IsoWorldDataSource {
    let snapshot: WorldSnapshot
    init(_ snapshot: WorldSnapshot) {
        self.snapshot = snapshot
    }

    func currentSnapshot() -> WorldSnapshot? {
        snapshot
    }
}

private func grassSnapshot(season: Season) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1).snapshot()
    return WorldSnapshot(
        tickCount: base.tickCount, simulatedTime: base.simulatedTime, mapWidth: base.mapWidth,
        mapHeight: base.mapHeight, terrainGrid: base.terrainGrid, occupiedTiles: base.occupiedTiles,
        buildings: base.buildings, carriers: base.carriers, economy: base.economy,
        totalPopulation: base.totalPopulation, camera: base.camera,
        date: GameDate(year: 1200, season: season)
    )
}

@MainActor
private func renderedGrassTextureNames(season: Season) -> [String?] {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.hasSprite = { _ in true }
    let source = FixedSnapshot(grassSnapshot(season: season))
    scene.dataSource = source
    scene.update(0)
    return scene.children.compactMap { $0 as? SKSpriteNode }.filter { $0.zPosition == 0 }
        .map { $0.userData?[IsoWorldScene.textureNameKey] as? String }
}

@MainActor
@Test("scenario: winter tints grass")
func scenarioWinterTintsGrass() {
    let names = renderedGrassTextureNames(season: .winter)
    #expect(!names.isEmpty)
    #expect(names.allSatisfy { $0 == "terrain-grass-winter" })
}

@MainActor
@Test("scenario: summer has no tint")
func scenarioSummerHasNoTint() {
    let names = renderedGrassTextureNames(season: .summer)
    #expect(!names.isEmpty)
    #expect(names.allSatisfy { $0 == nil })
}
