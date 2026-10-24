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

/// Child indices of the houses at `left` and `right`, after the scene has shown each snapshot in turn.
@MainActor
private func order(_ snapshots: [WorldSnapshot], left: TileCoordinate, right: TileCoordinate) throws -> (Int, Int) {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 2048, height: 1536)
    scene.hasSprite = { _ in true }
    let source = Snapshots(snapshots[0])
    scene.dataSource = source
    for snapshot in snapshots {
        source.snapshot = snapshot
        scene.update(0)
    }
    let leftNode = try #require(scene.buildingNodes[left]), rightNode = try #require(scene.buildingNodes[right])
    #expect(leftNode.zPosition == rightNode.zPosition)
    #expect(leftNode.position.x < rightNode.position.x)
    let layer = try #require(leftNode.parent)
    #expect(rightNode.parent === layer)
    return try (#require(layer.children.firstIndex(of: leftNode)), #require(layer.children.firstIndex(of: rightNode)))
}

/// Side by side at one depth, two wide sprites overlap; the right one must draw last every time, or a
/// shadow comes and goes on its wall after a pan or a relaunch.
@MainActor
@Test("equal-depth buildings draw left to right, whichever comes on screen first")
func equalDepthBuildingsDrawLeftToRight() throws {
    // Same x + y, so the same depth; (6, 4) sits to the right of (4, 6) on screen.
    let left = TileCoordinate(x: 4, y: 6), right = TileCoordinate(x: 6, y: 4)
    let together = try order([town([right, left])], left: left, right: right)
    #expect(together.0 < together.1)
    let rightFirst = try order([town([right]), town([right, left])], left: left, right: right)
    #expect(rightFirst.0 < rightFirst.1)
    let leftFirst = try order([town([left]), town([left, right])], left: left, right: right)
    #expect(leftFirst.0 < leftFirst.1)
}
