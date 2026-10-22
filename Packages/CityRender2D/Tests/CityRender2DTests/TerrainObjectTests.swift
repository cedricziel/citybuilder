import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/terrain-v2 (rendering-2_5d / Terrain objects).

private func map(
    _ width: Int,
    _ height: Int,
    occupied: [TileCoordinate: EntityID] = [:],
    paint: (Int, Int) -> TerrainType
) -> TerrainObjectMap {
    let grid = (0 ..< width * height).map { paint($0 % width, $0 / width) }
    return TerrainObjectMap(width: width, height: height, grid: grid, occupancy: occupied)
}

/// A 7 x 7 forest at (5...11, 5...11) in a 17 x 17 meadow.
private func forest(occupied: [TileCoordinate: EntityID] = [:]) -> TerrainObjectMap {
    map(17, 17, occupied: occupied) { x, y in (5 ... 11).contains(x) && (5 ... 11).contains(y) ? .forest : .grass }
}

@Test("scenario: Forest edges are thinner than forest interiors")
func forestEdgesAreThinnerThanInteriors() {
    let objects = forest()
    #expect(objects.object(at: .init(x: 8, y: 8))?.density == .dense)
    for x in 5 ... 11 {
        for edge in [TileCoordinate(x: x, y: 5), TileCoordinate(x: x, y: 11)] {
            let density = objects.object(at: edge)?.density
            #expect(density == .sparse || density == .medium, "edge \(edge) is \(String(describing: density))")
        }
    }
    #expect(objects.object(at: .init(x: 6, y: 8))?.density == .medium)
}

@Test("scenario: Trees never stand on a building")
func treesNeverStandOnABuilding() {
    let road = TileCoordinate(x: 8, y: 8)
    let objects = forest(occupied: [road: EntityID(raw: 1)])
    #expect(objects.object(at: road) == nil)
    #expect(objects.object(at: .init(x: 9, y: 8))?.density == .medium) // dense, one step down
    #expect(forest().object(at: .init(x: 9, y: 8))?.density == .dense)
}

@Test("scenario: Meadow trees stay rare and clear of buildings")
func meadowTreesStayRareAndClearOfBuildings() {
    let house = TileCoordinate(x: 3, y: 8)
    let objects = forest(occupied: [house: EntityID(raw: 1)])
    var near = 0, singles = 0
    for y in 0 ..< 17 {
        for x in 0 ..< 17 where !((5 ... 11).contains(x) && (5 ... 11).contains(y)) {
            let tile = TileCoordinate(x: x, y: y)
            if objects.object(at: tile) != nil {
                singles += 1
                #expect(objects.object(at: tile)?.density == .single)
                #expect(abs(x - house.x) > 1 || abs(y - house.y) > 1, "a tree beside the house at \(tile)")
            }
            if (3 ... 13).contains(x), (3 ... 13).contains(y) {
                near += 1
            }
        }
    }
    #expect(singles * 10 <= near)
}

@Test("Object sprite names follow the season, rock having no autumn look")
func objectNamesFollowTheSeason() {
    let tree = TerrainObject(kind: .forest, density: .dense, variant: 2)
    #expect(tree.assetName(in: .summer) == "terrain-forest-dense-v2")
    #expect(tree.assetName(in: .autumn) == "terrain-forest-dense-autumn-v2")
    #expect(tree.assetName(in: .winter) == "terrain-forest-dense-winter-v2")
    let rock = TerrainObject(kind: .mountain, density: .peak, variant: 0)
    #expect(rock.assetName(in: .autumn) == "terrain-mountain-peak")
    #expect(rock.assetName(in: .winter) == "terrain-mountain-peak-winter")
}

@MainActor
private final class Source: IsoWorldDataSource {
    var snapshot: WorldSnapshot
    init(_ snapshot: WorldSnapshot) {
        self.snapshot = snapshot
    }

    func currentSnapshot() -> WorldSnapshot? {
        snapshot
    }
}

