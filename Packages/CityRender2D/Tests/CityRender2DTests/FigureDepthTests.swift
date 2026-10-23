import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// realistic-walkers (rendering-2_5d / Figures sort by where they stand): measured on the nodes a real
// scene places, not on the depth formula.

/// A data source handing the scene one snapshot.
@MainActor
final class FixedSnapshotSource: IsoWorldDataSource {
    var snapshot: WorldSnapshot
    init(_ snapshot: WorldSnapshot) {
        self.snapshot = snapshot
    }

    func currentSnapshot() -> WorldSnapshot? {
        snapshot
    }
}

/// A 12 × 12 meadow: a house anchored at (4, 4) (tiles 4–5 × 4–5), a road along its back edge (row 3)
/// and down its right side (column 6), one forest tile at (9, 9), and a carrier on the back road.
private func town(carrierPath: [TileCoordinate]) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 12, height: 12, fill: .grass, seed: 1).snapshot()
    let grid = base.terrainGrid.indices.map { $0 == 9 * 12 + 9 ? TerrainType.forest : .grass }
    var buildings = [Building(id: EntityID(raw: 1), kind: .house, anchor: TileCoordinate(x: 4, y: 4), state: .operational)]
    let roads = (2 ... 7).map { TileCoordinate(x: $0, y: 3) } + (4 ... 8).map { TileCoordinate(x: 6, y: $0) }
    for (index, tile) in roads.enumerated() {
        buildings.append(Building(id: EntityID(raw: UInt32(10 + index)), kind: .road, anchor: tile, state: .operational))
    }
    var occupied: [TileCoordinate: EntityID] = [:]
    for building in buildings {
        for tile in BuildingCatalog.spec(for: building.kind).footprint.tiles(anchor: building.anchor) {
            occupied[tile] = building.id
        }
    }
    let carrier = Carrier(
        id: EntityID(raw: 99), path: carrierPath,
        mission: .deliver(good: .wood, amount: 1, fromProducer: EntityID(raw: 1), toWarehouse: EntityID(raw: 2))
    )
    return WorldSnapshot(
        tickCount: 1, simulatedTime: base.simulatedTime, mapWidth: 12, mapHeight: 12, terrainGrid: grid,
        occupiedTiles: occupied, buildings: Dictionary(uniqueKeysWithValues: buildings.map { ($0.id, $0) }), carriers: [carrier],
        economy: base.economy, totalPopulation: 0, camera: Camera(centerX: 6, centerY: 6, zoom: 1)
    )
}

/// The scene drawing `town`, and a way to stand its carrier at fractional tile (x, y) and read the z the
/// scene then gives it.
@MainActor
private func scene(carrierPath: [TileCoordinate]) throws -> (IsoWorldScene, (Double, Double) -> CGFloat) {
    let snapshot = town(carrierPath: carrierPath)
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.hasSprite = { _ in true }
    scene.dataSource = FixedSnapshotSource(snapshot)
    scene.update(0)
    let node = try #require(scene.carrierVisuals[EntityID(raw: 99)]?.node)
    var now: TimeInterval = 0
    let stand = { (x: Double, y: Double) -> CGFloat in
        node.position = IsoMath.screenPoint(forTileFractionalX: x + 0.5, fractionalY: y + 0.5)
        now += 0.01
        scene.reconcileCarriers(with: snapshot, now: now)
        return node.zPosition
    }
    return (scene, stand)
}

private let steps: [Double] = [0, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 1]

@MainActor
@Test("a figure behind a house is hidden by it; in front, or level beside it, it draws over it")
func figuresSortAgainstAPlacedHouse() throws {
    let (scene, stand) = try scene(carrierPath: [TileCoordinate(x: 3, y: 3), TileCoordinate(x: 4, y: 3)])
    let house = try #require(scene.buildingNodes[TileCoordinate(x: 4, y: 4)]).zPosition
    // Along the back road, and stepping from behind the house out to the tile beside its corner.
    for x in [3.0, 4, 5] {
        #expect(stand(x, 3) < house, "behind at (\(x), 3)")
    }
    for along in steps.dropLast() {
        #expect(stand(5 + along, 3) < house, "stepping out, \(along) of the way")
    }
    // Level with the house's centre, beside its corner, and on the road down its right side.
    #expect(stand(6, 3) > house)
    for y in [4.0, 5, 6, 7] {
        #expect(stand(6, y) > house, "in front at (6, \(y))")
    }
}

@MainActor
@Test("a figure walking a road draws over every road tile it crosses, down-screen and up-screen")
func figuresStayOnTopOfTheRoad() throws {
    let (scene, stand) = try scene(carrierPath: [TileCoordinate(x: 6, y: 4), TileCoordinate(x: 6, y: 5)])
    let roads = try [4, 5, 6].map { y in try #require(scene.buildingNodes[TileCoordinate(x: 6, y: y)]).zPosition }
    let top = try #require(roads.max())
    for along in steps {
        #expect(stand(6, 4 + along) > top, "down-screen, \(along) of the step")
        #expect(stand(6, 6 - along) > top, "up-screen, \(along) of the step")
    }
}

@MainActor
@Test("a figure passing behind a tree clump stays behind it until it is all but level with it")
func figuresStayBehindATreeClump() throws {
    let (scene, stand) = try scene(carrierPath: [TileCoordinate(x: 9, y: 8), TileCoordinate(x: 10, y: 8)])
    let ground = try #require(scene.presentSprites.first { spec, _ in
        guard case .terrain = spec.kind else { return false }
        return spec.coord == TileCoordinate(x: 9, y: 9)
    }?.value)
    // Over plain ground the clump stands alone; over a transition it rides on its ground node.
    let clump = try #require(ground.name == IsoWorldScene.terrainObjectNodeName
        ? ground : ground.children.first { $0.name == IsoWorldScene.terrainObjectNodeName }).zPosition
    // From (a, b - 1) to (a + 1, b - 1) behind the clump on (a, b): behind it for the whole step.
    for along in [0, 0.25, 0.5, 0.7, 0.9, 0.95] {
        #expect(stand(9 + along, 8) < clump, "\(along) of the step")
    }
}

/// One depth per footprint, its centre's, sorts a figure correctly only while the footprint is no more
/// than one tile longer than it is wide: at 3:1 and beyond (|w − h| ≥ 2) a figure beside the long end
/// can sort in front of a building that covers it. Nothing in the catalog is that long; this fails first
/// if something gets there.
@Test("no catalogued footprint is long enough to break the centre-depth sort")
func footprintsStayNearlySquare() {
    for kind in BuildingKind.allCases {
        let footprint = BuildingCatalog.spec(for: kind).footprint
        #expect(abs(footprint.width - footprint.height) < 2, "\(kind) is \(footprint.width) × \(footprint.height)")
    }
}
