import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-event-counterplay (seasonal-events,
// difficulty-and-goals, persistence-save-load): the decision, the warning
// and the event's start and end. Fire, blight and fever effects have their
// own tests.

private let fireInSummer = SeasonalEventOnset(event: .fire, season: .summer)

/// A Normal world with ten houses, so fire and fever have their targets.
private func townWorld(seed: UInt64) -> World {
    var world = eventsWorld(seed: seed)
    addHouses(10, in: &world)
    return world
}

@Test("scenario: The catalog has four events")
func catalogHasFourEvents() {
    let events = SeasonalEvent.allCases
    #expect(events == [.fire, .blight, .fever, .festival])
    #expect(SeasonalEvent.fire.seasons == [.summer, .autumn])
    #expect(SeasonalEvent.blight.seasons == [.summer, .autumn])
    #expect(SeasonalEvent.fever.seasons == [.autumn, .winter])
    #expect(SeasonalEvent.festival.seasons == [.spring, .summer])
    let warning = SeasonalEvent.fire.banners[.warning]
    #expect(warning?.title == "Dry {season} ahead")
}

@Test("scenario: crop fields are marked in the game data")
func cropFieldsAreMarked() {
    let crops = BuildingKind.allCases.filter(\.isCrop)
    let expected: [BuildingKind] = [.farm, .grainFarm, .hopGarden, .vineyard, .teaGarden, .coffeeGrove]
    #expect(Set(crops) == Set(expected))
    #expect(BuildingKind.sheepFarm.isCrop == false)
}

@Test("scenario: Same seed, same events")
func sameSeedSameEvents() {
    let first = townWorld(seed: 42), second = townWorld(seed: 42)
    let years = Array(1202 ... 1260)
    let firstDraws = years.map { first.seasonalEvent(forYear: $0) }
    let secondDraws = years.map { second.seasonalEvent(forYear: $0) }
    #expect(firstDraws == secondDraws)
    let drawn = firstDraws.compactMap(\.self)
    #expect(!drawn.isEmpty)
}

@Test("scenario: No events in the first two years on Normal")
func noEventsInTheFirstTwoYears() {
    var world = townWorld(seed: 3)
    let events = runSeasons(&world, untilTick: firstTick(of: .spring, 1202) - 1)
    #expect(events.seasonalEvents.isEmpty)
    let draws = (UInt64(0) ..< 200).compactMap { eventsWorld(seed: $0, size: 1).seasonalEvent(forYear: 1201) }
    #expect(draws.isEmpty)
}

@Test("scenario: Easy starts events later")
func easyStartsEventsLater() {
    let draws = (UInt64(0) ..< 200).compactMap { seed -> SeasonalEventOnset? in
        let world = eventsWorld(seed: seed, difficulty: .easy, size: 1)
        return world.seasonalEvent(forYear: 1202)
    }
    #expect(draws.isEmpty)
    let later = (UInt64(0) ..< 200).compactMap { eventsWorld(seed: $0, difficulty: .easy, size: 1).seasonalEvent(forYear: 1203) }
    #expect(!later.isEmpty)
}

@Test("scenario: Fever waits for the Medieval age")
func feverWaitsForMedieval() {
    let world = eventsWorld(seed: 5, difficulty: .hard, age: .antiquity)
    let draws = (1202 ..< 1402).compactMap { world.seasonalEvent(forYear: $0)?.event }
    #expect(!draws.contains(.fever))
    #expect(draws.contains(.fire))
}

@Test("scenario: The world RNG is untouched")
func seasonalDecisionLeavesTheRNGAlone() throws {
    let seed = try #require(summerFireSeed)
    var world = townWorld(seed: seed)
    _ = runSeasons(&world, untilTick: firstTick(of: .spring, 1202) - 1)
    let before = world.rng
    let events = world.tick().events
    #expect(events.seasonalEvents == [.seasonalEventWarned(event: .fire, onset: .summer)])
    #expect(world.rng == before)
}

@Test("scenario: A summer fire is warned in spring")
func summerFireIsWarnedInSpring() throws {
    let seed = try #require(summerFireSeed)
    var world = townWorld(seed: seed)
    let spring = runSeasons(&world, untilTick: firstTick(of: .spring, 1202))
    #expect(spring.seasonalEvents == [.seasonalEventWarned(event: .fire, onset: .summer)])
    #expect(world.seasonalEvents.warned == fireInSummer)
    let summer = runSeasons(&world, untilTick: firstTick(of: .summer, 1202))
    #expect(summer.seasonalEvents == [.seasonalEventStarted(event: .fire)])
    #expect(world.seasonalEvents.active?.event == .fire)
}

@Test("scenario: Only stores, no fire")
func onlyStoresNoFire() throws {
    let setup = { (seed: UInt64) -> World in
        var world = eventsWorld(seed: seed)
        for index in 0 ..< 4 {
            addOperational(.warehouse, at: TileCoordinate(x: index * 4, y: 0), in: &world)
        }
        addOperational(.granary, at: TileCoordinate(x: 0, y: 5), in: &world)
        addOperational(.granary, at: TileCoordinate(x: 4, y: 5), in: &world)
        return world
    }
    let seed = try #require(summerFireSeed)
    var world = setup(seed)
    let events = runSeasons(&world, untilTick: firstTick(of: .winter, 1202))
    #expect(events.seasonalEvents.isEmpty)
    #expect(world.seasonalEvents.plan?.onset == nil)
}

@Test("scenario: No targets, no warning")
func noTargetsNoWarning() throws {
    // A town of only a farm and a warehouse has nothing a fire can start in.
    let seed = try #require(summerFireSeed)
    var world = eventsWorld(seed: seed)
    addOperational(.warehouse, at: TileCoordinate(x: 0, y: 0), in: &world)
    let events = runSeasons(&world, untilTick: firstTick(of: .winter, 1202))
    #expect(events.seasonalEvents.isEmpty)
    #expect(world.seasonalEvents.plan == SeasonalEventPlan(year: 1202, onset: nil))
}

@Test("scenario: A scheduled fire")
func scheduledFire() {
    var world = eventsWorld(seed: 9)
    world.seasonalEvents.enabled = false
    world.seasonalEvents.randomEvents = false
    world.seasonalEvents.schedule = [ScheduledSeasonalEvent(year: 1202, event: .fire, onset: .summer)]
    addOperational(.house, at: TileCoordinate(x: 0, y: 0), residents: 2, in: &world)
    addOperational(.warehouse, at: TileCoordinate(x: 5, y: 0), in: &world)
    let events = runSeasons(&world, untilTick: firstTick(of: .spring, 1202))
    #expect(events.seasonalEvents == [.seasonalEventWarned(event: .fire, onset: .summer)])
    let otherYears = (1200 ... 1300).filter { $0 != 1202 }.compactMap { world.seasonalEvent(forYear: $0) }
    #expect(otherYears.isEmpty)
}

@Test func fireLastsAtMostIntoTheNextSeason() {
    var world = eventsWorld(seed: 2)
    world.seasonalEvents.schedule = [ScheduledSeasonalEvent(year: 1201, event: .fire, onset: .summer)]
    addOperational(.house, at: TileCoordinate(x: 0, y: 0), residents: 2, in: &world)
    _ = runSeasons(&world, untilTick: firstTick(of: .summer, 1201))
    let lastTick = world.seasonalEvents.active?.lastTick
    #expect(lastTick == firstTick(of: .winter, 1201) - 1)
}

@Test("scenario: an event left open skips the next year's")
func openEventSkipsTheNextYear() {
    var world = townWorld(seed: 4)
    world.seasonalEvents.schedule = [
        ScheduledSeasonalEvent(year: 1201, event: .fever, onset: .winter),
        ScheduledSeasonalEvent(year: 1202, event: .fire, onset: .summer)
    ]
    _ = runSeasons(&world, untilTick: firstTick(of: .winter, 1201))
    // A hand-edited save: the fever runs past the end of the year.
    world.seasonalEvents.active = ActiveSeasonalEvent(event: .fever, startTick: world.tickCount, lastTick: .max)
    let events = runSeasons(&world, untilTick: firstTick(of: .spring, 1202))
    #expect(events.seasonalEvents.isEmpty)
    #expect(world.seasonalEvents.plan == SeasonalEventPlan(year: 1202, onset: nil))
}

@Test("scenario: No marketplace, no festival")
func noMarketplaceNoFestival() {
    var world = townWorld(seed: 4)
    world.seasonalEvents.schedule = [ScheduledSeasonalEvent(year: 1201, event: .festival, onset: .summer)]
    let events = runSeasons(&world, untilTick: firstTick(of: .autumn, 1201))
    #expect(events.seasonalEvents.isEmpty)
    #expect(world.seasonalEvents.plan?.onset == nil)
}

@Test func feverNeedsHousesWithResidents() {
    var world = eventsWorld(seed: 1)
    addHouses(6, residents: 0, in: &world)
    #expect(!world.hasSeasonalEventTargets(.fever, scheduled: false))
    addHouses(6, residents: 3, row: 5, in: &world)
    #expect(world.hasSeasonalEventTargets(.fever, scheduled: false))
}

@Test("scenario: The decision survives an age change and a reload")
func decisionSurvivesAgeChangeAndReload() throws {
    let fire = SeasonalEventOnset(event: .fire, season: .autumn)
    // Only fire is drawn for now (design D14), so a change the draw sees
    // stands in for the age: the difficulty's chance.
    let seed = try #require((0 ..< 3000 as Range<UInt64>).first { seed in
        let earlier = eventsWorld(seed: seed, size: 1)
        let later = eventsWorld(seed: seed, difficulty: .easy, size: 1)
        return earlier.seasonalEvent(forYear: 1203) == fire && later.seasonalEvent(forYear: 1203) != fire
    })
    var world = townWorld(seed: seed)
    _ = runSeasons(&world, untilTick: firstTick(of: .spring, 1203))
    world.difficulty = .easy
    world.age = .renaissance
    let saved = try JSONEncoder().encode(world)
    var loaded = try JSONDecoder().decode(World.self, from: saved)
    #expect(loaded == world)
    let events = runSeasons(&loaded, untilTick: firstTick(of: .summer, 1203))
    #expect(events.seasonalEvents == [.seasonalEventWarned(event: .fire, onset: .autumn)])
}

