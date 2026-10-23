import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/add-gather-workers.

private func site(_ raw: UInt32, _ kind: BuildingKind, at x: Int, _ y: Int) -> Building {
    Building(id: EntityID(raw: raw), kind: kind, anchor: TileCoordinate(x: x, y: y), state: .operational)
}

/// Forest from column 14 east above row 25, mountain from row 30 south,
/// grass elsewhere.
private func land(_ tile: TileCoordinate) -> TerrainType {
    tile.y >= 30 ? .mountain : tile.x >= 14 && tile.y < 25 ? .forest : .grass
}

private func world(
    _ sites: [Building], tick: UInt64 = 180, issues: [EntityID: BuildingIssue] = [:], zoom: Double = 1,
    terrain: (TileCoordinate) -> TerrainType = land
) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 40, height: 40, fill: .grass, seed: 1).snapshot()
    var occupied: [TileCoordinate: EntityID] = [:]
    for building in sites {
        for tile in BuildingCatalog.spec(for: building.kind).footprint.tiles(anchor: building.anchor) {
            occupied[tile] = building.id
        }
    }
    return WorldSnapshot(
        tickCount: tick, simulatedTime: base.simulatedTime, mapWidth: 40, mapHeight: 40,
        terrainGrid: (0 ..< 1600).map { terrain(TileCoordinate(x: $0 % 40, y: $0 / 40)) }, occupiedTiles: occupied,
        buildings: Dictionary(uniqueKeysWithValues: sites.map { ($0.id, $0) }), carriers: [],
        economy: base.economy, totalPopulation: 0, camera: Camera(centerX: 20, centerY: 20, zoom: zoom),
        buildingIssues: issues, date: GameDate(year: 1200, season: .summer)
    )
}

private func ground(_ snapshot: WorldSnapshot) -> GatherWorkerPlanner.Ground {
    GatherWorkerPlanner.Ground(
        isWalkable: { snapshot.terrain(at: $0) == .grass && snapshot.occupiedTiles[$0] == nil },
        terrain: { snapshot.occupiedTiles[$0] == nil ? snapshot.terrain(at: $0) : nil }
    )
}

private func plan(
    _ snapshot: WorldSnapshot, clock: UInt64, trips: inout [EntityID: GatherWorkerPlanner.Trip]
) -> [GatherWorkerPlanner.Worker] {
    GatherWorkerPlanner.workers(in: snapshot, visible: (0 ... 39, 0 ... 39), clock: clock, ground: ground(snapshot), trips: &trips)
}

private func plan(_ snapshot: WorldSnapshot, clock: UInt64) -> [GatherWorkerPlanner.Worker] {
    var trips: [EntityID: GatherWorkerPlanner.Trip] = [:]
    return plan(snapshot, clock: clock, trips: &trips)
}

private func tile(_ worker: GatherWorkerPlanner.Worker) -> TileCoordinate {
    TileCoordinate(x: Int(worker.col.rounded()), y: Int(worker.row.rounded()))
}

@Test("scenario: a woodcutter walks out and back")
func scenarioAWoodcutterWalksOutAndBack() throws {
    // The catchment reaches 2 tiles past the footprint (columns 9 to 14).
    let hut = site(1, .lumberjackHut, at: 11, 10)
    let snapshot = world([hut])
    let isWalkable = ground(snapshot).isWalkable
    let footprint = BuildingCatalog.spec(for: .lumberjackHut).footprint.tiles(anchor: hut.anchor)
    var trips: [EntityID: GatherWorkerPlanner.Trip] = [:]
    var reachedForest = false, carriedLogs = false, walkedOut = false
    for clock in UInt64(0) ..< 400 {
        let workers = plan(snapshot, clock: clock, trips: &trips)
        let worker = try #require(workers.first)
        #expect(workers.count == 1)
        #expect(isWalkable(tile(worker)) || land(tile(worker)) == .forest, "the worker on a blocked tile at \(tile(worker))")
        #expect(!footprint.contains(tile(worker)), "the worker inside the hut at \(tile(worker))")
        reachedForest = reachedForest || (land(tile(worker)) == .forest && !worker.walking)
        carriedLogs = carriedLogs || worker.load == .logs
        walkedOut = walkedOut || (worker.walking && worker.load == nil)
    }
    #expect(reachedForest && carriedLogs && walkedOut)
}

