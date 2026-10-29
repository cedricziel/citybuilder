import Foundation
import Testing
@testable import CityCore

// The PlayerBot's events kit (openspec/changes/add-event-counterplay D12,
// task 7.3). The sweeps themselves wait for the sweep slot.

private let isFullSweep = ProcessInfo.processInfo.environment["RIVAL_SWEEP"] == "1"

/// Six houses along a road at y = 3, from x = 0 to 17.
private func streetWorld() -> World {
    var world = eventsWorld(size: 30)
    world.economy.balance = 1000
    for x in 0 ... 20 {
        SignatureFixture.inject(.road, at: TileCoordinate(x: x, y: 3), in: &world)
        world.roadGraph.addRoad(at: TileCoordinate(x: x, y: 3))
    }
    addHouses(6, row: 1, in: &world)
    return world
}

@Test("scenario: the kit builds a fire watch in fire season")
func kitBuildsAFireWatch() throws {
    var world = streetWorld()
    var kit = EventsKit()
    kit.takeTurn(&world)
    #expect(world.pendingCommands.isEmpty)
    world.seasonalEvents.warned = SeasonalEventOnset(event: .fire, season: .summer)
    kit.takeTurn(&world)
    world.tick()
    #expect(kit.watchesBuilt == 0)
    kit.takeTurn(&world)
    let watch = try #require(world.buildings.values.first { $0.kind == .fireWatch })
    let firstHouse = try #require(world.buildings.values.filter { $0.kind == .house }.min { $0.id.raw < $1.id.raw })
    #expect(World.footprintDistance(watch, firstHouse) <= World.fireWatchReach)
    #expect(kit.watchesBuilt == 1)
}

@Test("scenario: the kit covers every cluster once")
func kitCoversEveryClusterOnce() {
    var world = streetWorld()
    world.seasonalEvents.warned = SeasonalEventOnset(event: .fire, season: .summer)
    var kit = EventsKit()
    for _ in 0 ..< 10 {
        kit.takeTurn(&world)
        for _ in 0 ... BuildingCatalog.spec(for: .fireWatch).buildDurationTicks {
            world.tick()
        }
    }
    kit.takeTurn(&world)
    let uncovered = EventsKit.uncovered(in: world)
    #expect(uncovered.isEmpty)
    #expect(kit.watchesBuilt == 2)
}

@Test("scenario: the kit waits for the money")
func kitWaitsForTheMoney() {
    var world = streetWorld()
    world.economy.balance = 100
    world.seasonalEvents.warned = SeasonalEventOnset(event: .fire, season: .summer)
    var kit = EventsKit()
    kit.takeTurn(&world)
    #expect(world.pendingCommands.isEmpty)
}

// MARK: - Sweeps (design D12, bars 1 and 2): run in the sweep slot only

@Test(
    "scenario: guided Hard start stays solvent with fire season",
    .enabled(if: isFullSweep, "set RIVAL_SWEEP=1"),
    arguments: Array(UInt64(0) ..< 10)
)
func guidedHardStartWithFireSeason(seed: UInt64) {
    for layout in [WorldLayout.singleIsland, .archipelago] {
        let world = World.botGame(
            layout: layout, seed: seed, difficulty: .hard, tradesAtMarket: true,
            firstSteps: PlayerBot.guideSteps, events: .drawn(answered: true), ticks: 12000
        )
        let residents = world.population(of: .player)
        let lost = world.seasonalEvents.counters.buildingsLostToFire
        print(
            "GUIDE_SWEEP events seed=\(seed) layout=\(layout.rawValue) bankrupt=\(world.economy.gameOver) "
                + "residents=\(residents) lost=\(lost)"
        )
        #expect(!world.economy.gameOver, "\(layout) seed \(seed)")
        #expect(residents >= 25, "\(layout) seed \(seed): \(residents) residents")
    }
}

@Test(
    "scenario: a forced fire in 1202 leaves the first hour standing",
    .enabled(if: isFullSweep, "set RIVAL_SWEEP=1"),
    arguments: Array(UInt64(0) ..< 10)
)
func forcedFireFirstHour(seed: UInt64) {
    for layout in [WorldLayout.singleIsland, .archipelago] {
        for onset in [Season.summer, .autumn] {
            let run = { (answered: Bool) in
                World.botGame(
                    layout: layout, seed: seed, difficulty: .hard, tradesAtMarket: true,
                    firstSteps: PlayerBot.guideSteps, events: .forced(.fire, onset, answered: answered), ticks: 12000
                )
            }
            let with = run(true), without = run(false)
            let lostWith = with.seasonalEvents.counters.buildingsLostToFire
            let lostWithout = without.seasonalEvents.counters.buildingsLostToFire
            let residents = with.population(of: .player)
            print(
                "FIRE_SWEEP seed=\(seed) layout=\(layout.rawValue) onset=\(onset) bankrupt=\(with.economy.gameOver) "
                    + "residents=\(residents) lost_with=\(lostWith) lost_without=\(lostWithout)"
            )
            #expect(!with.economy.gameOver, "\(layout) seed \(seed) \(onset)")
            #expect(residents >= 20, "\(layout) seed \(seed) \(onset): \(residents) residents")
        }
    }
}

@Test("scenario: a watch on another road network doesn't cover a house")
func watchOnAnotherNetworkDoesNotCover() throws {
    var world = streetWorld()
    let watch = addOperational(.fireWatch, at: TileCoordinate(x: 2, y: 6), in: &world)
    let house = try #require(world.buildings.values.filter { $0.kind == .house }.min { $0.id.raw < $1.id.raw })
    let watchBuilding = try #require(world.buildings[watch])
    #expect(World.footprintDistance(watchBuilding, house) <= World.fireWatchReach)
    #expect(!world.fireWatchCovers(watchBuilding, house))
    let first = EventsKit.uncovered(in: world).first
    #expect(first?.id == house.id)
}

@Test("scenario: a placement that fails is not counted")
func failedPlacementIsNotCounted() {
    var world = streetWorld()
    world.seasonalEvents.warned = SeasonalEventOnset(event: .fire, season: .summer)
    var kit = EventsKit()
    kit.takeTurn(&world)
    // The money is gone before the command runs.
    world.economy.balance = 0
    world.tick()
    world.economy.balance = 1000
    kit.takeTurn(&world)
    #expect(kit.watchesBuilt == 0)
}

@Test("scenario: a building with no plot is tried once")
func buildingWithoutAPlotIsTriedOnce() {
    var world = eventsWorld(size: 30)
    world.economy.balance = 1000
    // A house with no road has no plot a watch could cover it from.
    addOperational(.house, at: TileCoordinate(x: 10, y: 10), in: &world)
    world.seasonalEvents.warned = SeasonalEventOnset(event: .fire, season: .summer)
    var kit = EventsKit()
    kit.takeTurn(&world)
    kit.takeTurn(&world)
    #expect(world.pendingCommands.isEmpty)
}
