import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-event-counterplay (platform-shells /
// New Game offers seasonal events; Seasonal events show banners and a chip;
// Ruins inspector).

@MainActor
@Test("scenario: the events toggle reaches the world, default On")
func eventsToggleReachesTheWorld() throws {
    let dialog = NewGameDialogViewModel()
    #expect(dialog.seasonalEvents)
    #expect(try #require(dialog.commit()).seasonalEvents.enabled)
    dialog.seasonalEvents = false
    #expect(try #require(dialog.commit()).seasonalEvents.enabled == false)
    dialog.mode = .scenario
    dialog.seasonalEvents = true
    #expect(try #require(dialog.commit()).seasonalEvents.enabled)
    dialog.seasonalEvents = false
    dialog.cancel()
    #expect(dialog.seasonalEvents)
}

/// A new Normal game with seasonal events on, changed by `change`.
@MainActor
private func eventsSession(change: (inout World) -> Void = { _ in }) -> GameSession {
    var world = World.newGame(layout: .singleIsland, seed: 0, rivals: false, seasonalEvents: true)
    change(&world)
    return GameSession(world: world)
}

@MainActor
@Test("scenario: Fire warning text")
func fireWarningText() throws {
    let session = eventsSession()
    session.noteBannerEvents(in: [.seasonalEventWarned(event: .fire, onset: .summer)])
    let banner = try #require(session.banner)
    #expect(banner.title == "Dry summer ahead")
    let text = "Fire risk is high next season. A fire watch puts out fires within 8 tiles that its roads reach, "
        + "and a road between buildings stops the flames."
    #expect(banner.description == text)
}

@MainActor
@Test("scenario: an ignition names the building")
func ignitionBannerNamesTheBuilding() throws {
    let session = eventsSession()
    session.noteBannerEvents(in: [.buildingCaughtFire(building: EntityID(raw: 3), kind: .sawmill)])
    let banner = try #require(session.banner)
    #expect(banner.title == "Fire!")
    #expect(banner.description.hasPrefix("A sawmill is burning."))
}

@MainActor
@Test("scenario: the fire end banners")
func fireEndBanners() {
    let session = eventsSession()
    session.noteBannerEvents(in: [.seasonalEventEnded(event: .fire, toll: SeasonalEventToll(count: 2, fires: 3))])
    #expect(session.banner?.description == "2 buildings burnt down. Clear the ruins with Demolish.")
    session.noteBannerEvents(in: [.seasonalEventEnded(event: .fire, toll: SeasonalEventToll(count: 0, fires: 1))])
    #expect(session.banner?.description == "Nothing was lost.")
    session.noteBannerEvents(in: [.seasonalEventEnded(event: .fire, toll: SeasonalEventToll(count: 0, fires: 0))])
    #expect(session.banner?.title == "The dry spell is over")
}

@MainActor
@Test("scenario: Fever end text")
func feverEndText() throws {
    let session = eventsSession()
    session.noteBannerEvents(in: [.seasonalEventEnded(event: .fever, toll: SeasonalEventToll(count: 7))])
    let banner = try #require(session.banner)
    #expect(banner.title == "The fever has passed")
    #expect(banner.description == "7 residents left the town.")
}

@MainActor
@Test("scenario: a blight's onset names its end")
func blightOnsetNamesItsEnd() {
    let session = eventsSession { world in
        world.tickCount = 600
        world.seasonalEvents.active = ActiveSeasonalEvent(event: .blight, startTick: 600, lastTick: 1199)
    }
    session.noteBannerEvents(in: [.seasonalEventStarted(event: .blight)])
    #expect(session.banner?.description == "Fields in the marked area yield half until End of Summer 1200.")
}

@MainActor
@Test("scenario: clearing ruins without the money")
func clearingRuinsWithoutMoneyBanner() throws {
    let session = eventsSession { world in
        let id = EntityID(raw: world.nextEntityRaw)
        world.nextEntityRaw += 1
        world.buildings[id] = Building(id: id, kind: .ruins, anchor: TileCoordinate(x: 2, y: 2), state: .operational, ruinOf: .house)
    }
    let ruins = try #require(session.world.buildings.values.first { $0.kind == .ruins })
    session.noteBannerEvents(in: [.demolitionRejected(building: ruins.id, reason: .notEnoughMoney)])
    #expect(session.banner?.title == "Not enough money")
    #expect(session.banner?.description == "Clearing these ruins costs $15.")
}

@MainActor
@Test("scenario: Warning banner and chip")
func warningChipText() {
    let fire = EventChip(SeasonalEventOnset(event: .fire, season: .summer))
    #expect(fire.text == "Fire risk · Summer")
    #expect(EventChip(SeasonalEventOnset(event: .blight, season: .summer)).text == "Blight · Summer")
    #expect(EventChip(SeasonalEventOnset(event: .fever, season: .autumn)).text == "Fever · Autumn")
    #expect(EventChip(SeasonalEventOnset(event: .festival, season: .autumn)).text == "Festival · by Autumn")
    let hud = HUDViewModel()
    var world = World.newGame()
    world.seasonalEvents.warned = SeasonalEventOnset(event: .fire, season: .summer)
    hud.apply(world.snapshot())
    #expect(hud.eventChip == fire)
}

@MainActor
@Test("scenario: tapping the chip shows the warning again")
func chipReplaysTheWarning() {
    let session = eventsSession { world in
        world.seasonalEvents.warned = SeasonalEventOnset(event: .fire, season: .autumn)
    }
    #expect(session.banner == nil)
    session.replaySeasonalWarning()
    #expect(session.banner?.title == "Dry autumn ahead")
}

@Test("scenario: the chip doesn't crowd a 300-point HUD")
func chipFitsANarrowHUD() {
    #expect(EventChipLayout.showsText(hudWidth: 300) == false)
    #expect(EventChipLayout.showsText(hudWidth: 390))
    #expect(EventChipLayout.maxWidth(hudWidth: 300) <= 150)
}

@MainActor
@Test("scenario: Inspecting burnt house ruins")
func inspectingBurntHouseRuins() {
    var world = World.newGame(layout: .singleIsland, seed: 0, rivals: false)
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw += 1
    let anchor = TileCoordinate(x: 2, y: 2)
    // Burnt down in summer 1202, two years and a season after the start.
    let burnt = 2 * CalendarState.ticksPerYear + CalendarState.ticksPerSeason + 120
    world.buildings[id] = Building(id: id, kind: .ruins, anchor: anchor, state: .operational, ruinOf: .house, burntAtTick: burnt)
    world.occupiedTiles[anchor] = id
    world.tickCount = 3 * CalendarState.ticksPerYear
    world.economy.balance = 100
    let model = InspectorViewModel.make(from: world.snapshot(), tile: anchor, buildings: world.buildings)
    #expect(model.title == "Ruins of a house")
    #expect(model.keyLines.contains("Burnt down in Summer 1202"))
    #expect(model.demolish == DemolishButton(title: "Clear ruins — $15", isEnabled: true))
    world.economy.balance = 10
    let poor = InspectorViewModel.make(from: world.snapshot(), tile: anchor, buildings: world.buildings)
    #expect(poor.demolish?.isEnabled == false)
}

@MainActor
@Test("scenario: a burning building's demolish names its cost")
func burningBuildingDemolishNamesItsCost() {
    var world = World.newGame(layout: .singleIsland, seed: 0, rivals: false)
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw += 1
    let anchor = TileCoordinate(x: 2, y: 2)
    world.buildings[id] = Building(id: id, kind: .sawmill, anchor: anchor, state: .burning)
    world.occupiedTiles[anchor] = id
    let model = InspectorViewModel.make(from: world.snapshot(), tile: anchor, buildings: world.buildings)
    #expect(model.demolish?.title == "Pull down — $30")
    #expect(model.keyLines.contains("Burning"))
}
