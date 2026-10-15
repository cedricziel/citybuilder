import Foundation

/// Rivals at their own town center's market, as a safety valve.
/// Spec: `rival-towns` / Rival market trades (`rival-ai-viability` D5).
extension RivalAI {
    /// Below this treasury a rival sells surplus.
    static let debtThreshold: Int64 = 150
    /// Below this much room the town center counts as full.
    static let fullStoreSpace = 4
    /// Units of a good a rival keeps when it sells.
    static let keepOnSale = 12
    /// A rival buys food only with at least this much money.
    static let feedThreshold: Int64 = 300
    static let feedUnits = 5
    /// Goods a rival in need sells, in this order.
    static let saleOrder: [Good] = [.planks, .wood, .food]
}

extension World {
    /// The trades a rival makes this turn instead of building, if any:
    /// pay debts, or feed its houses. Buying what a step lacks happens
    /// with the step itself (`shortfallBuys`).
    func rivalMarketCommands(turn: RivalTurn) -> [Command]? {
        let rival = turn.rival
        // A full town center takes no food from the farms, so a starving
        // town clears it like a debt is paid.
        let starvingAndFull = turn.centerFreeSpace < RivalAI.fullStoreSpace && turn.stock[.food, default: 0] < 4
        if rival.treasury < RivalAI.debtThreshold || starvingAndFull {
            for good in RivalAI.saleOrder {
                let units = min(turn.stock[good, default: 0] - RivalAI.keepOnSale, rival.market.left(good, .sold))
                if units > 0 { return [.rivalMarketSell(rival.id, good, units)] }
            }
        }
        if turn.stock[.food, default: 0] < 4, turn.hasHouseShortOfFood, rival.treasury >= RivalAI.feedThreshold {
            let units = min(RivalAI.feedUnits, rival.market.left(.food, .bought), turn.centerFreeSpace)
            if units > 0 { return [.rivalMarketBuy(rival.id, .food, units)] }
        }
        return nil
    }

    /// The wood and planks a step costing `cost` lacks, bought in the
    /// same batch as its placement so no carrier takes them first, and
    /// what they cost; nil when another good is missing, the season's
    /// limit is spent or the town center has no room for them.
    func shortfallBuys(_ cost: [Good: Int], turn: RivalTurn) -> (commands: [Command], price: Int64)? {
        let rival = turn.rival
        var commands: [Command] = []
        var price: Int64 = 0
        var units = 0
        for good in Good.allCases {
            let missing = cost[good, default: 0] - turn.stock[good, default: 0]
            guard missing > 0 else { continue }
            guard good == .wood || good == .planks, rival.market.left(good, .bought) >= missing else { return nil }
            commands.append(.rivalMarketBuy(rival.id, good, missing))
            price += Int64(missing) * good.marketPrice(.bought)
            units += missing
        }
        // A purchase that cannot fit would fail and take every turn.
        return units <= turn.centerFreeSpace ? (commands, price) : nil
    }

    /// Moves what the rival's limit, treasury, town center space or stock
    /// allow, at the player's market prices. No event: the player's
    /// market reports only the player's trades.
    mutating func applyRivalMarketTrade(_ direction: TradeDirection, _ good: Good, _ quantity: Int, for id: RivalID) {
        guard quantity > 0, let index = rivalIndex(id) else { return }
        let rival = rivals[index]
        guard let center = buildings[rival.townCenterID], center.owner == rival.owner,
              center.state == .operational
        else { return }
        let price = good.marketPrice(direction)
        let wanted = min(quantity, rival.market.left(good, direction))
        let space = stockpiles[center.id]?.freeSpace ?? 0
        let units = switch direction {
        case .bought:
            stockpiles[center.id]?.deposit(
                good, amount: min(wanted, space, Self.unitsPaidFor(by: rival.treasury, at: price))
            ) ?? 0
        case .sold:
            drain(good, upTo: wanted, from: goodsBuffers(of: rival.owner).filter { $0.state == .operational })
        }
        guard units > 0 else { return }
        let total = Int64(units) * price
        rivals[index].treasury += direction == .bought ? -total : total
        rivals[index].market.record(units, of: good, direction)
    }
}
