import Testing
@testable import CityCore

// The figures behind platform-shells / Deficit hint
// (openspec/changes/deficit-hint, design D3).

@Test("player tax and upkeep match what a collection credits and deducts", arguments: Difficulty.allCases)
func playerTaxAndUpkeepMatchACollection(difficulty: Difficulty) {
    var world = World.newGame(layout: .singleIsland, seed: 0, difficulty: difficulty)
    for _ in 0 ..< 3 {
        world.testAddHouse(owner: .player, residents: 4)
    }
    world.testAddBuilding(.sawmill, owner: .player)
    world.testAddBuilding(.sawmill, owner: .player)
    var events: [WorldEvent] = []
    repeat {
        events = world.tick().events
    } while !world.tickCount.isMultiple(of: Economy.taxIntervalTicks)
    let figures = world.playerTaxAndUpkeep
    #expect(figures.tax > 0)
    #expect(figures.upkeep > 0)
    #expect(events.contains(.taxesCollected(amount: figures.tax)))
    #expect(events.contains(.upkeepPaid(amount: figures.upkeep)))
}
