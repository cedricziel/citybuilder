import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/add-grazing-animals.

private func farmland(
    _ buildings: [Building], tick: UInt64, pops: [EntityID: HousePopulation] = [:], zoom: Double = 1,
    season: Season = .summer, terrain: ((TileCoordinate) -> TerrainType)? = nil, center: (x: Double, y: Double) = (20, 20)
) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 40, height: 40, fill: .grass, seed: 1).snapshot()
    var occupied: [TileCoordinate: EntityID] = [:]
    for building in buildings {
        for tile in BuildingCatalog.spec(for: building.kind).footprint.tiles(anchor: building.anchor) {
            occupied[tile] = building.id
        }
    }
    let grid = terrain.map { kind in (0 ..< 1600).map { kind(TileCoordinate(x: $0 % 40, y: $0 / 40)) } } ?? base.terrainGrid
    return WorldSnapshot(
        tickCount: tick, simulatedTime: base.simulatedTime, mapWidth: 40, mapHeight: 40,
        terrainGrid: grid, occupiedTiles: occupied,
        buildings: Dictionary(uniqueKeysWithValues: buildings.map { ($0.id, $0) }), carriers: [],
        economy: base.economy, totalPopulation: 0, camera: Camera(centerX: center.x, centerY: center.y, zoom: zoom), housePopulations: pops,
        date: GameDate(year: 1200, season: season)
    )
}

private func farm(_ raw: UInt32, _ kind: BuildingKind = .farm, at x: Int, _ y: Int) -> Building {
    Building(id: EntityID(raw: raw), kind: kind, anchor: TileCoordinate(x: x, y: y), state: .operational)
}

private func house(_ raw: UInt32, at x: Int, _ y: Int) -> Building {
    Building(id: EntityID(raw: raw), kind: .house, anchor: TileCoordinate(x: x, y: y), state: .operational)
}

private func residents(_ houses: [Building]) -> [EntityID: HousePopulation] {
    var pop = HousePopulation()
    pop.population = 3
    return Dictionary(uniqueKeysWithValues: houses.map { ($0.id, pop) })
}

private func plan(
    _ snapshot: WorldSnapshot, clock: UInt64? = nil,
    free: ((TileCoordinate) -> Bool)? = nil, yard: ((TileCoordinate) -> Bool)? = nil
) -> [AnimalPlanner.Animal] {
    var tours: [AnimalKey: AnimalPlanner.Tour] = [:]
    return plan(snapshot, clock: clock, free: free, yard: yard, tours: &tours)
}

private func plan(
    _ snapshot: WorldSnapshot, clock: UInt64? = nil,
    free: ((TileCoordinate) -> Bool)? = nil, yard: ((TileCoordinate) -> Bool)? = nil,
    tours: inout [AnimalKey: AnimalPlanner.Tour]
) -> [AnimalPlanner.Animal] {
    let open = free ?? { snapshot.terrain(at: $0) == .grass && snapshot.occupiedTiles[$0] == nil }
    return AnimalPlanner.animals(
        in: snapshot, visible: (0 ... 39, 0 ... 39), clock: clock ?? AnimalPlanner.dayClock(tick: snapshot.tickCount),
        ground: AnimalPlanner.Ground(isFreeGrass: open, isYard: yard ?? open), tours: &tours
    )
}

private func tile(of animal: AnimalPlanner.Animal) -> TileCoordinate {
    TileCoordinate(x: Int(animal.col.rounded()), y: Int(animal.row.rounded()))
}

@Test("scenario: sheep graze beside a farm")
func scenarioSheepGrazeBesideAFarm() {
    let sheepFarm = farm(1, at: 10, 10)
    for tick in stride(from: UInt64(100), to: 600, by: 13) {
        let snapshot = farmland([sheepFarm], tick: tick)
        let sheep = plan(snapshot)
        #expect((2 ... 4).contains(sheep.count) && sheep.allSatisfy { $0.kind == .sheep })
        for animal in sheep {
            #expect(snapshot.occupiedTiles[tile(of: animal)] == nil, "a sheep on the farm at \(tile(of: animal))")
            #expect((8 ... 13).contains(tile(of: animal).x) && (8 ... 13).contains(tile(of: animal).y))
        }
    }
    let cows = plan(farmland([farm(2, .grainFarm, at: 10, 10)], tick: 180))
    #expect((1 ... 2).contains(cows.count) && cows.allSatisfy { $0.kind == .cow })
}

