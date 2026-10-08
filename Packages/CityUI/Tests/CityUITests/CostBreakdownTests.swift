import CityCore
import Foundation
import Testing
@testable import CityUI

// Tests for the ghost-preview cost breakdown added by
// `add-build-materials-cost` → M6. Scenarios under `Requirement: Ghost
// preview surfaces material cost` in
// openspec/changes/add-build-materials-cost/specs/rendering-2_5d/spec.md.

@MainActor
private func session(armed kind: BuildingKind) -> GameSession {
    let world = World.newGame()
    // Hover over a tile that's reliably on the single island so the
    // cost-breakdown's per-island lookup has materials to read. The
    // first grass tile is on the island silhouette by definition.
    let tile = world.firstTile(of: .grass) ?? TileCoordinate(x: 48, y: 48)
    let session = GameSession(world: world)
    session.selectTool(.place(kind))
    session.handleHover(at: tile)
    return session
}

@MainActor
@Test("scenario: ghost preview surfaces material cost when build tool is armed")
func scenarioGhostPreviewSurfacesMaterialCostWhenBuildToolIsArmed() throws {
    let session = session(armed: .sawmill)
    let ghost = try #require(session.ghostState())
    let breakdown = try #require(ghost.costBreakdown)
    #expect(breakdown[.wood]?.need == 4)
    #expect(breakdown[.planks]?.need == 1)
}

@MainActor
@Test("scenario: cost breakdown reads available stock from current island")
func scenarioCostBreakdownReadsAvailableStockFromCurrentIsland() throws {
    let session = session(armed: .sawmill)
    let ghost = try #require(session.ghostState())
    let breakdown = try #require(ghost.costBreakdown)
    // Fresh world: town center starter inventory is 6 wood + 5 planks.
    #expect(breakdown[.wood]?.have == 6)
    #expect(breakdown[.planks]?.have == 5)
}

@MainActor
@Test("scenario: shortfall good highlights red")
func scenarioShortfallGoodHighlightsRed() throws {
    // Town center has 5 planks. Warehouse needs 6 planks → planks
    // short by 1; its 2 wood are covered. The ghost-preview's
    // `shortfall(for:)` helper is what the view consults for the red
    // highlight.
    let session = session(armed: .warehouse)
    let ghost = try #require(session.ghostState())
    let breakdown = try #require(ghost.costBreakdown)
    #expect(breakdown[.planks]?.need == 6)
    #expect(breakdown[.planks]?.have == 5)
    #expect(GameSession.GhostPreview.isShort(.planks, in: breakdown))
    #expect(!GameSession.GhostPreview.isShort(.wood, in: breakdown))
}

@MainActor
@Test("scenario: free-of-materials tool has no cost row")
func scenarioFreeOfMaterialsToolHasNoCostRow() throws {
    let session = session(armed: .road)
    let ghost = try #require(session.ghostState())
    #expect(ghost.costBreakdown == nil, "road has no material cost → no breakdown")
}
