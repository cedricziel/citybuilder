import Foundation
@testable import CityCore

/// The PlayerBot's order kit (`add-orders` D11): accepts a crown order it
/// could fill, up to the open limit, and sends it once the stores hold the
/// goods. It ignores a rival's orders, which need a ship it has no route for.
///
/// "Could fill" is what the stores hold plus 1.5 times the town's recent
/// output of the good until the deadline, less what the houses used last
/// season. It also keeps back what the next house tier will need: a first merchant that waits on tools the crown
/// took is a town the orders held back (measured on archipelago seed 7).
struct OrdersKit {
    /// Share of the recent output the bot counts on, in percent.
    static let headroomPercent = 150

    private(set) var accepted = 0

    mutating func takeTurn(_ world: inout World) {
        var open = world.acceptedOrderCount
        for order in world.boardOrders where order.state == .offered && order.issuer == .crown {
            guard open < OrderRules.maxAccepted, Self.canFill(order, in: world) else { continue }
            world.enqueue(.acceptOrder(order.id))
            open += 1
            accepted += 1
        }
        for order in world.orders.orders where order.state == .accepted && order.issuer == .crown {
            if case .ready = world.orderDispatch(for: order.id), !Self.isSelling(order.good, in: world) {
                world.enqueue(.dispatchOrder(order.id))
            }
        }
    }

    /// The goods the first tier with no residents yet needs.
    static func reserved(in world: World) -> [Good] {
        HouseTier.allCases.first { world.residents(atLeast: $0) == 0 }?.needs ?? []
    }

    /// A market sale queued this turn spends the same stock, so the order waits.
    static func isSelling(_ good: Good, in world: World) -> Bool {
        world.pendingCommands.contains { command in
            if case let .marketSell(_, sold, _) = command { sold == good } else { false }
        }
    }

    /// Units of `good` the houses used in the last closed season: what the
    /// merchants and citizens already in town will want in the next one.
    static func consumption(of good: Good, in world: World) -> Int {
        world.statistics.seasons.last?.goods[good]?.usedByHouses ?? 0
    }

    static func canFill(_ order: Order, in world: World) -> Bool {
        guard !reserved(in: world).contains(order.good) else { return false }
        let closed = world.statistics.seasons.suffix(OrderRules.outputWindowSeasons)
        let perSeason = closed.isEmpty ? 0 : closed.reduce(0) { $0 + ($1.goods[order.good]?.made ?? 0) } / closed.count
        let seasonsLeft = Int((order.deadlineTick &- min(order.deadlineTick, world.tickCount)) / CalendarState.ticksPerSeason)
        return world.orderAvailable(for: order.id) + perSeason * seasonsLeft * headroomPercent / 100
            >= order.quantity + consumption(of: order.good, in: world)
    }

    /// What a run did with its orders.
    struct Result {
        var accepted = 0
        var fulfilled = 0
        var failed = 0

        init(_ kit: OrdersKit, _ world: World) {
            accepted = kit.accepted
            fulfilled = world.orders.fulfilledCount
            failed = world.orders.failedCount
        }
    }
}
