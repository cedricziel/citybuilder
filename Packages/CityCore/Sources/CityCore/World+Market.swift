import Foundation

/// What a town center's market can move right now: room to buy into and
/// goods on its island to sell. Spec: `platform-shells` / Town center
/// market panel (design D6).
public struct MarketReach: Equatable, Sendable {
    /// Free space across the operational player goods buffers on the
    /// town center's island: room a purchase can fill.
    public let freeSpace: Int
    /// Goods across the operational player goods buffers on its island.
    public let stock: [Good: Int]

    public init(freeSpace: Int, stock: [Good: Int]) {
        self.freeSpace = freeSpace
        self.stock = stock
    }
}

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

    /// True when `id` is an operational player town center, so it trades.
    func hasMarket(at id: EntityID) -> Bool {
        marketTownCenter(id) != nil
    }

    /// The reach of the market at `townCenter`; nil unless it is an
    /// operational player town center.
    func marketReach(at townCenter: EntityID) -> MarketReach? {
        guard let center = marketTownCenter(townCenter) else { return nil }
        var stock: [Good: Int] = [:]
        var freeSpace = 0
        for buffer in marketBuffers(of: center) {
            guard let pile = stockpiles[buffer.id] else { continue }
            for (good, amount) in pile.contents where amount > 0 {
                stock[good, default: 0] += amount
            }
            freeSpace += pile.freeSpace
        }
        return MarketReach(freeSpace: freeSpace, stock: stock)
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
        guard quantity > 0, let center = marketTownCenter(townCenter) else { return }
        let price = good.marketPrice(direction)
        let wanted = min(quantity, market.left(good, direction))
        let units = switch direction {
        case .bought:
            depositAffordable(good, upTo: wanted, at: price, into: purchaseBuffers(of: center))
        case .sold:
            drain(good, upTo: wanted, from: marketBuffers(of: center))
        }
        guard units > 0 else { return }
        let total = Int64(units) * price
        economy.credit(direction == .bought ? -total : total)
        market.record(units, of: good, direction)
        events.append(.marketTraded(good: good, quantity: units, total: total, direction: direction))
    }

    /// `id` when it is an operational player town center.
    private func marketTownCenter(_ id: EntityID) -> Building? {
        guard let center = buildings[id], center.kind == .townCenter, center.owner == .player,
              center.state == .operational
        else { return nil }
        return center
    }

    /// The operational player goods buffers on `center`'s island, lowest
    /// entity ID first: what the market sells from.
    private func marketBuffers(of center: Building) -> [Building] {
        let tileToIsland = tileToIslandMap()
        guard let island = tileToIsland[center.anchor] else { return [] }
        return goodsBuffers(of: .player).filter {
            $0.state == .operational && buildingIsOnIsland($0, islandID: island, tileToIsland: tileToIsland)
        }
    }

    /// The market buffers in the order a purchase fills them: the town
    /// center first, then the rest by entity ID (`market-buys-use-island-stores` D2).
    private func purchaseBuffers(of center: Building) -> [Building] {
        [center] + marketBuffers(of: center).filter { $0.id != center.id }
    }

    /// Puts as many of `amount` units into `buffers`, in order, as fit and
    /// the player's balance pays for at `price`.
    private mutating func depositAffordable(_ good: Good, upTo amount: Int, at price: Int64, into buffers: [Building]) -> Int {
        fill(good, upTo: min(amount, Self.unitsPaidFor(by: economy.balance, at: price)), into: buffers)
    }
}
