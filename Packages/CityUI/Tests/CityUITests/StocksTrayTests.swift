import CityCore
import Foundation
import Testing
@testable import CityUI

// Scenarios from openspec/changes/redesign-hud-map-first/specs/platform-shells/spec.md.

@Test("scenario: island name toggles the stocks tray")
func scenarioIslandNameTogglesTheStocksTray() {
    let island = IslandSummary(
        id: 1,
        name: "Greenhold",
        bounds: TileBoundingBox(minX: 0, minY: 0, maxX: 4, maxY: 4),
        stockpile: [.wood: 12],
        capacity: [:]
    )
    let hud = HUDViewModel(currentIsland: island)
    #expect(hud.stocksTray.isEmpty)
    hud.toggleStocksTray()
    #expect(hud.stocksTray == [HUDGoodChip(good: .wood, count: 12)])
    hud.toggleStocksTray()
    #expect(hud.stocksTray.isEmpty)
}