@Test("scenario: Events off changes nothing")
func eventsOffChangesNothing() throws {
    let setup = { (seed: UInt64) -> World in
        var world = townWorld(seed: seed)
        world.seasonalEvents.enabled = false
        return world
    }
    var world = try setup(#require(summerFireSeed))
    let events = runSeasons(&world, untilTick: firstTick(of: .spring, 1203))
    #expect(events.seasonalEvents.isEmpty)
    #expect(world.seasonalEvents == {
        var state = SeasonalEventsState()
        state.enabled = false
        return state
    }())
}

@Test("scenario: An old save loads without events")
func oldSaveLoadsWithoutEvents() throws {
    let world = townWorld(seed: 1)
    let encoded = try JSONEncoder().encode(world)
    var json = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    json.removeValue(forKey: "seasonalEvents")
    let old = try JSONSerialization.data(withJSONObject: json)
    let loaded = try JSONDecoder().decode(World.self, from: old)
    #expect(loaded.seasonalEvents == SeasonalEventsState())
    #expect(loaded.buildings == world.buildings)
}

@Test("scenario: new games take the events toggle")
func newGameTakesTheToggle() {
    let off = World.newGame(layout: .singleIsland, seed: 1, rivals: false)
    let on = World.newGame(layout: .singleIsland, seed: 1, rivals: false, seasonalEvents: true)
    #expect(!off.seasonalEvents.enabled)
    #expect(on.seasonalEvents.enabled)
}