private func forestSnapshot(season: Season = .summer) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 9, height: 9, fill: .grass, seed: 1).snapshot()
    let grid = base.terrainGrid.indices.map { (3 ... 5).contains($0 % 9) && (3 ... 5).contains($0 / 9) ? TerrainType.forest : .grass }
    return WorldSnapshot(
        tickCount: base.tickCount, simulatedTime: base.simulatedTime, mapWidth: 9, mapHeight: 9, terrainGrid: grid,
        occupiedTiles: [:], buildings: base.buildings, carriers: base.carriers, economy: base.economy,
        totalPopulation: base.totalPopulation, camera: base.camera, date: GameDate(year: 1200, season: season)
    )
}

@MainActor
private func scene(_ source: Source) -> IsoWorldScene {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.hasSprite = { _ in true }
    scene.dataSource = source
    scene.update(0)
    return scene
}

/// The clumps on the forest tiles, leaving out single meadow trees.
@MainActor
private func objectNodes(_ scene: IsoWorldScene) -> [SKSpriteNode] {
    scene.children.flatMap(\.children).compactMap { $0 as? SKSpriteNode }.filter {
        $0.name == IsoWorldScene.terrainObjectNodeName
            && ($0.userData?[IsoWorldScene.textureNameKey] as? String)?.contains("-single") == false
    }
}

@MainActor
@Test("scenario: Forest ground has no tile edge")
func forestGroundHasNoTileEdge() {
    let scene = scene(Source(forestSnapshot()))
    let ground = scene.children.compactMap { $0.userData?[IsoWorldScene.textureNameKey] as? String }
    #expect(!ground.contains { $0.hasPrefix("terrain-forest") })
    #expect(objectNodes(scene).count == 9)
}

@MainActor
@Test("scenario: A clump in front of a house covers it")
func clumpInFrontOfAHouseCoversIt() {
    // A house on 2 x 2 at (1, 1) has its footprint centre at depth 1 + 1 + 2 = 4; tile (3, 3) is deeper.
    let house = 10 + 4 * 0.01
    let scene = scene(Source(forestSnapshot()))
    let front = objectNodes(scene).filter { ($0.userData?[IsoWorldScene.textureNameKey] as? String) != nil }
    #expect(front.allSatisfy { $0.zPosition > CGFloat(house) })
}

@MainActor
@Test("scenario: A clump behind a house stays behind it")
func clumpBehindAHouseStaysBehindIt() {
    // A house on 2 x 2 at (6, 6): depth 6 + 6 + 2 = 14, deeper than every tree in the 3...5 square.
    let house = 10 + 14 * 0.01
    let scene = scene(Source(forestSnapshot()))
    #expect(objectNodes(scene).allSatisfy { $0.zPosition < CGFloat(house) })
}

@MainActor
@Test("scenario: Forests turn in autumn")
func forestsTurnInAutumn() {
    let source = Source(forestSnapshot(season: .summer))
    let scene = scene(source)
    source.snapshot = forestSnapshot(season: .autumn)
    scene.update(1)
    let names = objectNodes(scene).compactMap { $0.userData?[IsoWorldScene.textureNameKey] as? String }
    #expect(names.count == 9 && names.allSatisfy { $0.contains("-autumn") })
}

@Test("Culling keeps the tiles the screen shows and drops the corners of the tile-space box")
func cullingKeepsOnlyTheScreen() throws {
    let camera = Camera(centerX: 50, centerY: 50, zoom: 1)
    let view = CGSize(width: 1024, height: 768)
    let bounds = Culling.screenBounds(camera: camera, viewSize: view)
    #expect(bounds.contains(IsoMath.screenPoint(forTile: .init(x: 50, y: 50))))
    // The box's corner tile (+col and -row far out) is off screen, though inside the tile range.
    let range = Culling.visibleTileRange(camera: camera, viewSize: view, mapWidth: 200, mapHeight: 200)
    let corner = try TileCoordinate(x: #require(range?.xRange.upperBound), y: #require(range?.yRange.lowerBound))
    #expect(!bounds.contains(IsoMath.screenPoint(forTile: corner)))
}
