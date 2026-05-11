import Foundation
import Testing
@testable import CityCore

// Tests for spec warehouses-and-logistics (M3 non-carrier scenarios only).
// Carrier scenarios land in M4.

@Test("scenario: warehouse accepts deposits")
func scenarioWarehouseAcceptsDeposits() {
    var stockpile = Stockpile(capacity: 50)
    let accepted = stockpile.deposit(.wood, amount: 10)
    #expect(accepted == 10)
    #expect(stockpile.quantity(of: .wood) == 10)
}

@Test("scenario: full warehouse rejects deposits")
func scenarioFullWarehouseRejectsDeposits() {
    var stockpile = Stockpile(capacity: 10)
    stockpile.deposit(.wood, amount: 10)
    let extra = stockpile.deposit(.wood, amount: 5)
    #expect(extra == 0, "deposits beyond capacity must report 0 accepted")
    #expect(stockpile.quantity(of: .wood) == 10)
}
