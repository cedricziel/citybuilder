import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/fix-early-game-edge-cases (platform-shells).

@MainActor
private func lostSession() -> GameSession {
    var world = World.newGame()
    world.economy.gameOver = true
    return GameSession(world: world)
}

@MainActor
@Test("scenario: bankruptcy banner stays up")
func scenarioBankruptcyBannerStaysUp() {
    let session = lostSession()
    for _ in 0 ... GameSession.bannerTicks {
        session.step()
    }
    let banner = session.banner
    #expect(banner?.title == "Bankrupt")
    #expect(banner?.description.contains("pause menu") == true)
    #expect(banner?.description.contains("title") == true)
}

@MainActor
@Test("scenario: build tools stay off after game over")
func scenarioBuildToolsStayOffAfterGameOver() throws {
    let session = lostSession()
    session.selectTool(.place(.road))
    #expect(session.selectedTool == .inspect)
    session.selectedTool = .demolish
    let center = try #require(session.world.goodsBuffers(of: .player).first).anchor
    session.handleTap(at: center)
    session.handleDrag(at: center)
    session.handleLongPress(at: center)
    #expect(session.world.pendingCommands.isEmpty)
    #expect(session.tileMenuRequest == nil)
}

@MainActor
@Test("scenario: game over disarms the armed tool")
func scenarioGameOverDisarmsTheArmedTool() throws {
    var world = World.newGame()
    world.economy.balance = -1
    world.economy.bankruptcyDeficitTicks = world.difficulty.bankruptcyGraceTicks - 1
    let session = GameSession(world: world)
    session.confirmsBuildingPlacement = true
    session.selectTool(.place(.sawmill))
    let center = try #require(session.world.goodsBuffers(of: .player).first).anchor
    session.handleTap(at: TileCoordinate(x: center.x + 4, y: center.y + 4))
    #expect(session.pendingPlacement != nil)
    session.step()
    #expect(session.world.economy.gameOver)
    #expect(session.selectedTool == .inspect)
    #expect(session.pendingPlacement == nil)
}

@MainActor
@Test("scenario: research is off after game over")
func scenarioResearchIsOffAfterGameOver() {
    let session = lostSession()
    #expect(!session.isResearchAvailable)
    session.chooseResearch(.milling)
    #expect(session.world.pendingCommands.isEmpty)
}
