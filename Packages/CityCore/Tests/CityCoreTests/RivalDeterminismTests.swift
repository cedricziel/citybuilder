import Foundation
import Testing
@testable import CityCore

// simulation-core scenarios of add-rival-towns, plus the tick budget
// with three rivals (tasks 2.3).

private func hardWorld() -> World {
    World.newGame(layout: .archipelago, seed: 42, difficulty: .hard)
}

/// Runs `ticks` ticks and returns the slowest and the mean tick time.
private func timedRun(_ world: inout World, ticks: Int) -> (max: UInt64, mean: UInt64) {
    var slowest: UInt64 = 0
    var total: UInt64 = 0
    for _ in 0 ..< ticks {
        let nanos = world.tick().metrics.wallClockNanoseconds
        slowest = max(slowest, nanos)
        total += nanos
    }
    return (slowest, total / UInt64(ticks))
}

@Test("scenario: replayed rival game")
func scenarioReplayedRivalGame() {
    var first = hardWorld()
    var second = hardWorld()
    let timing = timedRun(&first, ticks: 3000)
    _ = timedRun(&second, ticks: 3000)
    #expect(first == second)
    for rival in first.rivals {
        #expect(first.buildings.values.count { $0.owner == rival.owner } > 1, "rival \(rival.id) built nothing")
    }
    // The 10 Hz budget with three rivals on Hard: the mean tick stays
    // under 100 ms and no tick reaches a second. The mean, not the
    // slowest tick, carries the budget: the suite runs tests in parallel.
    #expect(timing.mean < 100_000_000, "mean tick took \(timing.mean) ns")
    #expect(timing.max < 1_000_000_000, "slowest tick took \(timing.max) ns")
}

@Test("scenario: save between decision and application")
func scenarioSaveBetweenDecisionAndApplication() throws {
    var world = hardWorld()
    _ = world.testRun(ticks: 30)
    #expect(world.pendingCommands.contains { if case .rivalPlace = $0 { true } else { false } })
    var copy = try JSONDecoder().decode(World.self, from: JSONEncoder().encode(world))
    #expect(copy == world)
    _ = world.testRun(ticks: 100)
    _ = copy.testRun(ticks: 100)
    #expect(copy == world)
}

@Test("goods never cross owners")
func goodsNeverCrossOwners() {
    var world = hardWorld()
    for _ in 0 ..< 1500 {
        world.tick()
        for carrier in world.carriers.values {
            let (from, to): (EntityID, EntityID) = switch carrier.mission {
            case let .deliver(_, _, producer, warehouse): (producer, warehouse)
            case let .retrieve(_, _, warehouse, consumer): (warehouse, consumer)
            case let .deliverToConstructionSite(_, _, producer, site): (producer, site)
            }
            #expect(world.owner(of: from) == world.owner(of: to))
        }
    }
}
