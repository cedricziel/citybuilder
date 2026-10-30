import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/visible-distribution
// (warehouses-and-logistics / Market hubs gather house goods, Buildings
// report why they are idle).

/// A grass strip with a road along y = 3; a town center at (0, 0) reaches
/// it at x = 0.
private func strip(roadTo: Int = 43) -> World {
    var world = World.fixtureWithTerrain(width: 44, height: 9, fill: .grass, seed: 1)
    for x in 0 ... roadTo {
        let tile = TileCoordinate(x: x, y: 3)
        SignatureFixture.inject(.road, at: tile, in: &world)
        world.roadGraph.addRoad(at: tile)
    }
    return world
}

private func peasants(at x: Int, in world: inout World) -> EntityID {
    addOperational(.house, at: TileCoordinate(x: x, y: 4), residents: 4, in: &world)
}

private func restocks(to hub: EntityID, in world: World) -> [Carrier.Mission] {
    world.carriers.values.map(\.mission).filter {
        if case let .retrieve(_, _, _, to) = $0 { to == hub } else { false }
    }
}

@Test("scenario: Bread goes to the town center before the warehouse")
func breadGoesToTheTownCenterBeforeTheWarehouse() throws {
    var world = strip()
    let center = addOperational(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world)
    _ = addOperational(.warehouse, at: TileCoordinate(x: 14, y: 0), in: &world)
    let bakery = addOperational(.bakery, at: TileCoordinate(x: 18, y: 4), in: &world)
    world.stockpiles[bakery]?.deposit(.bread, amount: 1)
    _ = world.tick()
    let carrier = try #require(world.carriers.values.first)
    #expect(carrier.mission.destination == center)
}

@Test func houseGoodsUseOtherStoresWhenNoHubHasRoom() throws {
    var world = strip()
    let center = addOperational(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world)
    world.stockpiles[center]?.deposit(.bread, amount: 40)
    let store = addOperational(.warehouse, at: TileCoordinate(x: 14, y: 0), in: &world)
    let bakery = addOperational(.bakery, at: TileCoordinate(x: 18, y: 4), in: &world)
    world.stockpiles[bakery]?.deposit(.bread, amount: 1)
    _ = world.tick()
    let carrier = try #require(world.carriers.values.first)
    #expect(carrier.mission.destination == store)
}

@Test("scenario: A hub low on food restocks from a warehouse")
func hubLowOnFoodRestocksFromAWarehouse() {
    var world = strip()
    let center = addOperational(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world)
    let store = addOperational(.warehouse, at: TileCoordinate(x: 14, y: 0), in: &world)
    world.stockpiles[store]?.deposit(.food, amount: 10)
    _ = peasants(at: 6, in: &world)
    _ = world.tick()
    let missions = restocks(to: center, in: world)
    #expect(missions.count == 1)
    #expect(missions.first?.good == .food)
    #expect(missions.first?.source == store)
}

@Test func aHubRestocksOneCarrierAtATimePerGood() {
    var world = strip()
    let center = addOperational(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world)
    let store = addOperational(.warehouse, at: TileCoordinate(x: 14, y: 0), in: &world)
    world.stockpiles[store]?.deposit(.food, amount: 10)
    _ = peasants(at: 6, in: &world)
    for _ in 0 ..< 3 {
        _ = world.tick()
    }
    #expect(restocks(to: center, in: world).count == 1)
}

@Test("scenario: A hub at its reserve does not restock")
func hubAtItsReserveDoesNotRestock() {
    var world = strip()
    let center = addOperational(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world)
    world.stockpiles[center]?.deposit(.food, amount: 6)
    let store = addOperational(.warehouse, at: TileCoordinate(x: 14, y: 0), in: &world)
    world.stockpiles[store]?.deposit(.food, amount: 10)
    let home = peasants(at: 6, in: &world)
    world.populations[home]?.addStock(.food, amount: 4)
    _ = world.tick()
    #expect(world.stockpiles[center]?.quantity(of: .food) == 6)
    #expect(restocks(to: center, in: world).isEmpty)
}

// MARK: - Buildings report why they are idle

@Test("scenario: A house out of every hub's reach reports no market in reach")
func houseOutOfEveryHubsReachReportsNoMarketInReach() {
    var world = strip()
    _ = addOperational(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world)
    let home = peasants(at: 25, in: &world)
    #expect(world.buildingIssues()[home] == .noMarketInReach)
}

@Test("scenario: A house without a road reports only no road")
func houseWithoutARoadReportsOnlyNoRoad() {
    var world = strip(roadTo: 5)
    _ = addOperational(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world)
    let home = peasants(at: 25, in: &world)
    #expect(world.buildingIssues()[home] == .noRoad)
}

@Test("scenario: A marketplace clears no market in reach")
func marketplaceClearsNoMarketInReach() {
    var world = strip()
    _ = addOperational(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world)
    let home = peasants(at: 25, in: &world)
    _ = addOperational(.marketplace, at: TileCoordinate(x: 30, y: 1), in: &world)
    #expect(world.buildingIssues()[home] == nil)
}

@Test func aRivalsHubDoesNotServeThePlayersHouse() {
    var world = strip()
    _ = SignatureFixture.inject(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world, owner: .rival(1))
    let home = peasants(at: 6, in: &world)
    #expect(world.buildingIssues()[home] == .noMarketInReach)
}

@Test func aHubRestocksFromAnotherHubsSurplus() {
    var world = strip()
    let center = addOperational(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world)
    world.stockpiles[center]?.deposit(.food, amount: 30)
    let market = addOperational(.marketplace, at: TileCoordinate(x: 30, y: 1), in: &world)
    _ = peasants(at: 34, in: &world)
    _ = world.tick()
    let missions = restocks(to: market, in: world)
    #expect(missions.map(\.source) == [center])
    #expect(missions.first?.amount == 4)
}

@Test func aHubKeepsItsOwnReserveFromAnother() {
    var world = strip()
    let center = addOperational(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world)
    world.stockpiles[center]?.deposit(.food, amount: 4)
    _ = peasants(at: 6, in: &world)
    let market = addOperational(.marketplace, at: TileCoordinate(x: 30, y: 1), in: &world)
    _ = peasants(at: 34, in: &world)
    _ = world.tick()
    #expect(restocks(to: market, in: world).isEmpty)
}

@Test func aRestockOnFootCarriesABasket() {
    var world = strip()
    let center = addOperational(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world)
    world.age = .antiquity
    let store = addOperational(.warehouse, at: TileCoordinate(x: 4, y: 0), in: &world)
    world.stockpiles[store]?.deposit(.food, amount: 40)
    for x in [3, 6, 9, 12] {
        _ = peasants(at: x, in: &world)
    }
    _ = world.tick()
    #expect(restocks(to: center, in: world).first?.amount == 10)
}

@Test func aHubReachesFromEveryRoadBesideIt() {
    var world = strip()
    // The town center's road runs along its south side; a house on the far
    // end of that side is nearer than the first road tile says.
    let center = addOperational(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world)
    let home = peasants(at: 20, in: &world)
    #expect(world.hubService().hubOf[home]?.hub == center)
    #expect(world.hubService().hubOf[home]?.distance == 18)
}
