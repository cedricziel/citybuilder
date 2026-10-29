import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/visible-distribution
// (buildings-and-construction / Marketplace).

@Test("scenario: Marketplace spec exposes its footprint and costs")
func marketplaceSpecExposesItsFootprintAndCosts() {
    let spec = BuildingCatalog.spec(for: .marketplace)
    #expect(spec.footprint == Footprint(width: 2, height: 2))
    #expect(spec.cost == 150)
    #expect(spec.upkeep == 1)
    #expect(spec.materialCost == [.wood: 3, .planks: 4])
    #expect(Tech.unlocking(.marketplace) == nil)
}

@Test("scenario: A marketplace is a hub")
func marketplaceIsAHub() {
    let hub = HubSpec(radius: 18, housesPerPorter: 4, maxPorters: 8, basketUnits: 10, reserveConsumptions: 2)
    #expect(BuildingKind.marketplace.hub == hub)
    #expect(BuildingKind.townCenter.hub == hub)
    #expect(BuildingKind.warehouse.hub == nil)
}

@Test func hubPortersGrowWithHousesUpToTheCap() {
    let hub = BuildingKind.marketplace.hub
    #expect(hub?.porters(serving: 0) == 1)
    #expect(hub?.porters(serving: 9) == 3)
    #expect(hub?.porters(serving: 100) == 8)
}

@Test("scenario: A finished marketplace stores goods")
func finishedMarketplaceStoresGoods() {
    var world = World.fixtureWithTerrain(width: 12, height: 6, fill: .grass, seed: 1)
    for x in 0 ... 9 {
        let tile = TileCoordinate(x: x, y: 2)
        SignatureFixture.inject(.road, at: tile, in: &world)
        world.roadGraph.addRoad(at: tile)
    }
    let market = addOperational(.marketplace, at: TileCoordinate(x: 4, y: 0), in: &world)
    let found = world.findRoadConnectedBuffer(fromRoad: TileCoordinate(x: 0, y: 2), good: .bread)
    #expect(found?.0 == market)
    #expect(world.stockpiles[market]?.room(for: .bread) == 30)
}

@Test func houseStockTunablesComeFromGameData() {
    #expect(LogisticsCatalog.houseStockConsumptions == 2)
    #expect(LogisticsCatalog.houseStockMinimum == 2)
}
