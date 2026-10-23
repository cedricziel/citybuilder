import CoreGraphics
import SpriteKit
import Testing
@testable import CityCore
@testable import CityRender2D

// rendering-2_5d / Snapshot-driven rendering (#175): the scene reconciles its sprites only on frames
// that change the view, the terrain or the buildings, and a pan touches only the tiles at the edges.

/// A 40 × 40 meadow with a forest at 10–17 × 10–17, rock at 24–29 × 8–13 and a lake at 8–13 × 26–31,
/// houses (one at (20, 20) by default) and roads, seen by `camera`. The other fields are the building
/// inputs a test can change one at a time.
private struct Meadow {
    static let size = 40
    var camera = Camera(centerX: 20, centerY: 20, zoom: 1)
    var houses = [TileCoordinate(x: 20, y: 20)]
    var houseState = BuildingState.operational
    var roads: [TileCoordinate] = []
    var paint: [TileCoordinate: TerrainType] = [:]
    var season = Season.spring
    var culture = Culture.northernEuropean
    var tick: UInt64 = 0
    var strayOccupancy: [TileCoordinate: EntityID] = [:]
    var roadDisconnected: Set<EntityID> = []
    var housePopulations: [EntityID: HousePopulation] = [:]
    var houseModifiers: [EntityID: HouseModifiers] = [:]
    var rivals: [RivalSummary] = []

    private static let base = World.fixtureWithTerrain(width: size, height: size, fill: .grass, seed: 1).snapshot()
    private static let ground = (0 ..< size * size).map { index -> TerrainType in
        let tile = TileCoordinate(x: index % size, y: index / size)
        if (10 ... 17).contains(tile.x), (10 ... 17).contains(tile.y) { return .forest }
        if (24 ... 29).contains(tile.x), (8 ... 13).contains(tile.y) { return .mountain }
        if (8 ... 13).contains(tile.x), (26 ... 31).contains(tile.y) { return .water }
        return .grass
    }

    var snapshot: WorldSnapshot {
        let (size, base) = (Self.size, Self.base)
        var grid = Self.ground
        for (tile, terrain) in paint {
            grid[tile.y * size + tile.x] = terrain
        }
        var buildings: [Building] = []
        var occupied = strayOccupancy
        let placements = houses.map { (BuildingKind.house, $0, houseState) } + roads
            .map { (BuildingKind.road, $0, BuildingState.operational) }
        for (kind, anchor, state) in placements {
            let tiles = BuildingCatalog.spec(for: kind).footprint.tiles(anchor: anchor)
            guard tiles.allSatisfy({ occupied[$0] == nil && (0 ..< size).contains($0.x) && (0 ..< size).contains($0.y) }) else { continue }
            let building = Building(id: EntityID(raw: UInt32(buildings.count + 1)), kind: kind, anchor: anchor, state: state)
            buildings.append(building)
            for tile in tiles {
                occupied[tile] = building.id
            }
        }
        return WorldSnapshot(
            tickCount: tick, simulatedTime: base.simulatedTime, mapWidth: size, mapHeight: size, terrainGrid: grid,
            occupiedTiles: occupied, buildings: Dictionary(uniqueKeysWithValues: buildings.map { ($0.id, $0) }),
            carriers: [], economy: base.economy, totalPopulation: base.totalPopulation, camera: camera,
            roadDisconnectedBuildings: roadDisconnected, housePopulations: housePopulations,
            date: GameDate(year: 1200, season: season), culture: culture, houseModifiers: houseModifiers, rivals: rivals
        )
    }
}

private let viewSize = CGSize(width: 480, height: 320)

@MainActor
private func scene(showing snapshot: WorldSnapshot, size: CGSize = viewSize) -> (IsoWorldScene, FixedSnapshotSource) {
    let source = FixedSnapshotSource(snapshot)
    let scene = IsoWorldScene()
    scene.size = size
    scene.hasSprite = { _ in true }
    scene.dataSource = source
    scene.update(0)
    return (scene, source)
}

