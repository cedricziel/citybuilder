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

private func world(_ sites: [Building], tick: UInt64 = 180, issues: [EntityID: BuildingIssue] = [:], zoom: Double = 1) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 40, height: 40, fill: .grass, seed: 1).snapshot()
    var occupied: [TileCoordinate: EntityID] = [:]
    for building in sites {
        for tile in BuildingCatalog.spec(for: building.kind).footprint.tiles(anchor: building.anchor) {
            occupied[tile] = building.id
        }
    }
    return WorldSnapshot(
        tickCount: tick, simulatedTime: base.simulatedTime, mapWidth: 40, mapHeight: 40,
        terrainGrid: (0 ..< 1600).map { land(TileCoordinate(x: $0 % 40, y: $0 / 40)) }, occupiedTiles: occupied,
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

private func plan(_ snapshot: WorldSnapshot, clock: UInt64) -> [GatherWorkerPlanner.Worker] {
    GatherWorkerPlanner.workers(in: snapshot, xRange: 0 ... 39, yRange: 0 ... 39, clock: clock, ground: ground(snapshot))
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
    var reachedForest = false, carriedLogs = false, walkedOut = false
    for clock in UInt64(0) ..< 400 {
        let workers = plan(snapshot, clock: clock)
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

@Test("scenario: an idle site stays empty")
func scenarioAnIdleSiteStaysEmpty() {
    let hut = site(1, .lumberjackHut, at: 11, 10)
    #expect(plan(world([hut], issues: [hut.id: .noTreesInReach]), clock: 100).isEmpty)
    let farHut = site(2, .lumberjackHut, at: 2, 10)
    #expect(plan(world([farHut]), clock: 100).isEmpty, "no forest within the catchment")
    let rival = Building(
        id: EntityID(raw: 3),
        kind: .lumberjackHut,
        anchor: TileCoordinate(x: 10, y: 10),
        state: .operational,
        owner: .rival(1)
    )
    #expect(plan(world([rival]), clock: 100).isEmpty, "a rival's site has no known issues, so it stays empty")
}

@Test("scenario: a miner carries a crate")
func scenarioAMinerCarriesACrate() {
    let mine = site(1, .mine, at: 20, 30)
    let loads = Set((UInt64(0) ..< 400).compactMap { plan(world([mine]), clock: $0).first?.load })
    #expect(loads == [.crate])
}

@Test("workers stay in budget and out of far zoom")
func workersStayInBudget() {
    let huts = (0 ..< 24).map { site(UInt32(100 + $0), .lumberjackHut, at: 11, $0 * 1) }
    #expect(plan(world(huts), clock: 50).count <= GatherWorkerPlanner.maxWorkers)
    #expect(plan(world([site(1, .lumberjackHut, at: 11, 10)], zoom: 0.4), clock: 50).isEmpty)
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
@Test("the scene draws the worker by its feet and holds it while paused and at night")
func sceneDrawsAndHoldsTheWorker() throws {
    let hut = site(1, .lumberjackHut, at: 11, 20)
    let scene = scene(showing: world([hut], tick: 180))
    scene.update(0)
    let shown = try #require(scene.gatherNodes[hut.id])
    #expect(abs(shown.node.zPosition - IsoWorldScene.figureZ(at: shown.node.position)) < 0.0001)
    let (col, row) = IsoMath.tileCoordinate(forScreenPoint: shown.node.position)
    let here = TileCoordinate(x: Int(col.rounded()), y: Int(row.rounded()))
    #expect(scene.isYard(here, in: world([hut])))
    scene.update(1)
    #expect(scene.gatherNodes.values.allSatisfy { !$0.pose.moving }, "paused: the worker stands")
    (scene.dataSource as? FixedSnapshot)?.snapshot = world([hut], tick: 780)
    scene.update(1.05)
    #expect(scene.gatherNodes.values.allSatisfy { !$0.pose.moving }, "night: the worker stands")
    (scene.dataSource as? FixedSnapshot)?.snapshot = world([hut], tick: 781, issues: [hut.id: .storageFull])
    scene.update(1.1)
    #expect(scene.gatherNodes.isEmpty && shown.node.parent == nil)
}
