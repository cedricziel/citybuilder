import CityCore
import Foundation
import Testing
@testable import CityPersistence

// Scenarios from openspec/changes/add-orders (persistence-save-load / Saves
// before orders have none): orders are an additive field, so no version
// bump and no migration step.

private let v9Fixture = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Fixtures/saves/v9_single_island.json")

@Test("scenario: a save without orders loads empty")
func scenarioASaveWithoutOrdersLoadsEmptyFromAFixture() throws {
    let data = try Data(contentsOf: v9Fixture)
    let loaded: World = try SaveStore(baseDirectory: FileManager.default.temporaryDirectory).decode(data)
    #expect(loaded.orders == OrdersState())
    #expect(loaded.orders.orders.isEmpty && loaded.orders.shipments.isEmpty)
    #expect(loaded.orders.favour.crown == 0 && loaded.orders.fulfilledCount == 0)
}
