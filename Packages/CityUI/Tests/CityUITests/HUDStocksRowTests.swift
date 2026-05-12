import CityCore
import Foundation
import Testing
@testable import CityUI

// Tests for the HUD stocks-row chip filtering added by
// `add-island-hud-overlay` → M7. The SwiftUI rendering itself is
// covered downstream via preview/snapshot tests; here we verify the
// view-model's chip list.

private func summary(
    name: String = "Greenwood",
    stockpile: [Good: Int] = [:],
    capacity: [Good: Int] = [:]
) -> IslandSummary {
    IslandSummary(
        id: 1,
        name: name,
        bounds: TileBoundingBox(minX: 0, minY: 0, maxX: 4, maxY: 4),
        stockpile: stockpile,
        capacity: capacity
    )
}

@Test("scenario: stocks row shows goods present on the island")
func scenarioStocksRowShowsGoodsPresentOnTheIsland() {
    let hud = HUDViewModel(currentIsland: summary(stockpile: [.wood: 12, .planks: 4]))
    let chips = hud.stocksRow
    let dict = Dictionary(uniqueKeysWithValues: chips.map { ($0.good, $0.count) })
    #expect(dict[.wood] == 12)
    #expect(dict[.planks] == 4)
}

@Test("scenario: empty island hides the stocks row")
func scenarioEmptyIslandHidesTheStocksRow() {
    let hud = HUDViewModel(currentIsland: nil)
    #expect(hud.stocksRow.isEmpty)
}

@Test("scenario: goods with zero stock and zero capacity are omitted")
func scenarioGoodsWithZeroStockAndZeroCapacityAreOmitted() {
    let hud = HUDViewModel(currentIsland: summary(
        stockpile: [.wood: 5],
        capacity: [.wood: 100, .planks: 100]
    ))
    let chips = hud.stocksRow
    let goods = Set(chips.map(\.good))
    #expect(goods.contains(.wood))
    #expect(goods.contains(.planks))
    #expect(!goods.contains(.food), "food has zero stock and zero capacity — must be omitted")
}

@Test("scenario: stocks row includes goods with capacity but zero stock")
func scenarioStocksRowIncludesGoodsWithCapacityButZeroStock() {
    let hud = HUDViewModel(currentIsland: summary(
        stockpile: [:],
        capacity: [.wood: 200, .planks: 200, .food: 200]
    ))
    let chips = hud.stocksRow
    #expect(chips.count == 3)
    let countSum = chips.reduce(0) { $0 + $1.count }
    #expect(countSum == 0)
}

@Test("scenario: stocks row is sorted deterministically")
func scenarioStocksRowIsSortedDeterministically() {
    let hud = HUDViewModel(currentIsland: summary(
        stockpile: [.food: 1, .wood: 1, .planks: 1],
        capacity: [.food: 100, .wood: 100, .planks: 100]
    ))
    let firstChip = hud.stocksRow
    let secondChip = hud.stocksRow
    #expect(firstChip.map(\.good) == secondChip.map(\.good))
}

@Test("scenario: hud exposes island name for rendering")
func scenarioHUDExposesIslandNameForRendering() {
    let hud = HUDViewModel(currentIsland: summary(name: "Whaleback"))
    #expect(hud.currentIslandName == "Whaleback")
    let empty = HUDViewModel(currentIsland: nil)
    #expect(empty.currentIslandName == nil)
}
