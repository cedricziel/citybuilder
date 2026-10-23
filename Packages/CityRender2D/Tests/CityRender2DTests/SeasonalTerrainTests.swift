import CityCore
import SpriteKit
import Synchronization
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

/// All grass, or with `shore` the eastern half (x >= 4) beach.
private func grassSnapshot(season: Season, shore: Bool = false) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1).snapshot()
    let grid = shore ? base.terrainGrid.enumerated().map { $0.offset % 8 >= 4 ? .beach : $0.element } : base.terrainGrid
    return WorldSnapshot(
        tickCount: base.tickCount, simulatedTime: base.simulatedTime, mapWidth: base.mapWidth,
        mapHeight: base.mapHeight, terrainGrid: grid, occupiedTiles: base.occupiedTiles,
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
    #expect(names.allSatisfy { $0?.hasPrefix("terrain-grass-winter") == true })
}

@MainActor
@Test("scenario: summer has no tint")
func scenarioSummerHasNoTint() {
    let names = renderedGrassTextureNames(season: .summer)
    #expect(!names.isEmpty)
    #expect(names.allSatisfy { $0 == "terrain-grass" || $0?.hasPrefix("terrain-grass-v") == true })
}

/// Grass changes with the season, so the shore that blends it does too, and a season change
/// redraws the shore even on tiles whose own terrain is beach.
@MainActor
@Test("scenario: Shores follow the season")
func shoresFollowTheSeason() {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.hasSprite = { _ in true }
    let shoreNames = {
        scene.children.compactMap { $0.userData?[IsoWorldScene.textureNameKey] as? String }
            .filter { $0.hasPrefix("terrain-grass-beach-") }
    }
    let spring = FixedSnapshot(grassSnapshot(season: .spring, shore: true))
    scene.dataSource = spring
    scene.update(0)
    #expect(!shoreNames().isEmpty)
    #expect(shoreNames().allSatisfy { !$0.hasSuffix("-autumn") })
    let autumn = FixedSnapshot(grassSnapshot(season: .autumn, shore: true))
    scene.dataSource = autumn
    scene.update(1)
    #expect(!shoreNames().isEmpty)
    #expect(shoreNames().allSatisfy { $0.hasSuffix("-autumn") })
}

/// Spring and summer share every terrain sprite, so turning from one to the other redraws nothing.
@MainActor
@Test("a season change that keeps the look keeps the terrain nodes")
func seasonChangeWithoutNewLookKeepsNodes() {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.hasSprite = { _ in true }
    let terrainNodes = { Set(scene.children.filter { $0.zPosition == 0 }.map(ObjectIdentifier.init)) }
    let spring = FixedSnapshot(grassSnapshot(season: .spring, shore: true))
    scene.dataSource = spring
    scene.update(0)
    let before = terrainNodes()
    let summer = FixedSnapshot(grassSnapshot(season: .summer, shore: true))
    scene.dataSource = summer
    scene.update(1)
    #expect(!before.isEmpty)
    #expect(terrainNodes() == before)
}

@MainActor
@Test("a shore without a seasonal set keeps its plain transition")
func shoreWithoutSeasonalSetKeepsPlainTransition() {
    let scene = IsoWorldScene()
    scene.appliedSeason = .winter
    let transition = TerrainTransition(upper: .grass, lower: .beach, mask: 3)
    scene.hasSprite = { $0 == transition.assetName }
    let node = scene.makeTerrainNode(kind: .beach, coord: TileCoordinate(x: 0, y: 0), transition: transition)
    #expect(node.userData?[IsoWorldScene.textureNameKey] as? String == "terrain-grass-beach-t3")
    #expect(transition.assetName(in: .winter) == "terrain-grass-beach-t3-winter")
    #expect(TerrainTransition(upper: .beach, lower: .water, mask: 3).assetName(in: .winter) == "terrain-beach-water-t3")
}

@MainActor
@Test("scenario: Grass variants are stable per tile")
func grassVariantsAreStablePerTile() {
    let first = renderedGrassTextureNames(season: .summer).compactMap(\.self).sorted()
    let second = renderedGrassTextureNames(season: .summer).compactMap(\.self).sorted()
    #expect(first == second)
    #expect(Set(first).count > 1)
    // Across a season change every tile keeps its variant, in the season's look.
    let winter = renderedGrassTextureNames(season: .winter).compactMap(\.self).sorted()
    let summerAsWinter = first.map { $0.replacingOccurrences(of: "terrain-grass", with: "terrain-grass-winter") }.sorted()
    #expect(winter == summerAsWinter)
}

/// A missing grass variant falls back to the plain tile and says so, once.
@MainActor
@Test("A missing grass variant falls back to the plain tile and is logged once")
func missingGrassVariantIsLoggedOnce() {
    let logged = Mutex<[String]>([])
    let scene = IsoWorldScene()
    scene.missLog = MissLog { name in logged.withLock { $0.append(name) } }
    scene.size = CGSize(width: 1024, height: 768)
    scene.hasSprite = { !$0.contains("-v") }
    scene.dataSource = FixedSnapshot(grassSnapshot(season: .summer))
    scene.update(0)
    let names = scene.children.compactMap { $0.userData?[IsoWorldScene.textureNameKey] as? String }
    #expect(!names.isEmpty && names.allSatisfy { $0 == "terrain-grass" })
    let variants = logged.withLock { $0.filter { $0.hasPrefix("terrain-grass-v") } }
    #expect(!variants.isEmpty)
    #expect(variants.count == Set(variants).count)
}
