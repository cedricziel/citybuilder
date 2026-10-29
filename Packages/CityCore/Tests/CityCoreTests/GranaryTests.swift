import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-event-counterplay
// (buildings-and-construction / Granary; calendar-and-events / History
// events at the turn of the year, the granary scenarios).

private func roads(_ tiles: [TileCoordinate], in world: inout World) {
    for tile in tiles {
        SignatureFixture.inject(.road, at: tile, in: &world)
        world.roadGraph.addRoad(at: tile)
    }
}

/// A road along y = 2 from x = 0 to 9, with a granary above it at x = 4.
private func granaryWorld() -> (world: World, granary: EntityID) {
    var world = World.fixtureWithTerrain(width: 12, height: 6, fill: .grass, seed: 1)
    roads((0 ... 9).map { TileCoordinate(x: $0, y: 2) }, in: &world)
    let granary = addOperational(.granary, at: TileCoordinate(x: 4, y: 0), in: &world)
    return (world, granary)
}

@Test("scenario: A granary refuses planks")
func granaryRefusesPlanks() {
    let (world, granary) = granaryWorld()
    let start = TileCoordinate(x: 0, y: 2)
    #expect(world.findRoadConnectedBuffer(fromRoad: start, good: .planks) == nil)
    let food = world.findRoadConnectedBuffer(fromRoad: start, good: .food)
    #expect(food?.0 == granary)
}

@Test func granaryHoldsSixtyOfEachFoodGood() throws {
    let (world, granary) = granaryWorld()
    var stock = try #require(world.stockpiles[granary])
    for good: Good in [.food, .grain, .flour, .bread] {
        #expect(stock.room(for: good) == 60)
    }
    #expect(stock.deposit(.planks, amount: 5) == 0)
    #expect(stock.deposit(.bread, amount: 70) == 60)
    #expect(stock.freeSpace == 180)
}

@Test func granaryStockSurvivesASave() throws {
    let (world, granary) = granaryWorld()
    let stock = try #require(world.stockpiles[granary])
    let decoded = try JSONDecoder().decode(Stockpile.self, from: JSONEncoder().encode(stock))
    #expect(decoded == stock)
    #expect(decoded.room(for: .wood) == 0)
}

@Test func storesWithoutALimitAcceptEveryGood() throws {
    let legacy = Data(#"{"capacity":80,"limitsEachGood":true,"contents":[]}"#.utf8)
    let stock = try JSONDecoder().decode(Stockpile.self, from: legacy)
    #expect(stock.room(for: .planks) == 80)
    let data = try JSONEncoder().encode(Stockpile(perGood: 80))
    let encoded = String(bytes: data, encoding: .utf8) ?? ""
    #expect(!encoded.contains("accepted"))
}

@Test func islandSummaryCountsOnlyWhatAGranaryTakes() throws {
    var world = World.fixtureWithTerrain(width: 12, height: 6, fill: .grass, seed: 1)
    world.islands = IslandDetector.detectIslands(
        width: 12, height: 6, terrain: world.terrainGrid, mapHeightForClimate: 6, seed: 1
    )
    addOperational(.granary, at: TileCoordinate(x: 4, y: 0), in: &world)
    let summary = try #require(world.snapshot().islandSummaries.values.first)
    #expect(summary.capacity[.food] == 60)
    #expect(summary.capacity[.planks] == nil)
}

@Test("scenario: Rats leave the granary alone")
func ratsLeaveTheGranaryAlone() {
    var (world, granary) = granaryWorld()
    let warehouse = addOperational(.warehouse, at: TileCoordinate(x: 0, y: 3), in: &world)
    world.stockpiles[warehouse]?.deposit(.food, amount: 9)
    world.stockpiles[granary]?.deposit(.food, amount: 20)
    world.applyHistoryEvent(.ratsInTheGranary)
    #expect(world.stockpiles[warehouse]?.quantity(of: .food) == 5)
    #expect(world.stockpiles[granary]?.quantity(of: .food) == 20)
}

@Test("scenario: Only the granary holds food")
func onlyTheGranaryHoldsFood() throws {
    let seed = try #require((UInt64(0) ..< 500).first {
        eventsWorld(seed: $0, size: 1).historyEvent(forYear: 1201) == .ratsInTheGranary
    })
    var world = eventsWorld(seed: seed, size: 12)
    world.seasonalEvents.enabled = false
    let granary = addOperational(.granary, at: TileCoordinate(x: 0, y: 0), in: &world)
    world.stockpiles[granary]?.deposit(.food, amount: 30)
    let events = runSeasons(&world, untilTick: firstTick(of: .spring, 1201))
    let fired = events.contains { if case .historyEvent = $0 { true } else { false } }
    #expect(!fired)
    #expect(world.stockpiles[granary]?.quantity(of: .food) == 30)
}
