import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// platform-shells / First-hour guide and Tool strip warns while the guide
// shows (openspec/changes/first-hour-guidance).

private let anchors = (0 ..< 8).map { TileCoordinate(x: 2 + ($0 % 4) * 4, y: 2 + ($0 / 4) * 4) }

/// A grass world with the player's operational `kinds`, one per anchor.
private func town(_ kinds: [BuildingKind], difficulty: Difficulty = .normal) -> World {
    var world = World.fixtureWithTerrain(width: 24, height: 24, fill: .grass, seed: 1)
    world.difficulty = difficulty
    for (kind, anchor) in zip(kinds, anchors) {
        let id = EntityID(raw: world.nextEntityRaw)
        world.nextEntityRaw &+= 1
        world.buildings[id] = Building(id: id, kind: kind, anchor: anchor, state: .operational)
        for tile in BuildingCatalog.spec(for: kind).footprint.tiles(anchor: anchor) {
            world.occupiedTiles[tile] = id
        }
        world.stockpiles[id] = World.stockpileCapacity(for: kind).map { Stockpile(capacity: $0) }
        if kind == .house {
            var residents = HousePopulation()
            residents.population = 6
            world.populations[id] = residents
        }
    }
    return world
}

private let everyStep: [BuildingKind] = [.farm, .lumberjackHut, .sawmill, .house, .house, .house]

@MainActor
private func metSteps(_ session: GameSession) -> [Bool] {
    session.firstStepsGuide?.steps.map(\.isMet) ?? []
}

@MainActor
@Test("scenario: guide shows on a new game")
func scenarioGuideShowsOnANewGame() throws {
    let session = GameSession(world: town([]))
    let guide = try #require(session.firstStepsGuide)
    #expect(guide.steps.map(\.title) == [
        "Build a farm", "Make planks: a lumberjack and a sawmill", "Build 3 houses on a road",
        "Earn more tax than upkeep", "Sell surplus at the market"
    ])
    #expect(metSteps(session) == [false, false, false, false, false])
    #expect(!session.isPaused)
    session.step()
    #expect(session.world.tickCount == 1)
}

@MainActor
@Test("scenario: farm step met by a farm")
func scenarioFarmStepMetByAFarm() throws {
    var world = town([.farm])
    let farm = try #require(world.buildings.values.first { $0.kind == .farm }?.id)
    world.buildings[farm]?.state = .constructing
    let session = GameSession(world: world)
    #expect(metSteps(session).first == false)
    session.world.buildings[farm]?.state = .operational
    session.refreshFirstSteps()
    #expect(metSteps(session).first == true)
}

@MainActor
@Test("scenario: planks step needs both buildings")
func scenarioPlanksStepNeedsBothBuildings() {
    #expect(metSteps(GameSession(world: town([.lumberjackHut])))[1] == false)
    #expect(metSteps(GameSession(world: town([.lumberjackHut, .sawmill])))[1] == true)
}

@MainActor
@Test("scenario: guide tracks the houses step")
func scenarioGuideTracksTheHousesStep() {
    #expect(metSteps(GameSession(world: town([.house, .house])))[2] == false)
    #expect(metSteps(GameSession(world: town([.house, .house, .house])))[2] == true)
}

@MainActor
@Test("scenario: tax step needs tax")
func scenarioTaxStepNeedsTax() throws {
    let empty = GameSession(world: town([]))
    #expect(empty.world.playerTaxAndUpkeep == (0, 0))
    #expect(metSteps(empty)[3] == false)
    let taxed = GameSession(world: town([.house]))
    try #require(taxed.world.playerTaxAndUpkeep.tax > 0)
    #expect(metSteps(taxed)[3] == true)
}