@Test("scenario: difficulty shapes seasonal events")
func difficultyShapesSeasonalEvents() {
    let all = Difficulty.allCases
    #expect(all.map(\.seasonalEventChancePercent) == [35, 50, 65])
    #expect(all.map(\.firstSeasonalEventYear) == [4, 3, 3])
    #expect(all.map(\.firesPerFireEvent) == [1, 1, 2])
    #expect(all.map(\.fireSpreadTicks) == [200, 150, 100])
    #expect(all.map(\.feverLeaveTicks) == [300, 200, 150])
    #expect(all.map(\.festivalWindowSeasons) == [2, 1, 1])
    #expect(all.map(\.festivalTaxBonusPercent) == [15, 10, 10])
    #expect(SeasonalEvent.fire.weights == [.easy: 1, .normal: 1, .hard: 2])
    #expect(SeasonalEvent.festival.weights == [.easy: 3, .normal: 1, .hard: 1])
}

@Test func seasonalWorldEventsCompareAndSortAfterEntities() {
    let warned = WorldEvent.seasonalEventWarned(event: .fire, onset: .summer)
    let started = WorldEvent.seasonalEventStarted(event: .fire)
    let ended = WorldEvent.seasonalEventEnded(event: .fire, toll: SeasonalEventToll(count: 2))
    #expect(warned == .seasonalEventWarned(event: .fire, onset: .summer))
    #expect(warned != .seasonalEventWarned(event: .fire, onset: .autumn))
    #expect(started != .seasonalEventStarted(event: .blight))
    #expect(ended != .seasonalEventEnded(event: .fire, toll: SeasonalEventToll(count: 1)))
    let ordinals = [warned, started, ended].map(\.caseOrdinal)
    #expect(ordinals == [36, 37, 38])
    for event in [warned, started, ended] {
        #expect(event.primaryEntityID == nil)
        #expect(event.buildingKind == nil)
    }
}

