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
}
