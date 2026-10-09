import Foundation

/// Trades at a rival port. Spec: `rival-trade` / Trading at a rival
/// port (design D4).
extension World {
    /// A player ship's manifest action at rival `id`'s port: a load buys
    /// from the rival and an unload sells to it. Returns true when at
    /// least one unit changed hands; otherwise the ship waits as at a
    /// player port.
    mutating func applyTrade(
        _ action: ManifestAction,
        ship: inout Ship,
        rival id: RivalID,
        events: inout [WorldEvent]
    ) -> Bool {
        guard ship.owner == .player, !economy.gameOver, let rival = rival(id) else { return false }
        switch action {
        case let .loadUpTo(good, qty):
            return buy(good, upTo: qty, ship: &ship, from: rival, events: &events)
        case let .unloadUpTo(good, qty):
            return sell(good, upTo: qty, ship: &ship, to: rival, events: &events)
        }
    }

    /// Takes the units from the rival's buffers in ID order.
    private mutating func buy(
        _ good: Good,
        upTo qty: Int,
        ship: inout Ship,
        from rival: RivalTown,
        events: inout [WorldEvent]
    ) -> Bool {
        let limit = min(qty, ship.freeSpace, Self.unitsPaidFor(by: economy.balance, at: good.rivalPrice(.bought)))
        guard limit > 0 else { return false }
        let buffers = goodsBuffers(of: rival.owner)
        let held = buffers.reduce(0) { $0 + (stockpiles[$1.id]?.quantity(of: good) ?? 0) }
        let units = min(limit, RivalMarket.sellQuantity(of: good, stock: [good: held]))
        guard units > 0 else { return false }
        var left = units
        for buffer in buffers where left > 0 {
            left -= stockpiles[buffer.id]?.withdraw(good, amount: left) ?? 0
        }
        ship.cargo[good, default: 0] += units
        settle(good, units: units, rival: rival, direction: .bought, events: &events)
        return true
    }

    /// Puts the units in the rival's town center first, then its
    /// warehouses, then its port; ID order within a kind.
    private mutating func sell(
        _ good: Good,
        upTo qty: Int,
        ship: inout Ship,
        to rival: RivalTown,
        events: inout [WorldEvent]
    ) -> Bool {
        let carried = ship.cargo[good] ?? 0
        let limit = min(qty, carried, Self.unitsPaidFor(by: rival.treasury, at: good.rivalPrice(.sold)))
        guard limit > 0 else { return false }
        let buffers = goodsBuffers(of: rival.owner)
        let held = buffers.reduce(0) { $0 + (stockpiles[$1.id]?.quantity(of: good) ?? 0) }
        let order = [BuildingKind.townCenter, .warehouse, .port].flatMap { kind in
            buffers.filter { $0.kind == kind }.map(\.id)
        }
        let space = order.reduce(0) { $0 + (stockpiles[$1]?.freeSpace ?? 0) }
        let units = min(limit, RivalMarket.buyQuantity(of: good, stock: [good: held]), space)
        guard units > 0 else { return false }
        var left = units
        for buffer in order where left > 0 {
            left -= stockpiles[buffer]?.deposit(good, amount: left) ?? 0
        }
        ship.cargo[good] = carried == units ? nil : carried - units
        settle(good, units: units, rival: rival, direction: .sold, events: &events)
        return true
    }

    /// Whole units `purse` pays for at `price`; none when it is empty or
    /// in debt.
    private static func unitsPaidFor(by purse: Int64, at price: Int64) -> Int {
        purse > 0 ? Int(purse / price) : 0
    }

    /// Moves the money for `units` and reports the trade.
    private mutating func settle(
        _ good: Good,
        units: Int,
        rival: RivalTown,
        direction: TradeDirection,
        events: inout [WorldEvent]
    ) {
        let total = Int64(units) * good.rivalPrice(direction)
        let (payer, payee): (Owner, Owner) = direction == .bought ? (.player, rival.owner) : (rival.owner, .player)
        credit(-total, to: payer)
        credit(total, to: payee)
        events.append(.tradeCompleted(rival: rival.id, good: good, quantity: units, total: total, direction: direction))
    }
}
