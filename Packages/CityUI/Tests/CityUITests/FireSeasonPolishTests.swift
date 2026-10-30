import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// Fixes from playtests/2026-10-29-fire-season.md (PR #301).

@MainActor
private func session(change: (inout World) -> Void = { _ in }) -> GameSession {
    var world = World.newGame(layout: .singleIsland, seed: 0, rivals: false, seasonalEvents: true)
    change(&world)
    return GameSession(world: world)
}

/// Moves the session's clock on by `ticks` and lets the banners catch up.
@MainActor
private func wait(_ session: GameSession, ticks: UInt64) {
    session.world.tickCount += ticks
    session.noteBannerEvents(in: [])
}

/// Lets the banner showing run out, so the next one in the queue shows.
@MainActor
func showNextBanner(_ session: GameSession) {
    wait(session, ticks: GameSession.bannerTicks + GameSession.bannerGapTicks)
}

private let warning = WorldEvent.seasonalEventWarned(event: .fire, onset: .autumn)

// MARK: - 1. One banner at a time

@MainActor
@Test("scenario: Two banners in one moment")
func secondBannerWaits() {
    let session = session()
    session.noteBannerEvents(in: [warning])
    session.noteBannerEvents(in: [.ageAdvanced(.renaissance)])
    #expect(session.banner?.title == "Dry autumn ahead")
    wait(session, ticks: GameSession.bannerTicks)
    // A short gap, so the two never draw at once.
    #expect(session.banner == nil)
    wait(session, ticks: GameSession.bannerGapTicks)
    #expect(session.banner?.title == "The Renaissance age begins")
}

@MainActor
@Test("scenario: a repeated banner shows once")
func repeatedBannerShowsOnce() {
    let session = session()
    session.noteBannerEvents(in: [warning, warning])
    session.noteBannerEvents(in: [warning])
    wait(session, ticks: GameSession.bannerTicks + GameSession.bannerGapTicks)
    #expect(session.banner == nil)
}

@MainActor
@Test("scenario: Fire! goes ahead of the queue, one for a burst of ignitions")
func fireGoesFirst() {
    let session = session()
    session.noteBannerEvents(in: [warning])
    session.noteBannerEvents(in: [.ageAdvanced(.renaissance)])
    session.noteBannerEvents(in: [
        .buildingCaughtFire(building: EntityID(raw: 900), kind: .farm),
        .buildingCaughtFire(building: EntityID(raw: 901), kind: .house)
    ])
    wait(session, ticks: GameSession.bannerTicks + GameSession.bannerGapTicks)
    #expect(session.banner?.title == "Fire!")
    #expect(session.banner?.description.hasPrefix("A house is burning.") == true)
    wait(session, ticks: GameSession.bannerTicks + GameSession.bannerGapTicks)
    #expect(session.banner?.title == "The Renaissance age begins")
}

// MARK: - 2. Banners leave a narrow column

@Test("scenario: a banner too narrow for its column spans the HUD")
func narrowColumnMovesTheBanner() {
    #expect(!SessionBannerLayout.fitsColumn(width: 110))
    #expect(SessionBannerLayout.fitsColumn(width: 300))
}

// MARK: - 3. The chip once a fire burns

@MainActor
@Test("scenario: The chip once the fire burns")
func chipOnceTheFireBurns() {
    let hud = HUDViewModel()
    var world = World.newGame()
    world.seasonalEvents.active = ActiveSeasonalEvent(event: .fire, startTick: 0, lastTick: 1199)
    hud.apply(world.snapshot())
    #expect(hud.eventChip?.text == "Fire season · Spring")
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw += 1
    world.buildings[id] = Building(id: id, kind: .farm, anchor: TileCoordinate(x: 2, y: 2), state: .burning)
    hud.apply(world.snapshot())
    #expect(hud.eventChip?.text == "Fire · 1 burning")
}

// MARK: - 4. What the fire watch does

/// A fire watch at (1, 2) with a road down to y = 3, along to x = 6, and a
/// house at (5, 1) on it; a second house at (9, 1) with no road.
private struct WatchFixture {
    let session: GameSession
    var onRoad = EntityID(raw: 0)
    var offRoad = EntityID(raw: 0)

