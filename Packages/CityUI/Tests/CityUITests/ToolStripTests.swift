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
    #expect(ToolStripText.hint(for: .place(.house), idiom: .phone) == "Tap or drag to place house")
    #expect(ToolStripText.hint(for: .demolish, idiom: .mac) == "Click a building to demolish")
}

@Test("scenario: Apple TV tool strip hints")
func scenarioAppleTVToolStripHints() {
    #expect(ToolStripText.hint(for: .place(.house), idiom: .tv) == "Move, then click to place house. Back to cancel.")
    #expect(ToolStripText.hint(for: .place(.road), idiom: .tv, paintingRoad: false) == "Click to start painting road")
}

@Test("Apple TV tool strip hints for painting and demolish")
func appleTVToolStripHintsForPaintingAndDemolish() {
    #expect(ToolStripText.hint(for: .place(.road), idiom: .tv, paintingRoad: true) == "Click to stop painting road")
    #expect(ToolStripText.hint(for: .demolish, idiom: .tv) == "Click a building to demolish")
    #expect(ToolStripText.hint(for: .place(.road), idiom: .pad) == "Tap or drag to place road")
}
