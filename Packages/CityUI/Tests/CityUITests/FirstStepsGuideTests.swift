import Foundation
import SwiftUI
import Testing
@testable import CityCore
@testable import CityUI

// platform-shells / First-hour guide and Tool strip warns while the guide
// shows (openspec/changes/first-hour-guidance).

private let anchors = (0 ..< 8).map { TileCoordinate(x: 2 + ($0 % 4) * 4, y: 2 + ($0 / 4) * 4) }

/// A grass world with money and `owner`'s operational `kinds`, one per
/// anchor. Houses get residents.
private func town(_ kinds: [BuildingKind], difficulty: Difficulty = .normal, owner: Owner = .player) -> World {
    var world = World.fixtureWithTerrain(width: 30, height: 30, fill: .grass, seed: 1)
    world.difficulty = difficulty
    world.economy.credit(10000)
    for (kind, anchor) in zip(kinds, anchors) {
        insert(kind, at: anchor, owner: owner, in: &world)
    }
    return world
}

@discardableResult
private func insert(_ kind: BuildingKind, at anchor: TileCoordinate, owner: Owner = .player, in world: inout World) -> EntityID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.buildings[id] = Building(id: id, kind: kind, anchor: anchor, state: .operational, owner: owner)
    for tile in BuildingCatalog.spec(for: kind).footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    world.stockpiles[id] = World.stockpileCapacity(for: kind).map { Stockpile(capacity: $0) }
    if kind == .house {
        var residents = HousePopulation()
        residents.population = 6
        world.populations[id] = residents
    }
    return id
}

/// `count` houses in a row at y = 20 with a road along y = 22, placed
/// through the real road command; `owner` owns the houses.
private func addHousesOnRoad(_ count: Int, owner: Owner = .player, in world: inout World) {
    for index in 0 ..< count {
        insert(.house, at: TileCoordinate(x: 2 + index * 2, y: 20), owner: owner, in: &world)
    }
    for x in 2 ..< 2 + count * 2 {
        world.enqueue(.place(.road, at: TileCoordinate(x: x, y: 22)))
    }
    world.tick()
}

private let planksAndFarm: [BuildingKind] = [.farm, .lumberjackHut, .sawmill]

@MainActor
private func metSteps(_ session: GameSession) -> [Bool] {
    session.firstStepsGuide?.steps(idiom: .pad).map(\.isMet) ?? []
}

@MainActor
@Test("scenario: guide shows on a new game")
func scenarioGuideShowsOnANewGame() throws {
    let session = GameSession(world: town([]))
    let guide = try #require(session.firstStepsGuide)
    #expect(guide.steps(idiom: .pad).map(\.title) == [
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
    var two = town([])
    addHousesOnRoad(2, in: &two)
    #expect(metSteps(GameSession(world: two))[2] == false)
    var three = town([])
    addHousesOnRoad(3, in: &three)
    #expect(metSteps(GameSession(world: three))[2] == true)
}

@MainActor
@Test("scenario: houses off the road don't count")
func scenarioHousesOffTheRoadDontCount() {
    var world = town([])
    for index in 0 ..< 3 {
        world.enqueue(.place(.house, at: TileCoordinate(x: 2 + index * 3, y: 20)))
    }
    world.tick()
    let houses = world.buildings.values.filter { $0.kind == .house }
    #expect(houses.count == 3)
    // Finished as if their planks arrived; no road ever touches them.
    for house in houses {
        world.buildings[house.id]?.state = .operational
    }
    #expect(metSteps(GameSession(world: world))[2] == false)
}

@MainActor
@Test("scenario: rival buildings don't count")
func scenarioRivalBuildingsDontCount() {
    var world = town(planksAndFarm, owner: .rival(RivalID(1)))
    addHousesOnRoad(3, owner: .rival(RivalID(1)), in: &world)
    world.market = MarketLedger()
    #expect(metSteps(GameSession(world: world)) == [false, false, false, false, false])
}

