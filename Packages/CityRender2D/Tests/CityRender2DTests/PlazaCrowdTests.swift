import CityCore
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/add-plaza-crowd.

private let center = Building(id: EntityID(raw: 1), kind: .townCenter, anchor: TileCoordinate(x: 8, y: 8), state: .operational)

private func town(residents: UInt32, tick: UInt64, zoom: Double = 1) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 30, height: 30, fill: .grass, seed: 1).snapshot()
    var buildings = [center.id: center]
    var pops: [EntityID: HousePopulation] = [:]
    for index in 0 ..< 3 {
        let house = Building(
            id: EntityID(raw: UInt32(10 + index)), kind: .house, anchor: TileCoordinate(x: 3 + index * 2, y: 3), state: .operational
        )
        buildings[house.id] = house
        var pop = HousePopulation()
        pop.population = residents / 3
        pops[house.id] = pop
    }
    // A house beyond 12 tiles does not count.
    let far = Building(id: EntityID(raw: 20), kind: .house, anchor: TileCoordinate(x: 25, y: 25), state: .operational)
    buildings[far.id] = far
    var farPop = HousePopulation()
    farPop.population = 30
    pops[far.id] = farPop
    return WorldSnapshot(
        tickCount: tick, simulatedTime: base.simulatedTime, mapWidth: 30, mapHeight: 30,
        terrainGrid: base.terrainGrid, occupiedTiles: [:], buildings: buildings, carriers: [],
        economy: base.economy, totalPopulation: 0, camera: Camera(centerX: 8, centerY: 8, zoom: zoom),
        housePopulations: pops
    )
}

private func plan(_ snapshot: WorldSnapshot, reduceMotion: Bool = false) -> [PlazaCrowdPlanner.Figure] {
    PlazaCrowdPlanner.figures(in: snapshot, xRange: 0 ... 29, yRange: 0 ... 29, reduceMotion: reduceMotion)
}

@Test("scenario: busy plaza by day")
func scenarioBusyPlazaByDay() {
    #expect(plan(town(residents: 30, tick: 180)).count == 8)
    #expect(plan(town(residents: 9, tick: 180)).count == 3)
}

@Test("scenario: empty plaza at night")
func scenarioEmptyPlazaAtNight() {
    #expect(plan(town(residents: 30, tick: 780)).isEmpty)
}

@Test("no crowd when zoomed far out or off screen")
func noCrowdZoomedOutOrOffscreen() {
    #expect(plan(town(residents: 30, tick: 180, zoom: 0.4)).isEmpty)
    let snapshot = town(residents: 30, tick: 180)
    #expect(PlazaCrowdPlanner.figures(in: snapshot, xRange: 0 ... 5, yRange: 0 ... 5, reduceMotion: false).isEmpty)
}

@Test("scenario: figures stay on the plaza")
func scenarioFiguresStayOnThePlaza() {
    let plazaU = PlazaCrowdPlanner.plazaU, plazaV = PlazaCrowdPlanner.plazaV
    var walked = false
    for tick in stride(from: UInt64(0), to: TimeOfDay.ticksPerDay, by: 7) {
        for figure in plan(town(residents: 30, tick: tick)) {
            let localU = figure.col - Double(center.anchor.x) + 0.5
            let localV = figure.row - Double(center.anchor.y) + 0.5
            #expect(plazaU.contains(localU) && plazaV.contains(localV))
            walked = walked || figure.walking
        }
    }
    #expect(walked)
}

@Test("scenario: reduce motion keeps figures still")
func scenarioReduceMotionKeepsFiguresStill() {
    let early = plan(town(residents: 30, tick: 100), reduceMotion: true)
    let later = plan(town(residents: 30, tick: 400), reduceMotion: true)
    #expect(early.map(\.col) == later.map(\.col) && early.map(\.row) == later.map(\.row))
    #expect(early.allSatisfy { !$0.walking })
}

@Test("figures of one plaza are spread out and stable per tick")
func figuresAreSpreadAndStable() {
    let first = plan(town(residents: 30, tick: 200))
    #expect(Set(first.map { "\($0.col),\($0.row)" }).count == first.count)
    #expect(plan(town(residents: 30, tick: 200)) == first)
}
