import Testing
@testable import CityCore

private typealias Fixture = SignatureFixture

// platform-shells / First-hour guide and Tool strip warns while the guide
// shows (openspec/changes/first-hour-guidance): the CityCore queries the
// guide reads.

@Test("upkeep per collection includes the mead hall's relief at the site")
func upkeepPerCollectionIncludesRelief() {
    var world = Fixture.grass(width: 60)
    Fixture.fuelled(.meadHall, at: TileCoordinate(x: 2, y: 2), in: &world)
    Fixture.runUntilBefore(multipleOf: Economy.upkeepIntervalTicks, in: &world)
    #expect(world.upkeepPerCollection(of: .sawmill, at: nil) == 2)
    // A served mead hall waives upkeep in its reach.
    #expect(world.upkeepPerCollection(of: .sawmill, at: TileCoordinate(x: 7, y: 2)) == 0)
    #expect(world.upkeepPerCollection(of: .sawmill, at: TileCoordinate(x: 30, y: 30)) == 2)
    #expect(world.upkeepPerCollection(of: .lumberjackHut, at: TileCoordinate(x: 7, y: 2)) == 0)
}

@Test("a house is road-connected only with a road beside it")
func houseRoadConnection() throws {
    var world = Fixture.grass(width: 20)
    let house = Fixture.inject(.house, at: TileCoordinate(x: 4, y: 4), in: &world)
    #expect(try !world.isRoadConnected(#require(world.buildings[house])))
    world.enqueue(.place(.road, at: TileCoordinate(x: 6, y: 4)))
    world.tick()
    #expect(try world.isRoadConnected(#require(world.buildings[house])))
}
