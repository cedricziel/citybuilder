import Foundation
import Testing
@testable import CityCore

// Mid-game pacing (#186): years from a guided start to the first merchant,
// to 20 merchants and to the Renaissance, for the PlayerBot's mid-game kit
// in both build orders, at every difficulty, on both layouts, with and
// without the market. A measurement, not a balance gate: it prints one
// PACING_SWEEP line per game and runs only in the weekly `rival-sweep` job.
// The job runs the market arms; the no-market arms, which mostly never
// climb and so run all 20 years, run with PACING_FULL=1.

private let isFullSweep = ProcessInfo.processInfo.environment["RIVAL_SWEEP"] == "1"
private let markets = ProcessInfo.processInfo.environment["PACING_FULL"] == "1" ? [true, false] : [true]
/// PACING_CAREFUL_ONLY=1 runs the careful order alone, for lever studies.
private let orders: [MidGameOrder] = ProcessInfo.processInfo.environment["PACING_CAREFUL_ONLY"] == "1"
    ? [.careful] : [.careful, .naive]

/// 20 years: every climb measured so far took under 15.
private let pacingTicks = 20 * Int(CalendarState.ticksPerYear)

@Test(
    "mid-game pacing across seeds",
    .enabled(if: isFullSweep, "set RIVAL_SWEEP=1"),
    arguments: Array(UInt64(0) ..< 10), [Difficulty.easy, .normal, .hard]
)
func midGamePacingAcrossSeeds(seed: UInt64, difficulty: Difficulty) {
    for layout in [WorldLayout.singleIsland, .archipelago] {
        for market in markets {
            for order in orders {
                let arm = MidGameArm(layout: layout, difficulty: difficulty, tradesAtMarket: market, order: order)
                let run = World.midGameRun(arm, seed: seed, ticks: pacingTicks)
                print(
                    "PACING_SWEEP seed=\(seed) difficulty=\(difficulty) layout=\(layout.rawValue) market=\(market) "
                        + "order=\(order) firstMerchant=\(MidGameMilestones.years(run.firstMerchant)) "
                        + "twentyMerchants=\(MidGameMilestones.years(run.twentyMerchants)) "
                        + "renaissance=\(MidGameMilestones.years(run.renaissance)) "
                        + "bankrupt=\(MidGameMilestones.years(run.bankruptAt)) "
                        + "hints=\(run.hinted.isEmpty ? "-" : run.hinted.map(\.rawValue).joined(separator: ","))"
                )
            }
        }
    }
}
