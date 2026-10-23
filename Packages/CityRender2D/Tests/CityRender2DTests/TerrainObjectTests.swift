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

@Test("scenario: A forest reaching the map border")
func forestReachingTheMapBorder() {
    let grid = World.fixtureWithTerrain(width: 6, height: 5, fill: .forest, seed: 1).snapshot().terrainGrid
    let objects = TerrainObjectMap(width: 6, height: 5, grid: grid, occupancy: [:])
    for corner in [TileCoordinate(x: 0, y: 0), TileCoordinate(x: 5, y: 0), TileCoordinate(x: 0, y: 4), TileCoordinate(x: 5, y: 4)] {
        let density = objects.object(at: corner)?.density
        #expect(density == .sparse || density == .medium, "corner \(corner) is \(String(describing: density))")
    }
    #expect(objects.object(at: .init(x: 2, y: 2))?.density == .dense)
    #expect(TerrainObjectMap(width: 1, height: 3, grid: [.forest, .forest, .forest], occupancy: [:]).object(at: .init(x: 0, y: 1)) != nil)
}

@Test("A building placed or cleared redoes only its tiles, matching a fresh map")
func occupancyUpdateMatchesAFreshMap() {
    let built: [TileCoordinate: EntityID] = [.init(x: 8, y: 8): EntityID(raw: 1), .init(x: 11, y: 5): EntityID(raw: 2)]
    var objects = forest()
    objects.update(occupancy: built)
    let fresh = forest(occupied: built)
    var cleared = objects
    cleared.update(occupancy: [:])
    for y in 0 ..< 17 {
        for x in 0 ..< 17 {
            let tile = TileCoordinate(x: x, y: y)
            #expect(objects.object(at: tile) == fresh.object(at: tile), "\(tile)")
            #expect(cleared.object(at: tile) == forest().object(at: tile), "\(tile)")
        }
    }
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

/// A 3 x 3 forest at (3...5, 3...5) in a 9 x 9 meadow, with `buildings` on their footprints.
private func forestSnapshot(
    season: Season = .summer,
    buildings: [Building] = [],
    paint: [TileCoordinate: TerrainType] = [:]
) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 9, height: 9, fill: .grass, seed: 1).snapshot()
    let grid = base.terrainGrid.indices.map { index in
        let tile = TileCoordinate(x: index % 9, y: index / 9)
        return paint[tile] ?? ((3 ... 5).contains(tile.x) && (3 ... 5).contains(tile.y) ? TerrainType.forest : .grass)
    }
    var occupied: [TileCoordinate: EntityID] = [:]
    for building in buildings {
        for tile in BuildingCatalog.spec(for: building.kind).footprint.tiles(anchor: building.anchor) {
            occupied[tile] = building.id
        }
    }
    return WorldSnapshot(
        tickCount: base.tickCount, simulatedTime: base.simulatedTime, mapWidth: 9, mapHeight: 9, terrainGrid: grid,
        occupiedTiles: occupied, buildings: Dictionary(uniqueKeysWithValues: buildings.map { ($0.id, $0) }), carriers: base.carriers,
        economy: base.economy, totalPopulation: base.totalPopulation, camera: base.camera, date: GameDate(year: 1200, season: season)
    )
}