@Test("scenario: walks stay on free grass")
func scenarioWalksStayOnFreeGrass() {
    let sheepFarm = farm(1, at: 10, 10), cottage = house(9, at: 13, 8)
    // Trees on every third tile and a house cut the pasture up.
    let free = { (tile: TileCoordinate) in (tile.x * 7 + tile.y * 3) % 3 != 0 && !(13 ... 14).contains(tile.x) || tile.y > 9 }
    var walked = false
    for tick in UInt64(100) ..< 600 {
        let snapshot = farmland([sheepFarm, cottage], tick: tick)
        let isFree = { (tile: TileCoordinate) in free(tile) && snapshot.occupiedTiles[tile] == nil }
        for animal in plan(snapshot, free: isFree) {
            #expect(isFree(tile(of: animal)), "an animal on a blocked tile at \(tile(of: animal)), tick \(tick)")
            walked = walked || animal.walking
        }
    }
    #expect(walked)
}

@Test("scenario: no jump when the pasture is built on")
func scenarioNoJumpWhenThePastureIsBuiltOn() {
    let sheepFarm = farm(1, at: 10, 10)
    let snapshot = farmland([sheepFarm], tick: 180)
    let footprint = Set(BuildingCatalog.spec(for: .farm).footprint.tiles(anchor: sheepFarm.anchor))
    // A road grows across the pasture, a tile every 15 ticks, along row 9 then column 9.
    let road = (8 ... 14).map { TileCoordinate(x: $0, y: 9) } + (10 ... 14).map { TileCoordinate(x: 9, y: $0) }
    var tours: [AnimalKey: AnimalPlanner.Tour] = [:]
    var last: [AnimalPlanner.Animal] = []
    for clock in UInt64(100) ..< 700 {
        let laid = Set(road.prefix(Int(clock - 100) / 15))
        let free = { (tile: TileCoordinate) in !footprint.contains(tile) && !laid.contains(tile) }
        let sheep = plan(snapshot, clock: clock, free: free, tours: &tours)
        #expect(sheep.count == last.count || last.isEmpty)
        for (old, new) in zip(last, sheep) {
            #expect(abs(old.col - new.col) <= 1 && abs(old.row - new.row) <= 1, "jumped at \(clock)")
        }
        for animal in sheep where !animal.walking {
            #expect(free(tile(of: animal)), "a sheep standing on the road at \(tile(of: animal)), clock \(clock)")
        }
        last = sheep
    }
}

@Test("scenario: no animals inside a tree clump")
func scenarioNoAnimalsInsideATreeClump() {
    #expect(plan(farmland([farm(1, at: 10, 10)], tick: 180), free: { _ in false }).isEmpty)
}

@Test("scenario: animals hold still at night")
func scenarioAnimalsHoldStillAtNight() {
    let early = plan(farmland([farm(1, at: 10, 10)], tick: 700))
    let later = plan(farmland([farm(1, at: 10, 10)], tick: 1000))
    #expect(!early.isEmpty)
    #expect(early.map(\.col) == later.map(\.col) && early.map(\.row) == later.map(\.row))
}

@Test("scenario: no jump at dusk or dawn")
func scenarioNoJumpAtDuskOrDawn() {
    let farms = [farm(1, at: 10, 10), farm(2, .grainFarm, at: 20, 20)]
    for (first, second) in [(UInt64(599), UInt64(601)), (1019, 1021), (1799, 1801), (2219, 2221)] {
        let before = plan(farmland(farms, tick: first)), after = plan(farmland(farms, tick: second))
        #expect(before.count == after.count)
        for (old, new) in zip(before, after) {
            #expect(abs(old.col - new.col) <= 1 && abs(old.row - new.row) <= 1, "jumped between \(first) and \(second)")
        }
    }
}

@Test("the day clock stops at night and runs by day")
func dayClockStopsAtNight() {
    #expect(AnimalPlanner.dayClock(tick: 700) == AnimalPlanner.dayClock(tick: 1000))
    #expect(AnimalPlanner.dayClock(tick: 1021) == AnimalPlanner.dayClock(tick: 1020) + 1)
    #expect(AnimalPlanner.dayClock(tick: 301) == AnimalPlanner.dayClock(tick: 300) + 1)
    for tick in UInt64(0) ..< 2400 where TimeOfDay(tick: tick).phase == .night {
        #expect(AnimalPlanner.dayClock(tick: tick + 1) == AnimalPlanner.dayClock(tick: tick) || TimeOfDay(tick: tick + 1).phase != .night)
    }
}