@MainActor
@Test("scenario: guide shows the ledger")
func scenarioGuideShowsTheLedger() throws {
    let ledger = FirstStepsLedger(tax: 12, upkeep: 36)
    #expect(ledger.net == -24)
    #expect(ledger.isNegative)
    #expect([ledger.tax, ledger.upkeep, ledger.net].map(FirstStepsLedger.money) == ["$12", "$36", "-$24"])
    let session = GameSession(world: town([.sawmill]))
    let guide = try #require(session.firstStepsGuide)
    let figures = session.world.playerTaxAndUpkeep
    #expect(guide.ledger == FirstStepsLedger(tax: figures.tax, upkeep: figures.upkeep))
}

@MainActor
@Test("scenario: market step met by a sale")
func scenarioMarketStepMetByASale() {
    let session = GameSession(world: town([]))
    #expect(metSteps(session)[4] == false)
    session.world.market.record(5, of: .planks, .sold)
    session.refreshFirstSteps()
    #expect(metSteps(session)[4] == true)
}

@MainActor
@Test("scenario: hiding the guide")
func scenarioHidingTheGuide() {
    let session = GameSession(world: town([]))
    session.hideFirstSteps()
    #expect(session.firstStepsGuide == nil)
    session.step()
    #expect(session.firstStepsGuide == nil)
}

@MainActor
@Test("scenario: guide leaves after year one")
func scenarioGuideLeavesAfterYearOne() {
    var world = town([])
    while world.tickCount < CalendarState.ticksPerYear - 1 {
        world.tick()
    }
    let session = GameSession(world: world)
    #expect(session.firstStepsGuide != nil)
    session.step()
    #expect(session.firstStepsGuide == nil)
}

@MainActor
@Test("scenario: guide leaves when every step is met")
func scenarioGuideLeavesWhenEveryStepIsMet() throws {
    var world = town(everyStep)
    world.market.record(5, of: .planks, .sold)
    let session = GameSession(world: world)
    try #require(session.world.playerTaxAndUpkeep.tax >= session.world.playerTaxAndUpkeep.upkeep)
    session.step()
    #expect(session.firstStepsGuide == nil)
    session.world.market = MarketLedger()
    session.refreshFirstSteps()
    #expect(session.firstStepsGuide == nil)
}

@MainActor
@Test("scenario: loaded save shows its steps")
func scenarioLoadedSaveShowsItsSteps() throws {
    let saved = try JSONEncoder().encode(town([.farm, .lumberjackHut, .sawmill]))
    let session = try GameSession(world: JSONDecoder().decode(World.self, from: saved))
    #expect(metSteps(session).prefix(2) == [true, true])
}

@MainActor
@Test("scenario: caption warns about food")
func scenarioCaptionWarnsAboutFood() {
    let session = GameSession(world: town([]))
    session.selectTool(.place(.house))
    #expect(session.armedGuideWarning == "No farm yet: residents need food")
    #expect(ToolStripText.hint(for: .place(.house), idiom: .pad, warning: session.armedGuideWarning)
        == "Tap or drag to place house · No farm yet: residents need food")
    let fed = GameSession(world: town([.farm]))
    fed.selectTool(.place(.house))
    #expect(fed.armedGuideWarning == nil)
}

@MainActor
@Test("scenario: caption names upkeep")
func scenarioCaptionNamesUpkeep() {
    let session = GameSession(world: town([], difficulty: .hard))
    session.selectTool(.place(.sawmill))
    let upkeep = Difficulty.hard.scaledUpkeep(BuildingCatalog.spec(for: .sawmill).upkeep)
    #expect(session.armedGuideWarning == "Upkeep $\(upkeep) per collection")
    session.selectTool(.place(.lumberjackHut))
    #expect(session.armedGuideWarning == nil)
}

@MainActor
@Test("scenario: caption unchanged without the guide")
func scenarioCaptionUnchangedWithoutTheGuide() {
    let session = GameSession(world: town([]))
    session.hideFirstSteps()
    session.selectTool(.place(.house))
    #expect(session.armedGuideWarning == nil)
    #expect(ToolStripText.hint(for: .place(.house), idiom: .pad, warning: nil) == "Tap or drag to place house")
}
