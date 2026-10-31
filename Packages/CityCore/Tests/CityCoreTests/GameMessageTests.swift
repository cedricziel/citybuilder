import Foundation
import Testing
@testable import CityCore

/// Spec: `localization` / The simulation core emits keys and arguments, not
/// sentences.
struct GameMessageTests {
    @Test("scenario: a history event carries its key and amount")
    func historyEventKeyAndAmount() throws {
        let message = HistoryEvent.bountifulHarvest.message
        #expect(message.key == "history.bountifulHarvest.text")
        #expect(message.args == ["food": .int(World.harvestFood)])

        var world = World.newGame()
        let store = try #require(world.goodsBuffers(of: .player).first { $0.state == .operational })
        let before = world.stockpiles[store.id]?.quantity(of: .food) ?? 0
        world.applyHistoryEvent(.bountifulHarvest)
        let added = (world.stockpiles[store.id]?.quantity(of: .food) ?? 0) - before
        #expect(message.args["food"] == .int(added))
    }

    @Test("every history event names its title and its amounts")
    func historyEventMessages() {
        #expect(HistoryEvent.allCases.map(\.titleKey) == [
            "history.bountifulHarvest.title", "history.tradeCaravan.title",
            "history.travellingScholar.title", "history.ratsInTheGranary.title"
        ])
        #expect(HistoryEvent.tradeCaravan.message == GameMessage(
            "history.tradeCaravan.text", ["payment": .money(World.caravanPayment)]
        ))
        #expect(HistoryEvent.travellingScholar.message == GameMessage(
            "history.travellingScholar.text", ["knowledge": .int(World.scholarKnowledge)]
        ))
        #expect(HistoryEvent.ratsInTheGranary.message == GameMessage("history.ratsInTheGranary.text"))
    }

    @Test("seasons, difficulties and scenarios name their keys")
    func enumKeys() {
        #expect(Season.allCases.map(\.nameKey) == ["season.spring", "season.summer", "season.autumn", "season.winter"])
        #expect(Difficulty.allCases.map(\.nameKey) == ["difficulty.easy", "difficulty.normal", "difficulty.hard"])
        #expect(Scenario.allCases.map(\.titleKey) == [
            "scenario.firstHarvest.title", "scenario.guildTown.title",
            "scenario.steamAndSmoke.title", "scenario.islandRivalry.title"
        ])
        #expect(Scenario.allCases.map(\.blurbKey) == [
            "scenario.firstHarvest.blurb", "scenario.guildTown.blurb",
            "scenario.steamAndSmoke.blurb", "scenario.islandRivalry.blurb"
        ])
    }

    /// The keys are computed, never stored: a world that ran through history
    /// events encodes without any of them, and reading every message along
    /// the way leaves it equal to an untouched twin. The determinism
    /// fixture's JSON was also compared before and after this change.
    @Test("scenario: keyed messages leave the simulation unchanged")
    func keyedMessagesLeaveSimulationUnchanged() throws {
        let seed = try #require((UInt64(0) ..< 500).first {
            World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: $0).historyEvent(forYear: 1201) == .tradeCaravan
        })
        var read = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: seed)
        read.calendar = CalendarState(startYear: 1200, isActive: true)
        var untouched = read
        var keys: [String] = []
        for _ in 0 ..< CalendarState.ticksPerYear * 3 {
            for case let .historyEvent(event) in read.tick().events {
                keys += [event.titleKey, event.message.key]
            }
            keys += [read.date.season.nameKey, read.difficulty.nameKey]
            _ = untouched.tick()
        }
        #expect(keys.contains { $0.hasPrefix("history.") })
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(read)
        #expect(try data == encoder.encode(untouched))
        let json = try #require(String(bytes: data, encoding: .utf8))
        #expect(!json.contains("history."))
        #expect(!json.contains("season."))
    }
}
