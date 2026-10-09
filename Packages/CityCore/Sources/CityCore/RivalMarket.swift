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

    /// The unit price of a trade in `direction`, from the player's side.
    func rivalPrice(_ direction: TradeDirection) -> Int64 {
        direction == .bought ? rivalSellPrice : rivalBuyPrice
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

    /// Units of `good` on sale: the stock above the reserve.
    public static func sellQuantity(of good: Good, stock: [Good: Int]) -> Int {
        max(0, stock[good, default: 0] - sellReserve)
    }

    /// Units of `good` wanted: a bought good's shortfall to the target.
    public static func buyQuantity(of good: Good, stock: [Good: Int]) -> Int {
        boughtGoods.contains(good) ? max(0, buyTarget - stock[good, default: 0]) : 0
    }

    /// Every good above the reserve, in catalog order.
    public static func sellOffers(stock: [Good: Int]) -> [RivalOffer] {
        Good.allCases.compactMap { good in
            let quantity = sellQuantity(of: good, stock: stock)
            return quantity > 0 ? RivalOffer(good: good, quantity: quantity, price: good.rivalSellPrice) : nil
        }
    }

    /// Every bought good below the target, in catalog order.
    public static func buyOffers(stock: [Good: Int]) -> [RivalOffer] {
        Good.allCases.compactMap { good in
            let quantity = buyQuantity(of: good, stock: stock)
            return quantity > 0 ? RivalOffer(good: good, quantity: quantity, price: good.rivalBuyPrice) : nil
        }
    }
}

public extension World {
    /// Goods across the rival's goods buffers: its town center,
    /// warehouses and port. Unlike an island summary it counts by owner,
    /// which is what trades draw on. A sum, so building order doesn't
    /// matter.
    func rivalStock(_ id: RivalID) -> [Good: Int] {
        var totals: [Good: Int] = [:]
        let owner = Owner.rival(id)
        for building in buildings.values where building.owner == owner && Self.logisticsBufferKinds.contains(building.kind) {
            for (good, amount) in stockpiles[building.id]?.contents ?? [:] {
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
