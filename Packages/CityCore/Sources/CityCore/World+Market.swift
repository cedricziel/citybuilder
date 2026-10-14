import Foundation

/// The town center market. Spec: `town-market` (design D1, D4, D5).
public extension World {
    /// Every good the market trades, in catalog order.
    var marketQuotes: [MarketQuote] {
        Good.allCases.compactMap { good in
            let terms = good.marketTerms
            guard terms.buyLimit > 0 || terms.sellLimit > 0 else { return nil }
            return MarketQuote(
                good: good, buyPrice: good.marketPrice(.bought), sellPrice: good.marketPrice(.sold),
                buyLeft: market.left(good, .bought), sellLeft: market.left(good, .sold)
            )
        }
    }
}

extension World {
    /// Buys into or sells from the island of `townCenter`, an operational
    /// player town center, as much of `quantity` as the limit, money,
    /// space or stock allow. Moves nothing and reports nothing otherwise.
    mutating func applyMarketTrade(
        _ direction: TradeDirection,
        _ good: Good,
        _ quantity: Int,
        at townCenter: EntityID,
        events: inout [WorldEvent]
    ) {
        guard let center = buildings[townCenter], center.kind == .townCenter, center.owner == .player,
              center.state == .operational
        else { return }
        let price = good.marketPrice(direction)
        let wanted = min(quantity, market.left(good, direction))
        let units = switch direction {
        case .bought:
            depositAffordable(good, upTo: wanted, at: price, into: townCenter)
        case .sold:
            withdrawFromIsland(of: center, good, upTo: wanted)
        }
        guard units > 0 else { return }
        let total = Int64(units) * price
        economy.credit(direction == .bought ? -total : total)
        market.record(units, of: good, direction)
        events.append(.marketTraded(good: good, quantity: units, total: total, direction: direction))
    }

    /// Puts as many of `amount` units into `townCenter` as fit and the
    /// player's balance pays for at `price`.
    private mutating func depositAffordable(_ good: Good, upTo amount: Int, at price: Int64, into townCenter: EntityID) -> Int {
        let space = stockpiles[townCenter]?.freeSpace ?? 0
        let units = min(amount, space, Self.unitsPaidFor(by: economy.balance, at: price))
        return stockpiles[townCenter]?.deposit(good, amount: units) ?? 0
    }

    /// Takes up to `amount` of `good` from the operational player goods
    /// buffers on `center`'s island, lowest entity ID first.
    private mutating func withdrawFromIsland(of center: Building, _ good: Good, upTo amount: Int) -> Int {
        let tileToIsland = tileToIslandMap()
        guard let island = tileToIsland[center.anchor] else { return 0 }
        let buffers = goodsBuffers(of: .player).filter {
            $0.state == .operational && buildingIsOnIsland($0, islandID: island, tileToIsland: tileToIsland)
        }
        return drain(good, upTo: amount, from: buffers)
    }
}