    @MainActor
    init() {
        var world = World.newGame(layout: .singleIsland, seed: 0, rivals: false, seasonalEvents: true)
        func put(_ kind: BuildingKind, _ x: Int, _ y: Int) -> EntityID {
            let id = EntityID(raw: world.nextEntityRaw)
            world.nextEntityRaw += 1
            let anchor = TileCoordinate(x: x, y: y)
            let building = Building(id: id, kind: kind, anchor: anchor, state: .operational)
            world.buildings[id] = building
            for tile in building.footprint.tiles(anchor: anchor) {
                world.occupiedTiles[tile] = id
            }
            if kind == .road { world.roadGraph.addRoad(at: anchor) }
            return id
        }
        for x in 1 ... 6 {
            _ = put(.road, x, 3)
        }
        _ = put(.fireWatch, 1, 2)
        onRoad = put(.house, 5, 1)
        offRoad = put(.house, 9, 1)
        session = GameSession(world: world)
    }
}

@MainActor
@Test("scenario: the Fire! banner names the watch in reach")
func fireBannerNamesTheWatch() {
    let fixture = WatchFixture()
    let session = fixture.session
    session.noteBannerEvents(in: [.buildingCaughtFire(building: fixture.onRoad, kind: .house)])
    #expect(session.banner?.description == "A house is burning. A fire watch in reach sends its watchman to put it out.")
    showNextBanner(session)
    session.noteBannerEvents(in: [.buildingCaughtFire(building: fixture.offRoad, kind: .house)])
    #expect(session.banner?.description.hasPrefix("A house is burning. Without a fire watch in reach") == true)
}

@MainActor
@Test("scenario: A watch with one house on its road")
func fireWatchInspector() {
    let session = WatchFixture().session
    let tile = TileCoordinate(x: 1, y: 2)
    let model = InspectorViewModel.make(from: session.world.snapshot(), tile: tile, buildings: session.world.buildings)
    #expect(model.keyLines.contains("Covers 1 building within 8 tiles by road"))
    #expect(model.keyLines.contains("Watchman: at the watch"))
}

@Test func watchmanLines() {
    let walker = { (dousing: Bool) in
        WatchmanWalker(watch: EntityID(raw: 1), fire: EntityID(raw: 2), path: [], pathIndex: 0, isDousing: dousing)
    }
    #expect(InspectorViewModel.watchmanLine(walker(false), hasRoad: true) == "Watchman: walking to a fire")
    #expect(InspectorViewModel.watchmanLine(walker(true), hasRoad: true) == "Watchman: dousing a fire")
    #expect(InspectorViewModel.watchmanLine(nil, hasRoad: false) == "Watchman: can't leave: no road")
}

// MARK: - 5. Polish

@MainActor
@Test("scenario: ruins read as ruins, and the end banner names the button")
func ruinsPolish() {
    var world = World.newGame(layout: .singleIsland, seed: 0, rivals: false, seasonalEvents: true)
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw += 1
    let anchor = TileCoordinate(x: 2, y: 2)
    world.buildings[id] = Building(id: id, kind: .ruins, anchor: anchor, state: .operational, ruinOf: .house)
    world.occupiedTiles[anchor] = id
    let model = InspectorViewModel.make(from: world.snapshot(), tile: anchor, buildings: world.buildings)
    #expect(model.bullets.contains("State: ruins"))
    let session = GameSession(world: world)
    session.noteBannerEvents(in: [.seasonalEventEnded(event: .fire, toll: SeasonalEventToll(count: 2, fires: 2))])
    #expect(session.banner?.description == "2 buildings burnt down. Select the ruins and choose Clear ruins.")
}

@Test("scenario: the glyph-only chip is a 44-point tap target")
func glyphOnlyChipTapTarget() {
    #expect(EventChipLayout.minimumTapSide == 44)
}

// MARK: - Review of #309

@MainActor
@Test("scenario: a chip tap takes the banner slot at once")
func chipTapTakesTheSlot() {
    let session = session { world in
        world.seasonalEvents.warned = SeasonalEventOnset(event: .fire, season: .autumn)
    }
    session.noteBannerEvents(in: [.ageAdvanced(.renaissance)])
    session.replaySeasonalWarning()
    #expect(session.banner?.title == "Dry autumn ahead")
}