@Test("scenario: tax step needs more tax than upkeep")
func scenarioTaxStepNeedsMoreTaxThanUpkeep() {
    let world = World.fixtureWithTerrain(width: 10, height: 10, fill: .grass, seed: 1)
    #expect(!FirstStepsGuide.steps(metIn: world, ledger: FirstStepsLedger(tax: 0, upkeep: 0)).contains(.tax))
    #expect(!FirstStepsGuide.steps(metIn: world, ledger: FirstStepsLedger(tax: 5, upkeep: 5)).contains(.tax))
    #expect(FirstStepsGuide.steps(metIn: world, ledger: FirstStepsLedger(tax: 6, upkeep: 5)).contains(.tax))
}

@MainActor
@Test("scenario: guide shows the ledger")
func scenarioGuideShowsTheLedger() throws {
    let ledger = FirstStepsLedger(tax: 12, upkeep: 36)
    #expect(ledger.net == -24)
    #expect(ledger.isNegative)
    #expect([ledger.tax, ledger.upkeep, ledger.net].map(FirstStepsLedger.money) == ["$12", "$36", "-$24"])
    #expect(FirstStepsLedger.spokenMoney(ledger.net) == "minus 24 dollars")
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
@Test("scenario: market step stays met after the season")
func scenarioMarketStepStaysMetAfterTheSeason() {
    let session = GameSession(world: town([]))
    session.world.market.record(5, of: .planks, .sold)
    session.refreshFirstSteps()
    while session.world.tickCount < CalendarState.ticksPerSeason {
        session.step()
    }
    #expect(session.world.market.sold.isEmpty)
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
@Test("scenario: guide stays past year one")
func scenarioGuideStaysPastYearOne() {
    let session = GameSession(world: town([]))
    while session.world.tickCount <= CalendarState.ticksPerYear {
        session.step()
    }
    #expect(session.firstStepsGuide != nil)
}

@MainActor
@Test("scenario: guide leaves when every step is met")
func scenarioGuideLeavesWhenEveryStepIsMet() throws {
    var world = town(planksAndFarm)
    addHousesOnRoad(3, in: &world)
    world.market.record(5, of: .planks, .sold)
    let session = GameSession(world: world)
    let figures = session.world.playerTaxAndUpkeep
    try #require(figures.tax > figures.upkeep)
    #expect(session.firstStepsGuide == nil)
    session.world.market = MarketLedger()
    session.step()
    #expect(session.firstStepsGuide == nil)
}

@MainActor
@Test("scenario: loaded save shows its steps")
func scenarioLoadedSaveShowsItsSteps() throws {
    let saved = try JSONEncoder().encode(town(planksAndFarm))
    let session = try GameSession(world: JSONDecoder().decode(World.self, from: saved))
    #expect(metSteps(session).prefix(2) == [true, true])
}

@Test("scenario: guide collapses on short screens")
func scenarioGuideCollapsesOnShortScreens() {
    let landscape = HUDLayout.make(size: CGSize(width: 844, height: 390), idiom: .phone)
    #expect(landscape.placement == .leftRail)
    #expect(landscape.collapsesFirstSteps)
    #expect(HUDLayout.make(size: CGSize(width: 390, height: 844), idiom: .phone).collapsesFirstSteps)
    #expect(!HUDLayout.make(size: CGSize(width: 1180, height: 820), idiom: .pad).collapsesFirstSteps)
    #expect(!HUDLayout.make(size: CGSize(width: 820, height: 1180), idiom: .pad).collapsesFirstSteps)
}

@Test("the expanded card narrows the stocks tray and the callout's free area")
func expandedCardNarrowsTrayAndFreeArea() {
    let size = CGSize(width: 1180, height: 820)
    let pad = HUDLayout.make(size: size, idiom: .pad)
    let tray = MinimapLayout.trayColumnWidth(hudWidth: 1100, layout: pad, showsMinimap: true)
    let trayWithCard = MinimapLayout.trayColumnWidth(hudWidth: 1100, layout: pad, showsMinimap: true, showsFirstSteps: true)
    #expect(tray - trayWithCard == FirstStepsCardView.width + 8)
    let insets = EdgeInsets()
    let free = InspectorCalloutLayout.freeArea(size: size, insets: insets, layout: pad, showsMinimap: true)
    let freeWithCard = InspectorCalloutLayout.freeArea(
        size: size, insets: insets, layout: pad, showsMinimap: true, showsFirstSteps: true
    )
    #expect(free.width - freeWithCard.width == FirstStepsCardView.width + MinimapLayout.gap)
    #expect(freeWithCard.minY == free.minY)
}

@Test("the collapsed capsule only lowers the callout's free area")
func collapsedCapsuleLowersFreeArea() {
    let size = CGSize(width: 844, height: 390)
    let phone = HUDLayout.make(size: size, idiom: .phone)
    let insets = EdgeInsets()
    let free = InspectorCalloutLayout.freeArea(size: size, insets: insets, layout: phone, showsMinimap: false)
    let freeWithCapsule = InspectorCalloutLayout.freeArea(
        size: size, insets: insets, layout: phone, showsMinimap: false, showsFirstSteps: true
    )
    #expect(freeWithCapsule.width == free.width)
    #expect(freeWithCapsule.minY == free.minY + FirstStepsCardView.capsuleHeight + MinimapLayout.gap)
    #expect(MinimapLayout.trayColumnWidth(hudWidth: 800, layout: phone, showsMinimap: false, showsFirstSteps: true)
        == MinimapLayout.trayColumnWidth(hudWidth: 800, layout: phone, showsMinimap: false))
}

@Test("the market step names each platform's gesture")
func marketStepNamesThePlatformGesture() {
    let guide = FirstStepsGuide(met: [], ledger: FirstStepsLedger(tax: 0, upkeep: 0))
    let reasons = [HUDIdiom.phone, .mac, .tv].map { guide.steps(idiom: $0)[4].reason }
    #expect(reasons == [
        "Tap the town center when cash runs low.", "Click the town center when cash runs low.",
        "Select the town center when cash runs low."
    ])
}