@Test("scenario: no jump when the woods change")
func scenarioNoJumpWhenTheWoodsChange() {
    let hut = site(1, .lumberjackHut, at: 11, 10)
    // Every tick fells or plants a tree somewhere in the catchment.
    func woods(_ tick: UInt64) -> (TileCoordinate) -> TerrainType {
        { tile in
            let flip = (tile.x * 7 + tile.y * 13 + Int(tick)) % 5 == 0
            if (9 ... 15).contains(tile.x), (8 ... 13).contains(tile.y), !(11 ... 12).contains(tile.x) || !(10 ... 11).contains(tile.y) {
                return flip ? (land(tile) == .forest ? .grass : .forest) : land(tile)
            }
            return land(tile)
        }
    }
    for (first, clockOf) in [(UInt64(100), { (tick: UInt64) in tick }), (700, { _ in 5000 }), (100, { _ in 7000 })] {
        var trips: [EntityID: GatherWorkerPlanner.Trip] = [:]
        var last: GatherWorkerPlanner.Worker?
        for tick in first ..< first + 300 {
            let snapshot = world([hut], tick: tick, terrain: woods(tick))
            guard let worker = plan(snapshot, clock: clockOf(tick), trips: &trips).first else {
                last = nil
                continue
            }
            if let last {
                #expect(abs(worker.col - last.col) <= 1 && abs(worker.row - last.row) <= 1, "jumped at tick \(tick)")
            }
            last = worker
        }
    }
}

@Test("scenario: an idle site stays empty")
func scenarioAnIdleSiteStaysEmpty() {
    let hut = site(1, .lumberjackHut, at: 11, 10)
    #expect(plan(world([hut], issues: [hut.id: .noTreesInReach]), clock: 100).isEmpty)
    let farHut = site(2, .lumberjackHut, at: 2, 10)
    #expect(plan(world([farHut]), clock: 100).isEmpty, "no forest within the catchment")
    let rival = Building(
        id: EntityID(raw: 3), kind: .lumberjackHut, anchor: TileCoordinate(x: 11, y: 10), state: .operational, owner: .rival(1)
    )
    #expect(plan(world([rival]), clock: 100).isEmpty, "a rival's site has no known issues, so it stays empty")
}

@Test("scenario: a miner carries a crate")
func scenarioAMinerCarriesACrate() {
    let mine = site(1, .mine, at: 20, 30)
    var trips: [EntityID: GatherWorkerPlanner.Trip] = [:]
    let loads = Set((UInt64(0) ..< 400).compactMap { plan(world([mine]), clock: $0, trips: &trips).first?.load })
    #expect(loads == [.crate])
}

@Test("workers fill the budget, on-screen sites first, and leave far zoom empty")
func workersStayInBudget() {
    // Twenty huts stacked along the forest edge, none overlapping.
    let huts = (0 ..< 20).map { site(UInt32(100 + $0), .lumberjackHut, at: 11, $0 * 2) }
    #expect(plan(world(huts, terrain: { $0.x >= 14 ? .forest : .grass }), clock: 50).count == GatherWorkerPlanner.maxWorkers)
    #expect(plan(world([site(1, .lumberjackHut, at: 11, 10)], zoom: 0.4), clock: 50).isEmpty)
    // On-screen sites win the budget over a lower id just off screen.
    let offScreen = site(1, .lumberjackHut, at: 11, 10),
        onScreen = (0 ..< 16).map { site(UInt32(10 + $0), .lumberjackHut, at: 11, 14 + $0) }
    let snapshot = world([offScreen] + onScreen, terrain: { $0.x >= 14 ? .forest : .grass })
    var trips: [EntityID: GatherWorkerPlanner.Trip] = [:]
    let chosen = GatherWorkerPlanner.workers(
        in: snapshot, visible: (0 ... 39, 14 ... 39), clock: 50, ground: ground(snapshot), trips: &trips
    )
    #expect(!chosen.contains { $0.site == offScreen.id })
}

