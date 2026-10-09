import Foundation

/// Rival prices and offers. Spec: `rival-trade` / Base prices, Rival
/// offers (design D2, D3).
public extension Good {
    /// What a rival charges the player: 125% of base, rounded down, at
    /// least $1.
    var rivalSellPrice: Int64 {
        max(1, basePrice * 5 / 4)
    }

    /// What a rival pays the player: 75% of base, rounded down, at
    /// least $1.
    var rivalBuyPrice: Int64 {
        max(1, basePrice * 3 / 4)
    }
}

/// One line of a rival's market: a good, how many units and the unit
/// price.
public struct RivalOffer: Hashable, Sendable {
    public let good: Good
    public let quantity: Int
    public let price: Int64

    public init(good: Good, quantity: Int, price: Int64) {
        self.good = good
        self.quantity = quantity
        self.price = price
    }
}

/// Offers derived from a stock; never stored (design D3).
public enum RivalMarket {
    /// Units of each good a rival keeps; it sells the rest.
    public static let sellReserve = 30
    /// Stock a rival buys the `boughtGoods` up to.
    public static let buyTarget = 20
    /// Goods a rival buys; bread and tools are what its houses need to
    /// become merchants.
    public static let boughtGoods: Set<Good> = [.wood, .planks, .food, .bread, .tools]

    /// Every good above the reserve, in catalog order.
    public static func sellOffers(stock: [Good: Int]) -> [RivalOffer] {
        Good.allCases.compactMap { good in
            let surplus = stock[good, default: 0] - sellReserve
            return surplus > 0 ? RivalOffer(good: good, quantity: surplus, price: good.rivalSellPrice) : nil
        }
    }

    /// Every bought good below the target, in catalog order.
    public static func buyOffers(stock: [Good: Int]) -> [RivalOffer] {
        Good.allCases.compactMap { good in
            let wanted = buyTarget - stock[good, default: 0]
            guard boughtGoods.contains(good), wanted > 0 else { return nil }
            return RivalOffer(good: good, quantity: wanted, price: good.rivalBuyPrice)
        }
    }
}

public extension World {
    /// Goods across the rival's goods buffers: its town center,
    /// warehouses and port.
    func rivalStock(_ id: RivalID) -> [Good: Int] {
        var totals: [Good: Int] = [:]
        for buffer in goodsBuffers(of: .rival(id)) {
            for (good, amount) in stockpiles[buffer.id]?.contents ?? [:] {
                totals[good, default: 0] += amount
            }
        }
        return totals
    }

    func sellOffers(of id: RivalID) -> [RivalOffer] {
        RivalMarket.sellOffers(stock: rivalStock(id))
    }

    func buyOffers(of id: RivalID) -> [RivalOffer] {
        RivalMarket.buyOffers(stock: rivalStock(id))
    }
}
