import SwiftUI
import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-calendar-and-events.

@MainActor
@Test("scenario: hud date text")
func scenarioHudDateText() {
    let base = World.newGame().snapshot()
    let snapshot = WorldSnapshot(
        tickCount: base.tickCount, simulatedTime: base.simulatedTime, mapWidth: base.mapWidth,
        mapHeight: base.mapHeight, terrainGrid: base.terrainGrid, occupiedTiles: base.occupiedTiles,
        buildings: base.buildings, carriers: base.carriers, economy: base.economy,
        totalPopulation: base.totalPopulation, camera: base.camera,
        date: GameDate(year: 1203, season: .autumn)
    )
    let hud = HUDViewModel()
    hud.apply(snapshot)
    #expect(hud.dateText == "Autumn 1203")
}

@MainActor
@Test("scenario: banner appears and expires")
func scenarioBannerAppearsAndExpires() throws {
    let seed = try #require((UInt64(0) ..< 500).first {
        World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: $0).historyEvent(forYear: 1201) == .tradeCaravan
    })
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: seed)
    world.calendar = CalendarState(startYear: 1200, isActive: true)
    for _ in 0 ..< 2399 {
        world.tick()
    }
    let session = GameSession(world: world)
    #expect(session.banner == nil)
    session.step()
    #expect(session.banner?.title == "Trade caravan")
    for _ in 0 ..< 59 {
        session.step()
    }
    #expect(session.banner?.title == "Trade caravan")
    session.step()
    #expect(session.banner == nil)
}

@MainActor
@Test("hud shows a moon at night and a sun at noon")
func hudShowsTimeOfDaySymbol() {
    #expect(HUDViewModel.symbol(for: TimeOfDay(tick: 780).phase) == "moon.stars.fill")
    #expect(HUDViewModel.symbol(for: TimeOfDay(tick: 180).phase) == "sun.max.fill")
}

@MainActor
@Test("scenario: the date chip shows a glyph for the season")
func hudShowsSeasonSymbol() {
    #expect(HUDViewModel.symbol(for: .autumn) == "leaf.fill")
    #expect(HUDViewModel.symbol(for: .winter) == "snowflake")
    #expect(Set(Season.allCases.map(HUDViewModel.symbol(for:))).count == 4)
}

@Test("scenario: the date chip yields when the row is tight")
func dateChipYieldsWhenTight() {
    let phone = HUDLayout.make(size: CGSize(width: 402, height: 874), idiom: .phone)
    let pad = HUDLayout.make(size: CGSize(width: 834, height: 1194), idiom: .pad)
    #expect(DateChipLayout.isShown(layout: phone, hudWidth: 386, showsFirstSteps: true, typeSize: .large))
    #expect(DateChipLayout.isShown(layout: phone, hudWidth: 386, showsFirstSteps: true, typeSize: .xxxLarge))
    // The pad's pill already carries the date.
    #expect(!DateChipLayout.isShown(layout: pad, hudWidth: 800, showsFirstSteps: true, typeSize: .large))
    // Large text: the chip goes first.
    #expect(!DateChipLayout.isShown(layout: phone, hudWidth: 386, showsFirstSteps: true, typeSize: .accessibility1))
    #expect(!DateChipLayout.isShown(layout: phone, hudWidth: 386, showsFirstSteps: false, typeSize: .accessibility5))
    // A narrow screen with the capsule beside it.
    #expect(!DateChipLayout.isShown(layout: phone, hudWidth: 300, showsFirstSteps: true, typeSize: .large))
    #expect(DateChipLayout.isShown(layout: phone, hudWidth: 300, showsFirstSteps: false, typeSize: .large))
}