@Test("animals walk now and then by day")
func animalsWalkByDay() {
    #expect((UInt64(100) ..< 500).contains { plan(farmland([farm(1, at: 10, 10)], tick: $0)).contains(where: \.walking) })
}

@Test("scenario: no animals in winter")
func scenarioNoAnimalsInWinter() {
    let cottage = house(5, at: 20, 20)
    let snapshot = farmland([farm(1, at: 10, 10), cottage], tick: 180, pops: residents([cottage]), season: .winter)
    #expect(plan(snapshot).isEmpty)
}

@Test("scenario: hens peck by an inhabited house")
func scenarioHensPeckByAnInhabitedHouse() {
    let cottage = house(5, at: 20, 20)
    for tick in stride(from: UInt64(100), to: 500, by: 7) {
        let snapshot = farmland([cottage], tick: tick, pops: residents([cottage]))
        let hens = plan(snapshot)
        #expect((1 ... 2).contains(hens.count) && hens.allSatisfy { $0.kind == .hen })
        for hen in hens {
            #expect(snapshot.occupiedTiles[tile(of: hen)] == nil, "a hen on the house plot at \(tile(of: hen))")
            #expect(tile(of: hen).x == 22 || tile(of: hen).y == 22)
        }
    }
    #expect(plan(farmland([cottage], tick: 180, pops: residents([cottage]), zoom: 0.6)).isEmpty, "too far out for hens")
    #expect(plan(farmland([cottage], tick: 780, pops: residents([cottage]))).isEmpty, "hens are in at night")
    #expect(plan(farmland([cottage], tick: 180)).isEmpty, "an empty house keeps no hens")
    #expect(plan(farmland([cottage], tick: 180, pops: residents([cottage])), yard: { _ in false }).isEmpty, "no yard, no hens")
}

@Test("a hen may peck on the road in front of the house")
func henOnTheRoad() {
    let cottage = house(5, at: 20, 20)
    let road = TileCoordinate(x: 22, y: 21)
    let hens = plan(farmland([cottage], tick: 180, pops: residents([cottage])), free: { _ in false }, yard: { $0 == road })
    #expect(!hens.isEmpty && hens.allSatisfy { tile(of: $0) == road })
}

@Test("scenario: animals stay in budget")
func scenarioAnimalsStayInBudget() {
    let farms = (0 ..< 40).map { farm(UInt32(100 + $0), at: ($0 % 8) * 5, ($0 / 8) * 7) }
    #expect(plan(farmland(farms, tick: 180)).count <= AnimalPlanner.maxHerd)
    #expect(plan(farmland(farms, tick: 180, zoom: 0.4)).isEmpty)
    let houses = (0 ..< 40).map { house(UInt32(300 + $0), at: ($0 % 8) * 5, ($0 / 8) * 7) }
    let hens = plan(farmland(houses, tick: 180, pops: residents(houses)))
    #expect(hens.count == AnimalPlanner.maxHens)
}