@Test("scenario: events stay off while the calendar is inactive")
func eventsNeedAnActiveCalendar() {
    var world = townWorld(seed: 4)
    world.calendar = .inactive
    world.seasonalEvents.schedule = [ScheduledSeasonalEvent(year: 1201, event: .fire, onset: .summer)]
    let events = runSeasons(&world, untilTick: firstTick(of: .winter, 1201))
    #expect(events.seasonalEvents.isEmpty)
    #expect(world.seasonalEvents.plan == nil)
}

@Test("scenario: a chapter's event in its first year")
func scheduledEventInTheFirstYear() {
    var world = eventsWorld(seed: 9)
    world.seasonalEvents.schedule = [ScheduledSeasonalEvent(year: 1200, event: .fire, onset: .summer)]
    addOperational(.house, at: TileCoordinate(x: 0, y: 0), residents: 2, in: &world)
    let first = world.tick().events
    #expect(first.seasonalEvents == [.seasonalEventWarned(event: .fire, onset: .summer)])
    let summer = runSeasons(&world, untilTick: firstTick(of: .summer, 1200))
    #expect(summer.seasonalEvents == [.seasonalEventStarted(event: .fire)])
}

@Test("scenario: a scheduled event outside its seasons is dropped")
func scheduledEventOutsideItsSeasonsIsDropped() throws {
    var world = eventsWorld(seed: 9)
    let springFire = ScheduledSeasonalEvent(year: 1202, event: .fire, onset: .spring)
    let summerBlight = ScheduledSeasonalEvent(year: 1203, event: .blight, onset: .summer)
    world.seasonalEvents.schedule = [springFire, summerBlight]
    #expect(world.seasonalEvents.schedule == [summerBlight])
    // A save that holds one anyway loads without it.
    var state = SeasonalEventsState()
    state.schedule = [summerBlight]
    var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
    json["schedule"] = [["year": 1202, "event": "fire", "onset": 0], ["year": 1203, "event": "blight", "onset": 1]]
    let world2 = try JSONDecoder().decode(WorldStateBox.self, from: JSONSerialization.data(withJSONObject: ["state": json]))
    #expect(world2.state.schedule == [summerBlight])
}

