import Foundation

/// A good's seasonal limits at the town market, from its pack. Spec:
/// `town-market` / Market terms are content (design D3).
public struct MarketTerms: Equatable, Sendable {
    /// Units the market sells to the player per season; 0 means the
    /// good cannot be bought.
    public let buyLimit: Int
    /// Units the market buys from the player per season.
    public let sellLimit: Int

    public init(buyLimit: Int, sellLimit: Int) {
        self.buyLimit = buyLimit
        self.sellLimit = sellLimit
    }

    /// The good's limit for trades in `direction`, from the player's side.
    public func limit(_ direction: TradeDirection) -> Int {
        direction == .bought ? buyLimit : sellLimit
    }
}

/// Units the player bought and sold at the market this season, across
/// all their town centers. Spec: `town-market` / Seasonal limits reset
/// and persist (design D4).
public struct MarketLedger: Codable, Equatable, Sendable {
    public internal(set) var bought: [Good: Int] = [:]
    public internal(set) var sold: [Good: Int] = [:]

    public init() {}

    /// Units of `good` traded in `direction` this season.
    public func traded(_ good: Good, _ direction: TradeDirection) -> Int {
        (direction == .bought ? bought : sold)[good, default: 0]
    }

    /// Units of `good` the market still trades in `direction` this season.
    public func left(_ good: Good, _ direction: TradeDirection) -> Int {
        max(0, good.marketTerms.limit(direction) - traded(good, direction))
    }

    mutating func record(_ units: Int, of good: Good, _ direction: TradeDirection) {
        switch direction {
        case .bought: bought[good, default: 0] += units
        case .sold: sold[good, default: 0] += units
        }
    }
}

extension KeyedDecodingContainer {
    /// Saves written before the market have no ledger; they start the
    /// season with fresh limits. `World`'s synthesized decoder picks this
    /// overload for its `market` field.
    func decode(_ type: MarketLedger.Type, forKey key: Key) throws -> MarketLedger {
        try decodeIfPresent(type, forKey: key) ?? MarketLedger()
    }
}

/// One good's line at the market: prices and what is left this season.
/// Spec: `town-market` / Market trades are reported (design D6).
public struct MarketQuote: Hashable, Sendable {
    public let good: Good
    /// What the player pays per unit.
    public let buyPrice: Int64
    /// What the player earns per unit.
    public let sellPrice: Int64
    public let buyLeft: Int
    public let sellLeft: Int

    public init(good: Good, buyPrice: Int64, sellPrice: Int64, buyLeft: Int, sellLeft: Int) {
        self.good = good
        self.buyPrice = buyPrice
        self.sellPrice = sellPrice
        self.buyLeft = buyLeft
        self.sellLeft = sellLeft
    }
}