// MARK: - Through the scene

@MainActor
private final class FixedSnapshot: IsoWorldDataSource {
    var snapshot: WorldSnapshot
    init(_ snapshot: WorldSnapshot) {
        self.snapshot = snapshot
    }

    func currentSnapshot() -> WorldSnapshot? {
        snapshot
    }
}

@MainActor
private func scene(showing snapshot: WorldSnapshot) -> IsoWorldScene {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    let source = FixedSnapshot(snapshot)
    scene.dataSource = source
    scene.userData = ["source": source]
    return scene
}

@MainActor
@Test("the worker sorts against the real hut and the clump it works at")
func workerSortsAgainstHutAndClump() throws {
    let hut = site(1, .lumberjackHut, at: 11, 20)
    let snapshot = world([hut], terrain: { $0.x >= 14 ? .forest : .grass })
    let scene = scene(showing: snapshot)
    let hutNode = scene.placedNode(for: SpriteSpec(coord: hut.anchor, kind: .building(
        kind: .lumberjackHut, state: .operational, footprint: Footprint(width: 2, height: 2),
        constructionFrameIndex: nil, orientation: nil, isWaitingForMaterials: false
    )))
    var checked = 0
    for tick in stride(from: UInt64(150), to: 600, by: 3) {
        (scene.dataSource as? FixedSnapshot)?.snapshot = world([hut], tick: tick, terrain: { $0.x >= 14 ? .forest : .grass })
        scene.update(TimeInterval(tick) / 10)
        let shown = try #require(scene.gatherNodes[hut.id])
        // Judge only where the worker stands, not mid-glide.
        guard shown.node.action(forKey: SKNode.glideKey) == nil else { continue }
        checked += 1
        let (col, row) = IsoMath.tileCoordinate(forScreenPoint: shown.node.position)
        let feet = col + row
        // The hut sorts at its footprint centre: anchor x + y + 2.
        #expect((shown.node.zPosition < hutNode.zPosition) == (feet < Double(hut.anchor.x + hut.anchor.y + 2)))
        // Working in the woods, the clump on the worker's own tile, placed as
        // the scene places it, draws over it; the clump behind does not.
        let here = TileCoordinate(x: Int(col.rounded()), y: Int(row.rounded()))
        let centred = abs(col - Double(here.x)) < 0.01 && abs(row - Double(here.y)) < 0.01
        if snapshot.terrain(at: here) == .forest, centred {
            scene.hasSprite = { _ in true }
            func clump(at coord: TileCoordinate) throws -> SKNode {
                let ground = scene.makeTerrainNode(
                    kind: .forest,
                    coord: coord,
                    object: TerrainObject(kind: .forest, density: .medium, variant: 0)
                )
                return try #require(ground.childNode(withName: IsoWorldScene.terrainObjectNodeName))
            }
            #expect(try shown.node.zPosition < clump(at: here).zPosition)
            #expect(try shown.node.zPosition > clump(at: TileCoordinate(x: here.x, y: here.y - 1)).zPosition)
        }
    }
    #expect(checked > 5)
}

