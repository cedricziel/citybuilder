import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-event-counterplay (goods-and-production /
// Granaries are drawn from last): every draw takes from the other stores
// first and from a granary only when they hold none of the good.

/// The orders fixture with a granary beside the road, nearer the town
/// center than the warehouse.
private func granaryFixture(warehouseFood: Int, granaryFood: Int) -> (fixture: OrdersFixture, granary: EntityID) {
    var fixture = OrdersFixture()
    let granary = fixture.world.testPlace(.granary, at: TileCoordinate(x: 14, y: 11), owner: .player)
    fixture.setStock([.food: warehouseFood], in: fixture.warehouse)
    fixture.setStock([.food: granaryFood], in: granary)
    return (fixture, granary)
}

@Test("scenario: Houses eat from the warehouse first")
func storesBeforeTheGranary() {
    // Houses draw through their hub's restock, which picks its source like every supply carrier.
    let (fixture, _) = granaryFixture(warehouseFood: 3, granaryFood: 20)
    let source = fixture.world.nearestBuffer(holding: .food, toRoad: TileCoordinate(x: 13, y: 12))
    #expect(source?.0 == fixture.warehouse)
}

@Test("scenario: The granary feeds the town in a shortage")
func granaryInAShortage() {
    let (fixture, granary) = granaryFixture(warehouseFood: 0, granaryFood: 20)
    let source = fixture.world.nearestBuffer(holding: .food, toRoad: TileCoordinate(x: 13, y: 12))
    #expect(source?.0 == granary)
}

@Test("scenario: a market sale empties the other stores before the granary")
func marketSaleDrawsTheGranaryLast() {
    // A store built after the granary comes after it in entity order, yet is drawn first.
    var (fixture, granary) = granaryFixture(warehouseFood: 0, granaryFood: 20)
    let later = fixture.world.testPlace(.warehouse, at: TileCoordinate(x: 14, y: 18), owner: .player)
    fixture.setStock([.food: 3], in: later)
    fixture.world.enqueue(.marketSell(fixture.center, .food, 5))
    fixture.world.tick()
    #expect(fixture.stock(.food, in: later) == 0)
    #expect(fixture.stock(.food, in: granary) == 18)
}

@Test("scenario: an order ships from the warehouse before the granary")
func orderDrawsTheGranaryLast() {
    var (fixture, granary) = granaryFixture(warehouseFood: 6, granaryFood: 20)
    let id = fixture.world.testAddOrder(good: .food, quantity: 8, state: .accepted)
    guard case let .ready(plan) = fixture.world.orderDispatch(for: id) else {
        Issue.record("the order should be ready")
        return
    }
    let stores = plan.legs.map(\.store)
    #expect(stores == [fixture.warehouse, granary])
    #expect(plan.legs.map(\.amount) == [6, 2])
}
