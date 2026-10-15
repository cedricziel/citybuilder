import Foundation

/// Rivals at their own town center's market, as a safety valve.
/// Spec: `rival-towns` / Rival market trades (`rival-ai-viability` D5).
extension RivalAI {
    /// Below this treasury a rival sells surplus.
    static let debtThreshold: Int64 = 150
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
    /// unblock the step it would take, pay debts, or feed its houses.
    func rivalMarketCommands(turn: RivalTurn, plan: inout RivalTownPlan) -> [Command]? {
        let rival = turn.rival
        if let buys = unblockingBuys(turn: turn, plan: &plan) { return buys }
        if rival.treasury < RivalAI.debtThreshold {
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

    /// Buys for the step the rival would take when only wood or planks
    /// hold it back and the treasury covers the purchase and the step.
    private func unblockingBuys(turn: RivalTurn, plan: inout RivalTownPlan) -> [Command]? {
        let rival = turn.rival
        guard turn.waiting.isEmpty else { return nil }
        let kind = turn.thresholdKinds(pastOpening: rival.ai.isPastOpening).first
            ?? RivalAI.scriptKind(at: rival.ai.scriptIndex)
        let cost = materialCost(of: kind, for: rival.owner)
        guard !turn.canSupply(cost) else { return nil }
        var buys: [(Good, Int)] = []
        var price: Int64 = 0
        for good in Good.allCases {
            let missing = cost[good, default: 0] - turn.stock[good, default: 0]
            guard missing > 0 else { continue }
            guard good == .wood || good == .planks, rival.market.left(good, .bought) >= missing else { return nil }
            buys.append((good, missing))
            price += Int64(missing) * good.marketPrice(.bought)
        }
        // A purchase that cannot fit would fail and take every turn.
        guard !buys.isEmpty, buys.reduce(0, { $0 + $1.1 }) <= turn.centerFreeSpace,
              let slot = plan.slot(for: kind)
        else { return nil }
        let step = BuildingCatalog.spec(for: kind).cost
            + BuildingCatalog.spec(for: .road).cost * Int64(slot.roads.count)
            + RivalAI.safetyMargin + turn.reserve(before: kind)
        guard rival.treasury >= price + step else { return nil }
        return buys.map { .rivalMarketBuy(rival.id, $0.0, $0.1) }
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
