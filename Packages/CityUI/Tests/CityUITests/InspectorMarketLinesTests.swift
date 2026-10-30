import Testing
@testable import CityCore
@testable import CityUI

// platform-shells / Market lines in the inspector
// (openspec/changes/visible-distribution).

private func inspect(_ id: EntityID, in world: World) -> InspectorViewModel {
    let snapshot = world.snapshot()
    let anchor = snapshot.buildings[id]?.anchor ?? TileCoordinate(x: 0, y: 0)
    return InspectorViewModel.make(from: snapshot, tile: anchor, buildings: snapshot.buildings)
}

@Test("scenario: A house names its stock and its market")
func houseNamesItsStockAndMarket() {
    var (world, _) = marketStrip()
    let home = placeOperational(.house, at: TileCoordinate(x: 10, y: 4), residents: 2, in: &world)
    world.populations[home]?.addStock(.food, amount: 2)
    let lines = inspect(home, in: world).keyLines
    #expect(lines.contains("Stock: food 2/2"))
    #expect(lines.contains("Market: town center, 8 road tiles"))
}

@Test("scenario: A house out of reach names no market")
func houseOutOfReachNamesNoMarket() {
    var (world, _) = marketStrip()
    let home = placeOperational(.house, at: TileCoordinate(x: 40, y: 4), residents: 2, in: &world)
    let lines = inspect(home, in: world).keyLines
    #expect(!lines.contains { $0.hasPrefix("Market:") })
    #expect(lines.contains("Problem: No market in reach: build a marketplace near it"))
}

@Test("scenario: A town center names its reach and its porters")
func townCenterNamesItsReachAndPorters() {
    var (world, hub) = marketStrip()
    for index in 0 ..< 5 {
        placeOperational(.house, at: TileCoordinate(x: 4 + index * 3, y: 4), residents: 2, in: &world)
    }
    let home = EntityID(raw: world.nextEntityRaw - 1)
    world.porters = [Porter(id: EntityID(raw: 9999), hub: hub, house: home, path: [], basket: [])]
    let lines = inspect(hub, in: world).keyLines
    #expect(lines.contains("Serves: 5 houses within 18 road tiles"))
    #expect(lines.contains("Porters: 1 of 2 out"))
}

@Test("a hub under construction lists no market lines")
func hubUnderConstructionListsNoMarketLines() {
    var (world, hub) = marketStrip()
    world.buildings[hub]?.state = .constructing
    #expect(!inspect(hub, in: world).bullets.contains { $0.hasPrefix("Serves:") })
}

@Test("a hub serving one house says house")
func hubServingOneHouseSaysHouse() {
    var (world, hub) = marketStrip()
    placeOperational(.house, at: TileCoordinate(x: 3, y: 4), residents: 2, in: &world)
    let lines = inspect(hub, in: world).bullets
    #expect(lines.contains("Serves: 1 house within 18 road tiles"))
}
