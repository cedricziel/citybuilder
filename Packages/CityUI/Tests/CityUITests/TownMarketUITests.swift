import Testing
@testable import CityCore
@testable import CityUI

// platform-shells scenarios of openspec/changes/add-town-market (M3).

/// A new Normal game with $1,000 and the player's town center selected.
@MainActor
private func marketSession(_ change: (inout World, EntityID) -> Void = { _, _ in }) throws -> (GameSession, EntityID) {
    var world = World.newGame()
    world.economy.balance = 1000
    let center = try #require(world.goodsBuffers(of: .player).first { $0.kind == .townCenter })
    change(&world, center.id)
    let session = GameSession(world: world)
    session.selectedTile = center.anchor
    return (session, center.id)
}

@MainActor
private func row(_ good: Good, in session: GameSession) throws -> TownMarketSection.Row {
    let market = try #require(session.townMarket)
    return try #require((market.rows + market.otherRows).first { $0.good == good })
}

@MainActor
@Test("scenario: Town market rows")
func townMarketRows() throws {
    let (session, _) = try marketSession()
    let market = try #require(session.townMarket)
    #expect(market.rows.first?.text == "Wood — buy $6 (10 left) · sell $2 (20 left)")
    #expect(try row(.tools, in: session).text == "Tools — sell $15 (20 left)")
    #expect(Set((market.rows + market.otherRows).map(\.good)) == Set(session.world.marketQuotes.map(\.good)))
    #expect(market.rows.count + market.otherRows.count == session.world.marketQuotes.count)
}

@MainActor
@Test func buyStaysEnabledWithRoomForFewerThanFive() throws {
    for room in 1 ... 4 {
        let (session, _) = try marketSession { world, center in
            world.stockpiles[center] = Stockpile(capacity: room)
        }
        #expect(try row(.wood, in: session).canBuy, "room \(room)")
    }
}

@MainActor
@Test("scenario: Buy button enqueues a market command")
func buyButtonEnqueuesAMarketCommand() throws {
    let (session, center) = try marketSession()
    session.tradeAtMarket(.bought, .wood, 5)
    session.tradeAtMarket(.sold, .wood, 1)
    #expect(session.world.pendingCommands == [.marketBuy(center, .wood, 5), .marketSell(center, .wood, 1)])
}

@MainActor
@Test func tradingNeedsASelectedTownCenter() throws {
    let (session, _) = try marketSession()
    session.selectedTile = nil
    session.tradeAtMarket(.bought, .wood, 5)
    session.selectedTile = TileCoordinate(x: 0, y: 0)
    session.tradeAtMarket(.bought, .wood, 5)
    #expect(session.world.pendingCommands.isEmpty)
}

@MainActor
@Test("scenario: Buy disabled at the limit")
func buyDisabledAtTheLimit() throws {
    let (session, _) = try marketSession { world, _ in world.market.record(10, of: .wood, .bought) }
    #expect(try !row(.wood, in: session).canBuy)
    #expect(try row(.planks, in: session).canBuy)
}

@MainActor
@Test func buyDisabledWhenTheTownCenterIsFullOrMoneyShort() throws {
    let (full, _) = try marketSession { world, center in
        world.stockpiles[center] = Stockpile(capacity: 1)
        world.stockpiles[center]?.deposit(.tools, amount: 1)
    }
    #expect(try !row(.wood, in: full).canBuy)
    let (poor, _) = try marketSession { world, _ in world.economy.balance = 5 }
    #expect(try !row(.wood, in: poor).canBuy)
    #expect(try row(.food, in: poor).canBuy == false)
}

@MainActor
@Test("scenario: Sell disabled without stock")
func sellDisabledWithoutStock() throws {
    let (session, center) = try marketSession { world, center in
        world.stockpiles[center]?.deposit(.planks, amount: 1)
    }
    #expect(session.world.marketReach(at: center)?.stock[.iron] == nil)
    #expect(try !row(.iron, in: session).canSell)
    #expect(try row(.planks, in: session).canSell)
}

@MainActor
@Test("scenario: Market locked after game over")
func marketLockedAfterGameOver() throws {
    let (session, center) = try marketSession { world, center in
        world.economy.gameOver = true
        world.stockpiles[center]?.deposit(.planks, amount: 1)
    }
    let market = try #require(session.townMarket)
    #expect(market.rows.allSatisfy { !$0.canBuy && !$0.canSell })
    session.tradeAtMarket(.bought, .wood, 1)
    #expect(session.world.pendingCommands.isEmpty)
}

@MainActor
@Test("scenario: No market at a rival town center")
func noMarketAtARivalTownCenter() throws {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    world.economy.balance = 1000
    let rival = try #require(world.rival(1))
    let session = GameSession(world: world)
    session.selectedTile = try #require(world.buildings[rival.townCenterID]).anchor
    #expect(session.inspector.rival != nil)
    #expect(session.townMarket == nil)
    session.tradeAtMarket(.bought, .wood, 1)
    #expect(session.world.pendingCommands.isEmpty)
}

@MainActor
@Test func otherBuildingsHaveNoTownMarket() throws {
    let (session, _) = try marketSession()
    session.selectedTile = nil
    #expect(session.townMarket == nil)
}

@MainActor
@Test("scenario: Goods the island cannot use are collapsed")
func goodsTheIslandCannotUseAreCollapsed() throws {
    let (session, _) = try marketSession()
    let market = try #require(session.townMarket)
    let shown = market.rows.map(\.good)
    #expect(shown.contains(.wood), "goods the market sells are always shown")
    #expect(shown.contains(.tools) == false, "tools are neither held nor produced at the start")
    for good in [Good.wine, .tea, .coffee] {
        #expect(!shown.contains(good), "\(good) belongs under Other goods")
        #expect(market.otherRows.contains { $0.good == good })
    }
}

@MainActor
@Test("scenario: Goods the island holds are shown")
func goodsTheIslandHoldsAreShown() throws {
    let (session, _) = try marketSession { world, center in
        var pile = world.stockpiles[center] ?? Stockpile(capacity: 200)
        pile.deposit(.tools, amount: 3)
        world.stockpiles[center] = pile
    }
    let market = try #require(session.townMarket)
    #expect(market.rows.contains { $0.good == .tools })
    #expect(!market.otherRows.contains { $0.good == .tools })
}

@MainActor
@Test("The visible market rows keep catalog order")
func visibleRowsKeepCatalogOrder() throws {
    let (session, _) = try marketSession()
    let market = try #require(session.townMarket)
    let order = session.world.marketQuotes.map(\.good)
    let indices = market.rows.map { good in order.firstIndex(of: good.good) ?? -1 }
    #expect(indices == indices.sorted())
}