private func house(_ raw: UInt32, at x: Int, _ y: Int) -> Building {
    Building(id: EntityID(raw: raw), kind: .house, anchor: TileCoordinate(x: x, y: y), state: .operational)
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

@MainActor
private func objectNodes(_ scene: IsoWorldScene) -> [SKSpriteNode] {
    scene.children.flatMap(\.children).compactMap { $0 as? SKSpriteNode }.filter { $0.name == IsoWorldScene.terrainObjectNodeName }
}

@MainActor
private func objectNames(_ scene: IsoWorldScene) -> [String] {
    objectNodes(scene).compactMap { $0.userData?[IsoWorldScene.textureNameKey] as? String }
}

/// The ground node of `tile`.
@MainActor
private func ground(at tile: TileCoordinate, in scene: IsoWorldScene) -> SKNode? {
    scene.presentSprites.first { spec, _ in
        guard case .terrain = spec.kind else { return false }
        return spec.coord == tile
    }?.value
}

/// The clump standing on `tile`, if any.
@MainActor
private func clump(at tile: TileCoordinate, in scene: IsoWorldScene) -> SKNode? {
    ground(at: tile, in: scene)?.children.first { $0.name == IsoWorldScene.terrainObjectNodeName }
}

@MainActor
@Test("scenario: Forest ground has no tile edge")
func forestGroundHasNoTileEdge() {
    let scene = scene(Source(forestSnapshot()))
    let ground = scene.children.compactMap { $0.userData?[IsoWorldScene.textureNameKey] as? String }
    #expect(!ground.contains { $0.hasPrefix("terrain-forest") })
    #expect(objectNodes(scene).count == 9)
}

/// The forest with a house at (1, 1), behind all of it, and one at (6, 6), in front of all of it.
@MainActor
private func forestBetweenHouses() -> IsoWorldScene {
    scene(Source(forestSnapshot(buildings: [house(1, at: 1, 1), house(2, at: 6, 6)])))
}

@MainActor
@Test("scenario: A clump in front of a house covers it")
func clumpInFrontOfAHouseCoversIt() throws {
    let scene = forestBetweenHouses()
    let house = try #require(scene.buildingNodes[TileCoordinate(x: 1, y: 1)]).zPosition
    #expect(objectNodes(scene).count == 9)
    #expect(objectNodes(scene).allSatisfy { $0.zPosition > house })
}

@MainActor
@Test("scenario: A clump behind a house stays behind it")
func clumpBehindAHouseStaysBehindIt() throws {
    let scene = forestBetweenHouses()
    let house = try #require(scene.buildingNodes[TileCoordinate(x: 6, y: 6)]).zPosition
    #expect(objectNodes(scene).count == 9)
    #expect(objectNodes(scene).allSatisfy { $0.zPosition < house })
}

@MainActor
@Test("scenario: A clump level with a building sorts behind it in every season")
func clumpLevelWithABuildingSortsBehindIt() throws {
    // The house at (6, 1) has depth 6 + 1 + 2 = 9; the clump on (5, 3) too, 5 + 3 + 1.
    let source = Source(forestSnapshot(buildings: [house(1, at: 6, 1)]))
    let scene = scene(source)
    for season in Season.allCases {
        source.snapshot = forestSnapshot(season: season, buildings: [house(1, at: 6, 1)])
        scene.update(1)
        let houseZ = try #require(scene.buildingNodes[TileCoordinate(x: 6, y: 1)]).zPosition
        let treeZ = try #require(clump(at: .init(x: 5, y: 3), in: scene)).zPosition
        #expect(treeZ < houseZ, "\(season)")
    }
}

@MainActor
@Test("scenario: A building placed in a live forest clears its clump and thins its neighbours")
func buildingPlacedInALiveForest() {
    let source = Source(forestSnapshot())
    let scene = scene(source)
    #expect(objectNodes(scene).count == 9)
    source.snapshot = forestSnapshot(buildings: [house(1, at: 3, 3)])
    scene.update(1)
    // Four tiles under the house; the five left all touch it and drop to sparse.
    #expect(objectNames(scene).count == 5)
    #expect(objectNames(scene).allSatisfy { $0.hasPrefix("terrain-forest-sparse") })
    #expect(clump(at: .init(x: 3, y: 3), in: scene) == nil)
    let under = ground(at: .init(x: 3, y: 3), in: scene)?.userData?[IsoWorldScene.textureNameKey] as? String
    #expect(under?.hasPrefix("terrain-grass") == true)
}

@MainActor
@Test("scenario: Felling and planting reach the scene")
func fellingAndPlantingReachTheScene() {
    let source = Source(forestSnapshot())
    let scene = scene(source)
    source.snapshot = forestSnapshot(paint: [.init(x: 4, y: 4): .grass])
    scene.update(1)
    #expect(objectNodes(scene).count == 8)
    #expect(clump(at: .init(x: 4, y: 4), in: scene) == nil)
    source.snapshot = forestSnapshot(paint: [.init(x: 4, y: 4): .grass, .init(x: 6, y: 4): .forest])
    scene.update(2)
    #expect(objectNodes(scene).count == 9)
    #expect(clump(at: .init(x: 6, y: 4), in: scene) != nil)
}

@MainActor
@Test("scenario: Forests turn in autumn")
func forestsTurnInAutumn() {
    let source = Source(forestSnapshot(season: .summer))
    let scene = scene(source)
    source.snapshot = forestSnapshot(season: .autumn)
    scene.update(1)
    let names = objectNames(scene)
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

@Test("A tree clump just below the screen's bottom corner stays in the scene")
func clumpBelowTheBottomCornerStays() {
    let camera = Camera(centerX: 50, centerY: 50, zoom: 1)
    let view = CGSize(width: 1024, height: 768)
    // (57, 73) lies 96 pt below the view's bottom-left corner: its clump, 112 pt tall, reaches into view.
    let tile = TileCoordinate(x: 57, y: 73)
    let point = IsoMath.screenPoint(forTile: tile)
    let centre = IsoMath.screenPoint(forTileFractionalX: 50, fractionalY: 50)
    #expect(point.y < centre.y - view.height / 2 && point.y + 112 > centre.y - view.height / 2)
    #expect(Culling.screenBounds(camera: camera, viewSize: view).contains(point))
    let range = Culling.visibleTileRange(camera: camera, viewSize: view, mapWidth: 200, mapHeight: 200, margin: Culling.screenMargin)
    #expect(range.map { $0.xRange.contains(tile.x) && $0.yRange.contains(tile.y) } == true)
}