/// Whether two nodes show the same: texture name, position, depth, and the same of their children
/// (window glow aside, which follows the time of day rather than the snapshot). Children usually come
/// in the order the factory adds them; any order is accepted.
@MainActor
private func sameLook(_ one: SKNode, _ other: SKNode) -> Bool {
    let texture = { (node: SKNode) in node.userData?[IsoWorldScene.textureNameKey] as? String }
    let children = { (node: SKNode) in node.children.filter { $0.name != IsoWorldScene.windowGlowNodeName } }
    guard texture(one) == texture(other), one.position == other.position, one.zPosition == other.zPosition else { return false }
    let (mine, theirs) = (children(one), children(other))
    guard mine.count == theirs.count else { return false }
    return zip(mine, theirs).allSatisfy(sameLook) || mine.allSatisfy { child in theirs.contains { sameLook(child, $0) } }
}

/// Where the scene differs from a fresh scene drawing the same frame, nil when it doesn't: the sprites
/// placed, what they show, and children the scene holds besides its sprites.
@MainActor
private func mismatch(_ incremental: IsoWorldScene, _ snapshot: WorldSnapshot) -> String? {
    let (fresh, _) = scene(showing: snapshot, size: incremental.size)
    let mine = Set(incremental.presentSprites.keys), theirs = Set(fresh.presentSprites.keys)
    if mine != theirs {
        return "sprites: \(mine.subtracting(theirs).count) extra, \(theirs.subtracting(mine).count) missing"
    }
    if let spec = mine.first(where: { spec in
        incremental.presentSprites[spec].map { sameLook($0, fresh.presentSprites[spec] ?? SKNode()) } != true
    }) {
        return "look differs at \(spec)"
    }
    let others = { (scene: IsoWorldScene) in scene.children.count - scene.presentSprites.count }
    return others(incremental) == others(fresh) ? nil : "other children: \(others(incremental)) vs \(others(fresh))"
}

@MainActor
@Test("scenario: An unchanged frame reconciles nothing")
func anUnchangedFrameReconcilesNothing() {
    let (scene, _) = scene(showing: Meadow().snapshot)
    let first = scene.spriteReconcileCounts
    #expect(first.terrainPasses == 1)
    #expect(first.buildingPasses == 1)
    for frame in 1 ... 5 {
        scene.update(TimeInterval(frame) / 60)
    }
    #expect(scene.spriteReconcileCounts == first)
}

@MainActor
@Test("scenario: A pan redraws only the edges")
func aPanRedrawsOnlyTheEdges() {
    var meadow = Meadow(camera: Camera(centerX: 20, centerY: 20, zoom: 0.5))
    let (scene, source) = scene(showing: meadow.snapshot)
    let shown = scene.terrainSpecs.count
    let before = scene.spriteReconcileCounts
    meadow.camera = Camera(centerX: 21, centerY: 20, zoom: 0.5)
    source.snapshot = meadow.snapshot
    scene.update(1)
    let after = scene.spriteReconcileCounts
    let touched = after.tilesAdded - before.tilesAdded + after.tilesRemoved - before.tilesRemoved
    #expect(after.terrainPasses == before.terrainPasses + 1)
    #expect(touched > 0)
    #expect(touched * 5 < shown)
    #expect(mismatch(scene, source.snapshot) == nil)
}

@MainActor
@Test("scenario: A new building redraws only the tiles round it")
func aNewBuildingRedrawsOnlyTheTilesRoundIt() {
    var meadow = Meadow()
    let (scene, source) = scene(showing: meadow.snapshot)
    let before = scene.spriteReconcileCounts
    meadow.houses.append(TileCoordinate(x: 18, y: 12))
    source.snapshot = meadow.snapshot
    scene.update(1)
    let after = scene.spriteReconcileCounts
    #expect(after.buildingPasses == before.buildingPasses + 1)
    #expect(after.tilesAdded - before.tilesAdded < 20)
    #expect(mismatch(scene, source.snapshot) == nil)
}

@MainActor
@Test("scenario: Incremental frames match a full rebuild")
func incrementalFramesMatchAFullRebuild() {
    var meadow = Meadow()
    let (scene, source) = scene(showing: meadow.snapshot)
    let steps: [(String, (inout Meadow) -> Void)] = [
        ("pan", { $0.camera = Camera(centerX: 22.3, centerY: 18.7, zoom: 1) }),
        ("zoom out", { $0.camera.zoom = 0.25 }),
        ("jump", { $0.camera = Camera(centerX: 5, centerY: 35, zoom: 0.5) }),
        ("autumn", { $0.season = .autumn }),
        ("zoom in on the forest", { $0.camera = Camera(centerX: 15, centerY: 15, zoom: 2) }),
        ("clear a tree", { $0.paint = [TileCoordinate(x: 13, y: 13): .grass] }),
        ("move the house", { $0.houses = [TileCoordinate(x: 16, y: 18)] }),
        ("winter", { $0.season = .winter }),
        ("mediterranean", { $0.culture = .mediterranean }),
        ("corner", { $0.camera = Camera(centerX: 38, centerY: 2, zoom: 0.75) })
    ]
    for (frame, (name, step)) in steps.enumerated() {
        step(&meadow)
        source.snapshot = meadow.snapshot
        scene.update(TimeInterval(frame + 1))
        #expect(mismatch(scene, source.snapshot) == nil, "\(name)")
    }
}

