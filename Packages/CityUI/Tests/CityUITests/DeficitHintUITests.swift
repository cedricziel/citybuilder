import Testing
@testable import CityCore
@testable import CityUI

// platform-shells / Deficit hint (openspec/changes/deficit-hint).

/// A grass world with $1 and two sawmills' upkeep, so its first
/// collection, at tick 50, takes the treasury below zero.
@MainActor
private func townAboutToGoRed() -> GameSession {
    var world = World.fixtureWithTerrain(width: 20, height: 20, fill: .grass, seed: 1)
    for anchor in [TileCoordinate(x: 2, y: 2), TileCoordinate(x: 6, y: 2)] {
        let id = EntityID(raw: world.nextEntityRaw)
        world.nextEntityRaw &+= 1
        world.buildings[id] = Building(id: id, kind: .sawmill, anchor: anchor, state: .operational)
        for tile in BuildingCatalog.spec(for: .sawmill).footprint.tiles(anchor: anchor) {
            world.occupiedTiles[tile] = id
        }
        world.stockpiles[id] = World.newStockpile(for: .sawmill)
    }
    world.economy.balance = 1
    return GameSession(world: world)
}

/// `townAboutToGoRed` stepped to its first collection.
@MainActor
private func townInTheRed() -> GameSession {
    let session = townAboutToGoRed()
    while session.world.tickCount < Economy.taxIntervalTicks {
        session.step()
    }
    return session
}

@MainActor
private func showsDeficitHint(_ session: GameSession) -> Bool {
    session.banner?.title.hasPrefix("In the red") == true
}

@MainActor
@Test("scenario: deficit hint names the cause")
func scenarioDeficitHintNamesTheCause() {
    let session = townInTheRed()
    let figures = session.world.playerTaxAndUpkeep
    #expect(figures.upkeep > figures.tax)
    #expect(session.world.economy.balance < 0)
    #expect(session.banner?.title == "In the red: upkeep $\(figures.upkeep) vs tax $\(figures.tax)")
    #expect(session.banner?.description
        == "Residents pay tax only when fed. Build a farm, fill your houses, and sell surplus at the town center's market.")
}

@MainActor
@Test("scenario: deficit hint pauses until dismissed")
func scenarioDeficitHintPausesUntilDismissed() {
    let session = townInTheRed()
    let tick = session.world.tickCount
    for _ in 0 ..< 100 {
        session.step()
    }
    #expect(session.world.tickCount == tick)
    #expect(showsDeficitHint(session))
    #expect(!session.isPaused, "the hint pauses without the pause menu")
    session.dismissDeficitHint()
    session.step()
    #expect(session.world.tickCount == tick + 1)
    #expect(!showsDeficitHint(session))
}

@MainActor
@Test("the pause control and Esc dismiss the deficit hint")
func pauseControlAndEscDismissTheDeficitHint() {
    let toggled = townInTheRed()
    toggled.togglePause()
    #expect(!showsDeficitHint(toggled))
    #expect(!toggled.isPaused)
    let escaped = townInTheRed()
    var state = StepBackState()
    CityRootView.stepBack(session: escaped, state: &state)
    #expect(!showsDeficitHint(escaped))
    #expect(!escaped.isPaused)
}

@MainActor
@Test("scenario: deficit hint wins its tick")
func scenarioDeficitHintWinsItsTick() {
    let session = GameSession(world: World.newGame())
    session.noteBannerEvents(in: [.bankruptcyWarning(deficitTicks: 1), .historyEvent(.tradeCaravan)])
    #expect(showsDeficitHint(session))
}

@MainActor
@Test("scenario: deficit hint on loading a save in the red")
func scenarioDeficitHintOnLoadingASaveInTheRed() {
    var world = World.newGame()
    world.economy.balance = -5
    let session = GameSession(world: world)
    #expect(showsDeficitHint(session))
    let tick = session.world.tickCount
    session.step()
    #expect(session.world.tickCount == tick)
}

@MainActor
@Test("scenario: deficit hint shows once")
func scenarioDeficitHintShowsOnce() {
    let session = townInTheRed()
    session.dismissDeficitHint()
    session.noteBannerEvents(in: [.bankruptcyWarning(deficitTicks: 1)])
    #expect(!showsDeficitHint(session))
}
