import Foundation
import Testing
@testable import CityCore

// Merchant trace (#402, `fix-merchant-churn` design "Diagnosis"): one careful
// mid-game bot game, Normal, single island, 12 years. Each season prints the
// merchants at its end and their range within it, the houses that moved up
// to and down from merchants, the needs that had run out for each decline,
// and the stock of each merchant need in the hubs and on the island.
// A measurement, not a gate: run it with MERCHANT_TRACE=1 (TRACE_SEED=n).

private let isTrace = ProcessInfo.processInfo.environment["MERCHANT_TRACE"] == "1"

/// One season's merchant moves.
private struct SeasonTally {
    var ups = 0
    var downs = 0
    var causes: [Good: Int] = [:]
    var lowest = Int.max
    var highest = 0

    /// Counts the player's houses that moved up to or down from merchants this tick.
    mutating func note(_ world: World, before: [EntityID: HousePopulation]) {
        for (id, pop) in world.populations where world.buildings[id]?.owner == .player {
            guard let old = before[id] else { continue }
            if pop.tier > old.tier, pop.tier == .merchants { ups += 1 }
            guard pop.tier < old.tier, old.tier == .merchants else { continue }
            downs += 1
            let grace = world.declineGrace(of: old.tier)
            let ranOut = world.bindingNeeds(of: old.tier, for: .player, advancing: false).filter { old.shortIntervals(of: $0) >= grace - 1 }
            for good in ranOut {
                causes[good, default: 0] += 1
            }
        }
        let merchants = world.residents(atLeast: .merchants)
        lowest = min(lowest, merchants)
        highest = max(highest, merchants)
    }

    func line(_ world: World, seed: UInt64, tick: Int, island: [Good: Int]) -> String {
        let watched: [Good] = [.food, .planks, .bread, .tools, world.culture.luxury, .cloth]
        let tiers = world.buildings.values.filter { $0.owner == .player && $0.kind == .house }.compactMap { world.populations[$0.id]?.tier }
        let hubs = world.buildings.values.filter { $0.owner == .player && $0.kind.hub != nil }
        let hubStock = watched.map { good in
            "\(good.rawValue)=\(hubs.reduce(0) { $0 + (world.stockpiles[$1.id]?.quantity(of: good) ?? 0) })"
        }
        let tierCounts = [HouseTier.peasants, .citizens, .merchants].map { tier in String(tiers.filter { $0 == tier }.count) }
        let year = String(format: "%.2f", Double(tick) / Double(CalendarState.ticksPerYear))
        return "MERCHANT_TRACE seed=\(seed) y=\(year) merchants=\(world.residents(atLeast: .merchants)) "
            + "range=\(lowest)-\(highest) houses=\(tiers.count) p/c/m=\(tierCounts.joined(separator: "/")) "
            + "up=\(ups) down=\(downs) causes=\(causes.map { "\($0.key.rawValue):\($0.value)" }.sorted().joined(separator: ",")) "
            + "hub[\(hubStock.joined(separator: ","))] "
            + "island[\(watched.map { "\($0.rawValue)=\(island[$0, default: 0])" }.joined(separator: ","))] age=\(world.age)"
    }
}

@Test("merchant trace per season", .enabled(if: isTrace, "set MERCHANT_TRACE=1"))
func merchantTracePerSeason() {
    let seed = UInt64(ProcessInfo.processInfo.environment["TRACE_SEED"] ?? "0") ?? 0
    var world = World.newGame(layout: .singleIsland, seed: seed, difficulty: .normal)
    world.calendar = CalendarState(startYear: 1200, isActive: true)
    guard let center = world.goodsBuffers(of: .player).first(where: { $0.kind == .townCenter }) else { return }
    var bot = PlayerBot(center: center, tradesAtMarket: true, firstSteps: PlayerBot.guideSteps, midGame: .careful)
    var tally = SeasonTally()
    for tick in 1 ... 12 * Int(CalendarState.ticksPerYear) {
        if tick.isMultiple(of: 50) { bot.takeTurn(&world) }
        let before = world.populations
        world.tick()
        tally.note(world, before: before)
        guard tick.isMultiple(of: Int(CalendarState.ticksPerSeason)) else { continue }
        let island = world.islandStockpile(at: center.anchor, tileToIsland: world.tileToIslandMap())
        print(tally.line(world, seed: seed, tick: tick, island: island))
        tally = SeasonTally()
    }
}
