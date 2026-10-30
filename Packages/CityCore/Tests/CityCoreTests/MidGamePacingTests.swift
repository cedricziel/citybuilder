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
/// PACING_DIFFICULTIES=normal (or a comma list) runs those difficulties only.
/// PACING_CAREFUL_ONLY=1 runs the careful order alone, for lever studies.
private let orders: [MidGameOrder] = ProcessInfo.processInfo.environment["PACING_CAREFUL_ONLY"] == "1"
    ? [.careful] : [.careful, .naive, .naiveFollowingHints]

/// PACING_ORDERS=1 adds an arm of each setup that also fills the crown's
/// orders (`OrdersKit`), next to the one that ignores them.
private let orderArms = ProcessInfo.processInfo.environment["PACING_ORDERS"] == "1" ? [false, true] : [false]

/// PACING_EVENTS=1 adds an arm of each setup with seasonal events on and the
/// `EventsKit` answering them (`add-event-counterplay` D12, bars 3 and 6).
private let eventArms = ProcessInfo.processInfo.environment["PACING_EVENTS"] == "1" ? [false, true] : [false]

/// "fire:2,blight:1,fever:0,festival:1": the events warned or requested.
private func eventCounts(_ counts: [SeasonalEffect: Int]) -> String {
    [SeasonalEffect.fire, .blight, .fever, .festival].map { "\($0):\(counts[$0, default: 0])" }.joined(separator: ",")
}

/// 20 years: every climb measured so far took under 15.
private let pacingTicks = 20 * Int(CalendarState.ticksPerYear)

@Test(
    "mid-game pacing across seeds",
    .enabled(if: isFullSweep, "set RIVAL_SWEEP=1"),
    arguments: Array(UInt64(0) ..< 10), [Difficulty.easy, .normal, .hard]
)
func midGamePacingAcrossSeeds(seed: UInt64, difficulty: Difficulty) {
    if let only = ProcessInfo.processInfo.environment["PACING_DIFFICULTIES"],
       !only.split(separator: ",").contains(Substring(difficulty.rawValue)) { return }
    for layout in [WorldLayout.singleIsland, .archipelago] {
        for market in markets {
            for order in orders {
                for useOrders in orderArms {
                    for events in eventArms {
                        let arm = MidGameArm(
                            layout: layout, difficulty: difficulty, tradesAtMarket: market, order: order, orders: useOrders, events: events
                        )
                        let run = World.midGameRun(arm, seed: seed, ticks: pacingTicks)
                        print(
                            "PACING_SWEEP seed=\(seed) difficulty=\(difficulty) layout=\(layout.rawValue) market=\(market) "
                                + "order=\(order) orders=\(run.orders.map { "\($0.accepted)/\($0.fulfilled)/\($0.failed)" } ?? "off") "
                                + "firstMerchant=\(MidGameMilestones.years(run.firstMerchant)) "
                                + "twentyMerchants=\(MidGameMilestones.years(run.twentyMerchants)) "
                                + "renaissance=\(MidGameMilestones.years(run.renaissance)) "
                                + "bankrupt=\(MidGameMilestones.years(run.bankruptAt)) "
                                + "merchantsAtTen=\(run.merchantsAtTen.map(String.init) ?? "-") "
                                + "heldShare=\(run.heldShare.map { String(format: "%.2f", $0) } ?? "-") "
                                + "hints=\(run.hinted.isEmpty ? "-" : run.hinted.map(\.rawValue).joined(separator: ","))"
                                + " events=\(run.events.map { eventCounts($0) + " festivalsHeld=\(run.festivalsHeld)" } ?? "off")"
                        )
                    }
                }
            }
        }
    }
}
