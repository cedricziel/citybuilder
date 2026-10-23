import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/add-grazing-animals.

private func farmland(_ buildings: [Building], tick: UInt64, pops: [EntityID: HousePopulation] = [:], zoom: Double = 1) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 40, height: 40, fill: .grass, seed: 1).snapshot()
    var occupied: [TileCoordinate: EntityID] = [:]
    for building in buildings {
        for tile in BuildingCatalog.spec(for: building.kind).footprint.tiles(anchor: building.anchor) {
            occupied[tile] = building.id
        }
    }
    return WorldSnapshot(
        tickCount: tick, simulatedTime: base.simulatedTime, mapWidth: 40, mapHeight: 40,
        terrainGrid: base.terrainGrid, occupiedTiles: occupied,
        buildings: Dictionary(uniqueKeysWithValues: buildings.map { ($0.id, $0) }), carriers: [],
        economy: base.economy, totalPopulation: 0, camera: Camera(centerX: 20, centerY: 20, zoom: zoom), housePopulations: pops
    )
}

private func farm(_ raw: UInt32, _ kind: BuildingKind = .farm, at x: Int, _ y: Int) -> Building {
    Building(id: EntityID(raw: raw), kind: kind, anchor: TileCoordinate(x: x, y: y), state: .operational)
}

private func plan(
    _ snapshot: WorldSnapshot,
    reduceMotion: Bool = false,
    free: ((TileCoordinate) -> Bool)? = nil
) -> [AnimalPlanner.Animal] {
    let open = free ?? { snapshot.terrain(at: $0) == .grass && snapshot.occupiedTiles[$0] == nil }
    return AnimalPlanner.animals(in: snapshot, xRange: 0 ... 39, yRange: 0 ... 39, reduceMotion: reduceMotion, isFreeGrass: open)
}

@Test("scenario: sheep graze beside a farm")
func scenarioSheepGrazeBesideAFarm() {
    let sheepFarm = farm(1, at: 10, 10)
    for tick in stride(from: UInt64(100), to: 400, by: 13) {
        let snapshot = farmland([sheepFarm], tick: tick)
        let sheep = plan(snapshot)
        #expect((2 ... 4).contains(sheep.count) && sheep.allSatisfy { $0.kind == .sheep })
        for animal in sheep {
            let tile = TileCoordinate(x: Int(animal.col.rounded()), y: Int(animal.row.rounded()))
            #expect(snapshot.occupiedTiles[tile] == nil, "a sheep on the farm at \(tile)")
            #expect((8 ... 13).contains(tile.x) && (8 ... 13).contains(tile.y))
        }
    }
    let cows = plan(farmland([farm(2, .grainFarm, at: 10, 10)], tick: 180))
    #expect((1 ... 2).contains(cows.count) && cows.allSatisfy { $0.kind == .cow })
}

@Test("scenario: no animals inside a tree clump")
func scenarioNoAnimalsInsideATreeClump() {
    #expect(plan(farmland([farm(1, at: 10, 10)], tick: 180)) { _ in false }.isEmpty)
}

@Test("scenario: animals hold still at night")
func scenarioAnimalsHoldStillAtNight() {
    let early = plan(farmland([farm(1, at: 10, 10)], tick: 780))
    let later = plan(farmland([farm(1, at: 10, 10)], tick: 1000))
    #expect(!early.isEmpty)
    #expect(early.map(\.col) == later.map(\.col) && early.map(\.row) == later.map(\.row))
    #expect(early.allSatisfy { !$0.walking })
    #expect(plan(farmland([farm(1, at: 10, 10)], tick: 180), reduceMotion: true).allSatisfy { !$0.walking })
}

@Test("animals walk now and then by day")
func animalsWalkByDay() {
    let walks = (UInt64(100) ..< 500).contains { tick in plan(farmland([farm(1, at: 10, 10)], tick: tick)).contains(where: \.walking) }
    #expect(walks)
}

@Test("scenario: hens peck by an inhabited house")
func scenarioHensPeckByAnInhabitedHouse() {
    let house = Building(id: EntityID(raw: 5), kind: .house, anchor: TileCoordinate(x: 20, y: 20), state: .operational)
    var pop = HousePopulation()
    pop.population = 3
    let footprint = BuildingCatalog.spec(for: .house).footprint
    let hens = plan(farmland([house], tick: 180, pops: [house.id: pop]))
    #expect((1 ... 2).contains(hens.count) && hens.allSatisfy { $0.kind == .hen })
    for hen in hens {
        let localU = hen.col - 19.5, localV = hen.row - 19.5
        let onFront = localU > Double(footprint.width) - 0.4 || localV > Double(footprint.height) - 0.4
        #expect(onFront && localU <= Double(footprint.width) && localV <= Double(footprint.height))
    }
    #expect(plan(farmland([house], tick: 180, pops: [house.id: pop], zoom: 0.6)).isEmpty, "too far out for hens")
    #expect(plan(farmland([house], tick: 780, pops: [house.id: pop])).isEmpty, "hens are in at night")
    #expect(plan(farmland([house], tick: 180)).isEmpty, "an empty house keeps no hens")
}

@Test("scenario: animals stay in budget")
func scenarioAnimalsStayInBudget() {
    let farms = (0 ..< 40).map { farm(UInt32(100 + $0), at: ($0 % 8) * 5, ($0 / 8) * 7) }
    #expect(plan(farmland(farms, tick: 180)).count <= AnimalPlanner.maxHerd)
    #expect(plan(farmland(farms, tick: 180, zoom: 0.4)).isEmpty)
}

@MainActor
@Test("the scene draws animals anchored at their feet and drops them when the farm goes")
func animalNodesFollowThePlan() throws {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.reconcileAnimals(with: farmland([farm(1, at: 20, 20)], tick: 180), now: 0)
    let shown = try #require(scene.animalNodes.values.first)
    let anchor = shown.pose.action.anchor
    #expect(abs(shown.node.anchorPoint.x - anchor.x) < 0.001 && abs(shown.node.anchorPoint.y - anchor.y) < 0.001)
    scene.reconcileAnimals(with: farmland([], tick: 181), now: 0.1)
    #expect(scene.animalNodes.isEmpty && shown.node.parent == nil)
}
