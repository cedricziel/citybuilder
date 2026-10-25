import Foundation
import Testing
@testable import CityCore

// Balance sweeps for orders (`add-orders` D11). Like the other sweeps they
// take minutes, so they run only with RIVAL_SWEEP=1, in the weekly
// `rival-sweep` workflow; each game prints a SOLVENCY_SWEEP line.

private let isFullSweep = ProcessInfo.processInfo.environment["RIVAL_SWEEP"] == "1"

@Test(
    "orders: market-trading towns that fill orders stay solvent across seeds",
    .enabled(if: isFullSweep, "set RIVAL_SWEEP=1"),
    arguments: Array(UInt64(0) ..< 10)
)
func scenarioOrderKitTownsStaySolventAcrossSeeds(seed: UInt64) {
    for layout in [WorldLayout.singleIsland, .archipelago] {
        let world = World.botGame(layout: layout, seed: seed, difficulty: .normal, tradesAtMarket: true, orders: true, ticks: 36000)
        let bankrupt = world.economy.gameOver
        print(
            "SOLVENCY_SWEEP seed=\(seed) layout=\(layout.rawValue) market=true orders=true bankrupt=\(bankrupt) "
                + "fulfilled=\(world.orders.fulfilledCount) failed=\(world.orders.failedCount)"
        )
        #expect(!bankrupt, "\(layout) seed \(seed)")
    }
}

@Test(
    "orders: guided Hard start that fills orders stays solvent and grows",
    .enabled(if: isFullSweep, "set RIVAL_SWEEP=1"),
    arguments: Array(UInt64(0) ..< 10)
)
func scenarioGuidedHardStartWithOrdersStaysSolventAndGrows(seed: UInt64) {
    for layout in [WorldLayout.singleIsland, .archipelago] {
        let world = World.botGame(
            layout: layout, seed: seed, difficulty: .hard, tradesAtMarket: true,
            firstSteps: PlayerBot.guideSteps, orders: true, ticks: 12000
        )
        let residents = world.population(of: .player)
        print(
            "GUIDE_SWEEP seed=\(seed) layout=\(layout.rawValue) orders=true bankrupt=\(world.economy.gameOver) "
                + "residents=\(residents) fulfilled=\(world.orders.fulfilledCount) failed=\(world.orders.failedCount)"
        )
        #expect(!world.economy.gameOver, "\(layout) seed \(seed)")
        #expect(residents >= 25, "\(layout) seed \(seed): \(residents) residents")
    }
}

/// The market control with the order kit on: over archipelago seeds 0 to
/// 29 on Normal, by tick 4,000 (one crown order is issued at tick 2,400),
/// towns that trade at the market go bankrupt no more often than the same
/// towns without it. Residents are printed, not asserted: a town that
/// keeps its planks for the crown can out-grow one that sells them, which
/// is orders giving surplus the purpose the market lost (#268).
@Test(
    "orders: the market does not make towns that fill orders worse off",
    .enabled(if: isFullSweep, "set RIVAL_SWEEP=1")
)
func scenarioTheMarketDoesNotMakeOrderTownsWorseOff() async {
    let without = await orderControlRuns(tradesAtMarket: false)
    let with = await orderControlRuns(tradesAtMarket: true)
    print(
        "SOLVENCY_SWEEP control orders=true seeds=0-29 layout=archipelago bankrupt_without=\(without.bankrupt) "
            + "bankrupt_with=\(with.bankrupt) residents_without=\(without.residents) residents_with=\(with.residents)"
    )
    #expect(with.bankrupt <= without.bankrupt)
}

private func orderControlRuns(tradesAtMarket: Bool) async -> (bankrupt: Int, residents: Int) {
    await withTaskGroup(of: (Bool, Int).self) { group in
        for seed in UInt64(0) ..< 30 {
            group.addTask {
                let world = World.botGame(
                    layout: .archipelago, seed: seed, difficulty: .normal,
                    tradesAtMarket: tradesAtMarket, orders: true, ticks: 4000
                )
                return (world.economy.gameOver, world.residents(atLeast: .peasants))
            }
        }
        return await group.reduce((bankrupt: 0, residents: 0)) { total, run in
            (total.bankrupt + (run.0 ? 1 : 0), total.residents + run.1)
        }
    }
}