/// Each input the building sprites are drawn from, changed on its own.
enum BuildingInput: CaseIterable, Sendable {
    case cullingRange, buildings, occupancy, roadAccess, housePopulations, houseModifiers, rivals

    fileprivate func change(_ meadow: inout Meadow) {
        let house = EntityID(raw: 1)
        switch self {
        case .cullingRange: meadow.camera.centerX += 3
        case .buildings: meadow.houseState = .constructing
        case .occupancy: meadow.strayOccupancy = [TileCoordinate(x: 2, y: 2): EntityID(raw: 99)]
        case .roadAccess: meadow.roadDisconnected = [house]
        case .housePopulations:
            var citizens = HousePopulation()
            citizens.tier = .citizens
            meadow.housePopulations = [house: citizens]
        case .houseModifiers: meadow.houseModifiers = [house: HouseModifiers(smoky: true)]
        case .rivals:
            let rival = RivalTown(
                id: RivalID(1), name: "Rival", islandID: 1, culture: .mediterranean, colour: .forRival(RivalID(1)), age: .medieval,
                treasury: 0, townCenterID: EntityID(raw: 50), ai: RivalAIState()
            )
            meadow.rivals = [RivalSummary(rival)]
        }
    }
}

@MainActor
@Test("a change to any building input runs one building pass", arguments: BuildingInput.allCases)
func aBuildingInputChangeRunsOneBuildingPass(input: BuildingInput) {
    var meadow = Meadow()
    let (scene, source) = scene(showing: meadow.snapshot)
    let before = scene.spriteReconcileCounts.buildingPasses
    input.change(&meadow)
    source.snapshot = meadow.snapshot
    scene.update(1)
    #expect(scene.spriteReconcileCounts.buildingPasses == before + 1)
    #expect(mismatch(scene, source.snapshot) == nil)
}

private extension DeterministicRNG {
    mutating func next(_ bound: Int) -> Int {
        Int(next() % UInt64(bound))
    }
}

@MainActor
@Test("random frames match a fresh scene, sprite by sprite")
func randomFramesMatchAFreshScene() {
    var random = DeterministicRNG(seed: 42)
    let zooms = [0.25, 0.5, 1, 2, 4]
    let sizes = [viewSize, CGSize(width: 200, height: 700), CGSize(width: 800, height: 200)]
    let size = Meadow.size
    var meadow = Meadow()
    let (scene, source) = scene(showing: meadow.snapshot)
    for frame in 1 ... 60 {
        switch random.next(9) {
        case 0:
            let tile = (Double(random.next(size)), Double(random.next(size)))
            meadow.camera = Camera(centerX: tile.0, centerY: tile.1, zoom: zooms[random.next(zooms.count)])
        case 1:
            meadow.camera.centerX += Double(random.next(21) - 10) / 10
            meadow.camera.centerY += Double(random.next(21) - 10) / 10
        case 2: meadow.houses.append(TileCoordinate(x: random.next(size), y: random.next(size)))
        case 3: meadow.houses.removeFirst(min(1, meadow.houses.count))
        case 4: meadow.roads.append(TileCoordinate(x: random.next(size), y: random.next(size)))
        case 5:
            let tile = TileCoordinate(x: random.next(size), y: random.next(size))
            meadow.paint[tile] = [.grass, .forest, .water, .mountain][random.next(4)]
        case 6: meadow.season = [.spring, .summer, .autumn, .winter][random.next(4)]
        case 7: meadow.culture = [.northernEuropean, .mediterranean][random.next(2)]
        default: scene.size = sizes[random.next(sizes.count)]
        }
        meadow.tick += 7
        source.snapshot = meadow.snapshot
        scene.update(TimeInterval(frame))
        let difference = mismatch(scene, source.snapshot)
        #expect(difference == nil, "frame \(frame)")
        if difference != nil { break }
    }
}