@MainActor
@Test("scenario: caption warns about food")
func scenarioCaptionWarnsAboutFood() throws {
    let session = GameSession(world: town([]))
    session.selectTool(.place(.house))
    #expect(session.armedGuideWarning(idiom: .pad) == "No farm yet: residents need food")
    #expect(ToolStripText.hint(for: .place(.house), idiom: .pad, warning: session.armedGuideWarning(idiom: .pad))
        == "Tap or drag to place house · No farm yet: residents need food")
    let fed = GameSession(world: town([.farm]))
    fed.selectTool(.place(.house))
    #expect(fed.armedGuideWarning(idiom: .pad) == nil)
    // The farm step stays met, but the warning follows the farms standing now.
    let farm = try #require(fed.world.buildings.values.first { $0.kind == .farm }?.id)
    fed.world.buildings[farm] = nil
    fed.refreshFirstSteps()
    #expect(fed.firstStepsGuide?.met.contains(.farm) == true)
    #expect(fed.armedGuideWarning(idiom: .pad) == "No farm yet: residents need food")
}

@MainActor
@Test("scenario: caption names upkeep")
func scenarioCaptionNamesUpkeep() {
    let session = GameSession(world: town([], difficulty: .hard))
    session.selectTool(.place(.sawmill))
    let upkeep = Difficulty.hard.scaledUpkeep(BuildingCatalog.spec(for: .sawmill).upkeep)
    #expect(session.armedGuideWarning(idiom: .mac) == "Upkeep \(FirstStepsLedger.money(upkeep)) per collection")
    session.selectTool(.place(.lumberjackHut))
    #expect(session.armedGuideWarning(idiom: .mac) == nil)
}

@MainActor
@Test("scenario: caption unchanged without the guide")
func scenarioCaptionUnchangedWithoutTheGuide() {
    let session = GameSession(world: town([]))
    session.hideFirstSteps()
    session.selectTool(.place(.house))
    #expect(session.armedGuideWarning(idiom: .pad) == nil)
    #expect(ToolStripText.hint(for: .place(.house), idiom: .pad, warning: nil) == "Tap or drag to place house")
}

@Test("test and shot launches start with the guide dismissed unless asked")
func uiTestLaunchesHideTheGuide() {
    #expect(!UITestSeed.hidesFirstSteps(fromArguments: []))
    #expect(UITestSeed.hidesFirstSteps(fromArguments: ["-uiTestSeedTown"]))
    #expect(!UITestSeed.hidesFirstSteps(fromArguments: ["-uiTestSeedTown", "-uiTestFirstSteps"]))
}
