import CityCore
import Testing
@testable import CityUI

@Test("cost chip label spells out stock and need")
func costChipLabelSpellsOutStockAndNeed() {
    let label = ToolStripView.label(for: .planks, cost: GhostCost(need: 4, have: 1, status: .blocked))
    #expect(label == "Planks: 1 in store, 4 needed. Not enough")
}
