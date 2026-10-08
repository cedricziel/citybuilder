import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-culture-signatures: the
// caravanserai's export and caravans (milestone M3).

private typealias Fixture = SignatureFixture

@discardableResult
private func caravanserai(holding goods: [Good: Int], export: Good? = nil, in world: inout World) -> EntityID {
    let id = Fixture.inject(.caravanserai, at: TileCoordinate(x: 2, y: 2), in: &world)
    world.buildings[id]?.exportGood = export
    for good in Good.allCases {
        if let amount = goods[good] { world.stockpiles[id]?.deposit(good, amount: amount) }
    }
    return id
}

private func caravanEvent(_ events: [WorldEvent]) -> (goods: [Good: Int], revenue: Int64)? {
    events.lazy.compactMap { event -> (goods: [Good: Int], revenue: Int64)? in
        if case let .caravanSold(_, goods, revenue) = event { return (goods, revenue) }
        return nil
    }.first
}

/// Runs to the next tick whose count is a multiple of 100 and returns
/// its events.
private func caravanTick(_ world: inout World) -> [WorldEvent] {
    Fixture.runUntilBefore(multipleOf: 100, in: &world)
    return world.tick().events
}

// MARK: - Export good

@Test("scenario: export bread")
func scenarioExportBread() {
    var world = Fixture.grass()
    let id = caravanserai(holding: [:], in: &world)
    world.enqueue(.setExport(id, .bread))
    world.tick()
    #expect(world.buildings[id]?.exportGood == .bread)
    world.enqueue(.setExport(id, nil))
    world.tick()
    #expect(world.buildings[id]?.exportGood == nil)
}

@Test("scenario: no coffee exports")
func scenarioNoCoffeeExports() {
    var world = Fixture.grass()
    let id = caravanserai(holding: [:], export: .bread, in: &world)
    world.enqueue(.setExport(id, .coffee))
    world.tick()
    #expect(world.buildings[id]?.exportGood == .bread)
}

@Test("setExport is ignored for other kinds")
func setExportIgnoredForOtherKinds() {
    var world = Fixture.grass()
    let forum = Fixture.inject(.forum, at: TileCoordinate(x: 2, y: 2), in: &world)
    world.enqueue(.setExport(forum, .bread))
    world.tick()
    #expect(world.buildings[forum]?.exportGood == nil)
}

// MARK: - Export supply

/// A warehouse holding `food` food and a caravanserai exporting food,
/// on one road along y = 4.
private func exportStreet(food: Int) -> (world: World, caravanserai: EntityID) {
    var world = Fixture.grass()
    let warehouse = Fixture.inject(.warehouse, at: TileCoordinate(x: 0, y: 1), in: &world)
    world.stockpiles[warehouse]?.deposit(.food, amount: food)
    for x in 0 ... 20 {
        world.enqueue(.place(.road, at: TileCoordinate(x: x, y: 4)))
    }
    let id = Fixture.inject(.caravanserai, at: TileCoordinate(x: 8, y: 1), in: &world)
    world.buildings[id]?.exportGood = .food
    return (world, id)
}

private func foodHeadedTo(_ id: EntityID, in world: World) -> Int {
    world.carriers.values.count {
        if case let .retrieve(good, _, _, consumer) = $0.mission { return consumer == id && good == .food }
        return false
    }
}

@Test("scenario: reserve stays home")
func scenarioReserveStaysHome() {
    var (world, id) = exportStreet(food: 10)
    for _ in 0 ..< 90 {
        world.tick()
        #expect(foodHeadedTo(id, in: world) == 0)
    }
    #expect(world.stockpiles[id]?.quantity(of: .food) == 0)
}

@Test("supply carriers take only the surplus above the reserve")
func exportSupplyTakesTheSurplus() {
    var (world, id) = exportStreet(food: 12)
    _ = Fixture.run(&world, ticks: 90)
    #expect(world.stockpiles[id]?.quantity(of: .food) == 2)
}

@Test("export supply stops at 8 on hand or in flight")
func exportSupplyCap() {
    var (world, id) = exportStreet(food: 40)
    for _ in 0 ..< 90 {
        world.tick()
        let onHand = world.stockpiles[id]?.quantity(of: .food) ?? 0
        #expect(onHand + foodHeadedTo(id, in: world) <= 8)
    }
    #expect(world.stockpiles[id]?.quantity(of: .food) == 8)
}

// MARK: - Caravans

@Test("scenario: bread caravan")
func scenarioBreadCaravan() {
    var world = Fixture.grass()
    let id = caravanserai(holding: [.bread: 6], in: &world)
    let events = caravanTick(&world)
    #expect(world.stockpiles[id]?.quantity(of: .bread) == 2)
    #expect(events.contains(.caravanSold(building: id, goods: [.bread: 4], revenue: 48)))
    #expect(world.buildings[id]?.lastCaravan == CaravanSale(goods: [.bread: 4], revenue: 48))
}

@Test("scenario: coffee doubles the caravan")
func scenarioCoffeeDoublesTheCaravan() {
    var world = Fixture.grass()
    let id = caravanserai(holding: [.tools: 8, .coffee: 2], in: &world)
    let events = caravanTick(&world)
    #expect(world.stockpiles[id]?.quantity(of: .tools) == 0)
    #expect(world.stockpiles[id]?.quantity(of: .coffee) == 1)
    #expect(caravanEvent(events)?.revenue == 240)
}

@Test("scenario: leftovers after changing the export")
func scenarioLeftoversAfterChangingTheExport() {
    var world = Fixture.grass()
    let id = caravanserai(holding: [.tools: 1, .bread: 5], export: .tools, in: &world)
    let events = caravanTick(&world)
    #expect(caravanEvent(events)?.goods == [.tools: 1, .bread: 3])
    #expect(caravanEvent(events)?.revenue == 66)
    #expect(world.stockpiles[id]?.quantity(of: .bread) == 2)
}

@Test("a caravanserai holding only coffee sends no caravan")
func onlyCoffeeSendsNoCaravan() {
    var world = Fixture.grass()
    let id = caravanserai(holding: [.coffee: 3], in: &world)
    let events = caravanTick(&world)
    #expect(caravanEvent(events) == nil)
    #expect(world.stockpiles[id]?.quantity(of: .coffee) == 2)
}

@Test("scenario: caravan income is not tax")
func scenarioCaravanIncomeIsNotTax() {
    var world = Fixture.grass()
    caravanserai(holding: [.bread: 4], in: &world)
    Fixture.runUntilBefore(multipleOf: 100, in: &world)
    let before = world.economy.balance
    let events = world.tick().events
    #expect(world.tickCount.isMultiple(of: Economy.taxIntervalTicks))
    #expect(world.economy.balance == before + 46)
    #expect(!events.contains { if case .taxesCollected = $0 { true } else { false } })
}