@MainActor
@Test("scenario: the chip replays the covered Fire! text")
func chipReplaysTheCoveredText() {
    let fixture = WatchFixture()
    let session = fixture.session
    session.world.buildings[fixture.onRoad]?.state = .burning
    session.world.seasonalEvents.active = ActiveSeasonalEvent(event: .fire, startTick: 0, lastTick: 1199)
    var fire = FireEventState(ignitionTicks: [])
    fire.fires = [Fire(building: fixture.onRoad, ignitionTick: 0)]
    session.world.seasonalEvents.fire = fire
    session.noteBannerEvents(in: [.buildingCaughtFire(building: fixture.onRoad, kind: .house)])
    let shown = session.banner
    session.replaySeasonalWarning()
    #expect(session.banner == shown)
    #expect(shown?.description.contains("sends its watchman") == true)
}

@MainActor
@Test("scenario: a stale order offer is dropped from the queue")
func staleOfferIsDropped() {
    let session = boardSession([order(1, offerEnds: 30)])
    session.noteBannerEvents(in: [.ageAdvanced(.renaissance)])
    session.noteBannerEvents(in: [.orderOffered(order: 1, issuer: .crown)])
    showNextBanner(session)
    #expect(session.banner == nil)
}

@MainActor
@Test("scenario: the queue keeps at most eight banners, urgent ones first")
func queueIsCapped() {
    let session = session()
    session.noteBannerEvents(in: [.ageAdvanced(.renaissance)])
    session.noteBannerEvents(in: [.buildingCaughtFire(building: EntityID(raw: 900), kind: .farm)])
    let distinct: [WorldEvent] = Age.allCases.map { .ageAdvanced($0) } + HistoryEvent.allCases.map { .historyEvent($0) } + [
        .monumentCompleted(building: EntityID(raw: 2)), .commissionEnded(building: EntityID(raw: 4)),
        .fuelRanOut(building: EntityID(raw: 3), kind: .steamEngine)
    ]
    session.noteBannerEvents(in: distinct)
    #expect(session.bannerQueue.count == GameSession.bannerQueueLimit)
    #expect(session.bannerQueue.first?.isUrgent == true)
}

// MARK: - CodeRabbit on #309

@MainActor
@Test("scenario: a Fire! in the same tick wins the free slot")
func fireWinsTheSameTick() {
    let session = session()
    session.noteBannerEvents(in: [.ageAdvanced(.renaissance), .buildingCaughtFire(building: EntityID(raw: 900), kind: .farm)])
    #expect(session.banner?.title == "Fire!")
}

@MainActor
@Test("scenario: the banner a chip tap interrupts comes back next")
func chipTapRequeuesTheInterrupted() {
    let session = session { world in
        world.seasonalEvents.warned = SeasonalEventOnset(event: .fire, season: .autumn)
    }
    session.noteBannerEvents(in: [.ageAdvanced(.renaissance)])
    session.replaySeasonalWarning()
    #expect(session.banner?.title == "Dry autumn ahead")
    showNextBanner(session)
    #expect(session.banner?.title == "The Renaissance age begins")
}

@Test("scenario: the wide banner clears the build controls and an open side drawer")
func wideBannerClearsTheControls() {
    #expect(SessionBannerLayout.bottomInset(controlsHeight: 180) == 188)
    #expect(SessionBannerLayout.showsWide(placement: .bottomDock, drawerOpen: true))
    #expect(!SessionBannerLayout.showsWide(placement: .leftRail, drawerOpen: true))
    #expect(SessionBannerLayout.showsWide(placement: .leftRail, drawerOpen: false))
}

@MainActor
@Test("scenario: with nothing selected the map shows the blight's marked area")
func mapShowsTheMarkedArea() {
    let session = session { world in
        world.seasonalEvents.warned = SeasonalEventOnset(event: .blight, season: .summer)
        world.seasonalEvents.marked = MarkedArea(around: TileBoundingBox(minX: 4, minY: 4, maxX: 5, maxY: 5), radius: 6)
    }
    #expect(session.areaOfEffect()?.style == .threat)
}
