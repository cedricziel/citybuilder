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

    /// The same, improved by `bonusPercent` of favour: the rival sells for
    /// that much less and buys for that much more, rounded down and at
    /// least $1. Spec: `rival-trade` / Favour improves a rival's prices.
    func rivalPrice(_ direction: TradeDirection, bonusPercent: Int) -> Int64 {
        let base = rivalPrice(direction)
        let percent = Int64(direction == .bought ? 100 - bonusPercent : 100 + bonusPercent)
        return max(1, base * percent / 100)
    }

    /// The unit price at the town market, from the player's side: 150%
    /// of base to buy and 50% to sell, rounded down, at least $1. The
    /// worst channel both ways. Spec: `town-market` / Market prices
    /// (design D2).
    func marketPrice(_ direction: TradeDirection) -> Int64 {
        max(1, direction == .bought ? basePrice * 3 / 2 : basePrice / 2)
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
    /// become merchants. Cloth is not among them: no rival has the wool
    /// chain, so its houses are never held to cloth (`World.bindingNeeds`).
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
    public static func sellOffers(stock: [Good: Int], bonusPercent: Int = 0) -> [RivalOffer] {
        Good.allCases.compactMap { good in
            let quantity = sellQuantity(of: good, stock: stock)
            return quantity > 0 ? RivalOffer(good: good, quantity: quantity, price: good.rivalPrice(.bought, bonusPercent: bonusPercent)) :
                nil
        }
    }

    /// Every bought good below the target, in catalog order.
    public static func buyOffers(stock: [Good: Int], bonusPercent: Int = 0) -> [RivalOffer] {
        Good.allCases.compactMap { good in
            let quantity = buyQuantity(of: good, stock: stock)
            return quantity > 0 ? RivalOffer(good: good, quantity: quantity, price: good.rivalPrice(.sold, bonusPercent: bonusPercent)) :
                nil
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
        RivalMarket.sellOffers(stock: rivalStock(id), bonusPercent: rivalPriceBonusPercent(id))
    }

    func buyOffers(of id: RivalID) -> [RivalOffer] {
        RivalMarket.buyOffers(stock: rivalStock(id), bonusPercent: rivalPriceBonusPercent(id))
    }
}