@Test("scenario: panning to a farm gives it animals")
func budgetGoesToTheFarmsNearestTheCamera() {
    // 40 farms, more sheep than the budget, all in view.
    let farms = (0 ..< 40).map { farm(UInt32(100 + $0), at: ($0 % 8) * 5, ($0 / 8) * 7) }
    for center in [(x: 35.0, y: 28.0), (x: 0.0, y: 0.0), (x: 20.0, y: 14.0)] {
        let animals = plan(farmland(farms, tick: 180, center: center))
        let herded = Set(animals.map(\.home))
        #expect(animals.count <= AnimalPlanner.maxHerd)
        // Farms get animals by distance from the camera centre until the budget is full.
        let byDistance = farms.sorted {
            let lhs = pow(Double($0.anchor.x) - center.x, 2) + pow(Double($0.anchor.y) - center.y, 2)
            let rhs = pow(Double($1.anchor.x) - center.x, 2) + pow(Double($1.anchor.y) - center.y, 2)
            return (lhs, $0.id.raw) < (rhs, $1.id.raw)
        }
        #expect(herded.contains(byDistance[0].id), "the farm under the camera at \(center) has no animals")
        let served = byDistance.prefix { herded.contains($0.id) }.count
        #expect(served == herded.count, "a farm at \(center) has animals while a nearer one has none")
    }
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
@Test("the scene keeps animals off trees, rock and water")
func sceneKeepsAnimalsOffTreesRockAndWater() {
    // Forest to the west, rock to the north, water to the south of the farm.
    let terrain = { (tile: TileCoordinate) -> TerrainType in
        tile.x < 10 ? .forest : tile.y < 10 ? .mountain : tile.y > 13 ? .water : .grass
    }
    let farmhouse = farm(1, at: 10, 10)
    for tick in stride(from: UInt64(100), to: 600, by: 37) {
        let snapshot = farmland([farmhouse], tick: tick, terrain: terrain)
        let scene = scene(showing: snapshot)
        scene.update(0)
        #expect(scene.objectMap != nil)
        for (_, shown) in scene.animalNodes {
            let (col, row) = IsoMath.tileCoordinate(forScreenPoint: shown.node.position)
            let here = TileCoordinate(x: Int(col.rounded()), y: Int(row.rounded()))
            #expect(scene.isFreeGrass(here, in: snapshot), "an animal on \(snapshot.terrain(at: here).map { "\($0)" } ?? "-") at \(here)")
        }
    }
}

@MainActor
@Test("a paused game holds the animals on their standing frame")
func pausedGameHoldsAnimals() {
    let scene = scene(showing: farmland([farm(1, at: 20, 20)], tick: 180))
    scene.update(0)
    #expect(scene.animalNodes.values.contains { $0.pose.moving })
    scene.update(1)
    #expect(!scene.animalNodes.isEmpty && scene.animalNodes.values.allSatisfy { !$0.pose.moving })
}

@MainActor
@Test("reduce motion holds the animals where they stood")
func reduceMotionHoldsAnimals() {
    let scene = scene(showing: farmland([farm(1, at: 20, 20)], tick: 180))
    scene.reduceMotion = true
    scene.update(0)
    let first = scene.animalNodes.mapValues(\.node.position)
    (scene.dataSource as? FixedSnapshot)?.snapshot = farmland([farm(1, at: 20, 20)], tick: 400)
    scene.update(0.1)
    #expect(!first.isEmpty && scene.animalNodes.allSatisfy { key, shown in
        shown.node.action(forKey: SKNode.glideKey) == nil && first[key] == shown.node.position
    })
}

@MainActor
@Test("the scene draws animals anchored at their feet and drops them when the farm goes")
func animalNodesFollowThePlan() throws {
    let scene = scene(showing: farmland([farm(1, at: 20, 20)], tick: 180))
    scene.update(0)
    let shown = try #require(scene.animalNodes.values.first)
    let anchor = shown.pose.action.anchor
    #expect(abs(shown.node.anchorPoint.x - anchor.x) < 0.001 && abs(shown.node.anchorPoint.y - anchor.y) < 0.001)
    (scene.dataSource as? FixedSnapshot)?.snapshot = farmland([], tick: 181)
    scene.update(0.1)
    #expect(scene.animalNodes.isEmpty && shown.node.parent == nil)
}

@MainActor
@Test("an animal behind a 2×2 building sorts below it, one in front above it")
func animalsSortAgainstBuildings() throws {
    let scene = scene(showing: farmland([farm(1, at: 20, 20)], tick: 180))
    scene.update(0)
    let shown = try #require(scene.animalNodes.values.first)
    let (col, row) = IsoMath.tileCoordinate(forScreenPoint: shown.node.position)
    let here = TileCoordinate(x: Int(col.rounded()), y: Int(row.rounded()))
    func house(at anchor: TileCoordinate) -> SKNode {
        scene.placedNode(for: SpriteSpec(coord: anchor, kind: .building(
            kind: .house, state: .operational, footprint: Footprint(width: 2, height: 2),
            constructionFrameIndex: nil, orientation: nil, isWaitingForMaterials: false
        )))
    }
    // The animal stands behind a house one tile nearer the camera, and in
    // front of one two tiles further back.
    #expect(shown.node.zPosition < house(at: TileCoordinate(x: here.x + 1, y: here.y)).zPosition)
    #expect(shown.node.zPosition > house(at: TileCoordinate(x: here.x - 2, y: here.y - 2)).zPosition)
    #expect(scene.animalNodes.values.allSatisfy { abs($0.node.zPosition - IsoWorldScene.figureZ(at: $0.node.position)) < 0.0001 })
}