@MainActor
@Test("the worker holds still while paused and at night")
func workerHoldsWhilePausedAndAtNight() throws {
    // A site whose worker is mid-walk on the frozen night clock.
    let clock = AnimalPlanner.dayClock(tick: 780)
    let walker = try #require((UInt32(1) ..< 60).first { raw in
        plan(world([site(raw, .lumberjackHut, at: 11, 20)], terrain: { $0.x >= 14 ? .forest : .grass }), clock: clock).first?
            .walking == true
    })
    let hut = site(walker, .lumberjackHut, at: 11, 20)
    let scene = scene(showing: world([hut], tick: 780, terrain: { $0.x >= 14 ? .forest : .grass }))
    scene.update(0)
    let night = try #require(scene.gatherNodes[hut.id])
    #expect(!night.pose.moving, "night: the worker stands, though its trip is mid-walk")
    (scene.dataSource as? FixedSnapshot)?.snapshot = world([hut], tick: 180, terrain: { $0.x >= 14 ? .forest : .grass })
    scene.update(1)
    scene.update(2.5)
    #expect(scene.gatherNodes.values.allSatisfy { !$0.pose.moving }, "paused: the worker stands")
    (scene.dataSource as? FixedSnapshot)?.snapshot = world(
        [hut],
        tick: 181,
        issues: [hut.id: .storageFull],
        terrain: { $0.x >= 14 ? .forest : .grass }
    )
    scene.update(2.6)
    #expect(scene.gatherNodes.isEmpty && night.node.parent == nil)
}

@MainActor
@Test("a different world drops the workers and animals")
func newWorldDropsFigures() throws {
    let hut = site(1, .lumberjackHut, at: 11, 20)
    let scene = scene(showing: world([hut], tick: 500, terrain: { $0.x >= 14 ? .forest : .grass }))
    scene.update(0)
    let old = try #require(scene.gatherNodes[hut.id]?.node)
    (scene.dataSource as? FixedSnapshot)?.snapshot = world([hut], tick: 10, terrain: { $0.x >= 14 ? .forest : .grass })
    scene.update(0.1)
    #expect(old.parent == nil)
    #expect(scene.gatherNodes[hut.id]?.node !== old)
}

@Test("a building on the way turns the worker home without a jump")
func buildingOnTheWayTurnsTheWorkerHome() {
    // Forest further out, so the walk is several tiles long.
    let hut = site(1, .lumberjackHut, at: 10, 10)
    let terrain = { (tile: TileCoordinate) -> TerrainType in tile.x >= 13 && tile.y < 25 ? .forest : .grass }
    var trips: [EntityID: GatherWorkerPlanner.Trip] = [:]
    var last: GatherWorkerPlanner.Worker?
    var blocked: TileCoordinate?
    for clock in UInt64(0) ..< 600 {
        var buildings = [hut]
        if let blocked {
            buildings.append(Building(id: EntityID(raw: 9), kind: .road, anchor: blocked, state: .constructing))
        }
        var snapshot = world(buildings, terrain: terrain)
        if let blocked {
            // A building, not a road: nobody may walk there.
            var occupied = snapshot.occupiedTiles
            occupied[blocked] = EntityID(raw: 9)
            snapshot = WorldSnapshot(
                tickCount: snapshot.tickCount, simulatedTime: snapshot.simulatedTime, mapWidth: 40, mapHeight: 40,
                terrainGrid: snapshot.terrainGrid, occupiedTiles: occupied, buildings: [hut.id: hut], carriers: [],
                economy: snapshot.economy, totalPopulation: 0, camera: snapshot.camera
            )
        }
        guard let worker = plan(snapshot, clock: clock, trips: &trips).first else { continue }
        if let last {
            #expect(abs(worker.col - last.col) <= 1 && abs(worker.row - last.row) <= 1, "jumped at \(clock)")
        }
        if let blocked { #expect(tile(worker) != blocked, "the worker on the new building") }
        // Block the far end of the trip while the worker is on its way out.
        if blocked == nil, worker.walking, worker.load == nil, let path = trips[hut.id]?.path, path.count > 2 {
            blocked = path[path.count - 1]
        }
        last = worker
    }
    #expect(blocked != nil)
}