/// Decodes a `SeasonalEventsState` through a keyed container, as `World` does.
private struct WorldStateBox: Decodable {
    let state: SeasonalEventsState
}

@Test("scenario: only enabled events are drawn")
func onlyEnabledEventsAreDrawn() {
    let draws = (UInt64(0) ..< 300).flatMap { seed in
        (1202 ... 1210).compactMap { eventsWorld(seed: seed, difficulty: .hard, size: 1).seasonalEvent(forYear: $0)?.event }
    }
    let disabled = draws.filter { !$0.isEnabled }
    let drawn = Set(draws)
    #expect(disabled.isEmpty)
    #expect(drawn == Set(SeasonalEvent.allCases))
}

@Test func blightAndFestivalTargets() {
    var world = eventsWorld(seed: 2)
    #expect(!world.hasSeasonalEventTargets(.blight, scheduled: true))
    addOperational(.farm, at: TileCoordinate(x: 0, y: 0), in: &world)
    #expect(world.hasSeasonalEventTargets(.blight, scheduled: true))
    #expect(!world.hasSeasonalEventTargets(.festival, scheduled: true))
}

@Test("scenario: Events off")
func eventsOffKeepsHistoryEvents() {
    var world = World.newGame(layout: .singleIsland, seed: 3, difficulty: .hard, rivals: false, seasonalEvents: false)
    let events = runSeasons(&world, untilTick: firstTick(of: .spring, 1210))
    let history = events.filter { if case .historyEvent = $0 { true } else { false } }
    #expect(events.seasonalEvents.isEmpty)
    #expect(!history.isEmpty)
}

@Test func scenarioGamesTakeTheToggle() {
    let world = World.newGame(layout: .singleIsland, seed: 1, culture: .northernEuropean, scenario: .firstHarvest, seasonalEvents: true)
    #expect(world.seasonalEvents.enabled)
}

@Test("scenario: the snapshot names the event warned or under way")
func snapshotNamesTheCurrentEvent() {
    var world = eventsWorld(seed: 9)
    world.seasonalEvents.schedule = [ScheduledSeasonalEvent(year: 1201, event: .fire, onset: .summer)]
    addOperational(.house, at: TileCoordinate(x: 0, y: 0), residents: 2, in: &world)
    #expect(world.snapshot().seasonalEvent == nil)
    _ = runSeasons(&world, untilTick: firstTick(of: .spring, 1201))
    let warned = SeasonalEventOnset(event: .fire, season: .summer)
    #expect(world.snapshot().seasonalEvent == warned)
    _ = runSeasons(&world, untilTick: firstTick(of: .summer, 1201))
    #expect(world.snapshot().seasonalEvent == warned)
}

@Test("scenario: a disabled pick is a quiet year, so fire keeps its rate")
func disabledPickIsAQuietYear() {
    // Normal, Medieval: half the years have an event, a quarter of those a fire.
    let draws = (UInt64(0) ..< 40).flatMap { seed in
        (1202 ..< 1302).map { eventsWorld(seed: seed, size: 1).seasonalEvent(forYear: $0)?.event }
    }
    let fires = draws.count { $0 == .fire }
    let disabled = draws.count { $0.map { !$0.isEnabled } ?? false }
    #expect(disabled == 0)
    #expect((400 ... 600).contains(fires), "\(fires) fires in 4000 years")
}

@Test("scenario: seed 42's fire years on Normal")
func seed42FireYears() {
    // Pinned: switching blight, fever or the festival on must not move these.
    let years = (1202 ..< 1262).filter { eventsWorld(seed: 42, size: 1).seasonalEvent(forYear: $0)?.event == .fire }
    #expect(years == [1203, 1211, 1232, 1238, 1251, 1252])
}
