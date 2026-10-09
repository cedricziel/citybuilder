import CityCore
import Foundation
import Testing
@testable import CityUI

// Scenarios from openspec/changes/redesign-hud-map-first/specs/platform-shells/spec.md.

@MainActor
@Test("scenario: tool strip chips without hover")
func scenarioToolStripChipsWithoutHover() throws {
    let session = GameSession()
    session.selectTool(.place(.sawmill))
    #expect(session.hoveredTile == nil)
    let breakdown = try #require(session.armedCostBreakdown)
    #expect(breakdown[.wood] == GhostCost(need: 4, have: 6, status: .ok))
    #expect(breakdown[.planks] == GhostCost(need: 1, have: 5, status: .ok))
}

@Test("scenario: tool strip hint")
func scenarioToolStripHint() {
    #expect(ToolStripText.hint(for: .place(.house), touch: true) == "Tap or drag to place house")
    #expect(ToolStripText.hint(for: .demolish, touch: false) == "Click a building to demolish")
}
