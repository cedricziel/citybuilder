import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

@MainActor
private final class Snapshots: IsoWorldDataSource {
    var snapshot: WorldSnapshot
    init(_ snapshot: WorldSnapshot) {
        self.snapshot = snapshot
    }

    func currentSnapshot() -> WorldSnapshot? {
        snapshot
    }
}

/// Houses at the given anchors, all operational, on a grass map.
private func town(_ anchors: [TileCoordinate]) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 16, height: 16, fill: .grass, seed: 1).snapshot()
    var buildings: [EntityID: Building] = [:]
    var tiles: [TileCoordinate: EntityID] = [:]
    for (index, anchor) in anchors.enumerated() {
        let id = EntityID(raw: UInt32(index + 1))
        buildings[id] = Building(id: id, kind: .house, anchor: anchor, state: .operational)
        for tile in BuildingCatalog.spec(for: .house).footprint.tiles(anchor: anchor) {
            tiles[tile] = id
        }
    }
    return WorldSnapshot(
        tickCount: 100, simulatedTime: base.simulatedTime, mapWidth: 16, mapHeight: 16,
        terrainGrid: base.terrainGrid, occupiedTiles: tiles, buildings: buildings, carriers: [],
        economy: base.economy, totalPopulation: 0, camera: Camera(centerX: 8, centerY: 8, zoom: 1)
    )
}

/// A ghost that swaps its texture (another building armed) takes the new sprite's size, not the old one's.
@MainActor
@Test("the placement ghost takes its texture's size")
func ghostTakesItsTexturesSize() throws {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    let source = Snapshots(town([]))
    scene.dataSource = source
    scene.ghostProvider = { IsoWorldScene.GhostState(kind: .house, tile: TileCoordinate(x: 8, y: 8), valid: true) }
    scene.update(0)
    let ghost = try #require(scene.ghostNode)
    ghost.size = CGSize(width: 1, height: 1)
    scene.update(0.1)
    #expect(ghost.size == ghost.texture?.size())
}
