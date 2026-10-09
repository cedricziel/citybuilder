import CityCore
import Foundation

/// The Market section of a rival port's inspector. Spec:
/// `platform-shells` / Rival market in the inspector.
public struct RivalMarketSection: Equatable, Sendable {
    /// "Wood — $5 — 12 available", or "Nothing for sale".
    public let sells: [String]
    /// "Tools — $22 — wants 20", or "Buying nothing".
    public let buys: [String]

    init(_ rival: RivalSummary) {
        let sells = rival.sellOffers.map { "\(Self.name($0.good)) — $\($0.price) — \($0.quantity) available" }
        let buys = rival.buyOffers.map { "\(Self.name($0.good)) — $\($0.price) — wants \($0.quantity)" }
        self.sells = sells.isEmpty ? ["Nothing for sale"] : sells
        self.buys = buys.isEmpty ? ["Buying nothing"] : buys
    }

    private static func name(_ good: Good) -> String {
        GoodsCatalog.spec(for: good).displayName
    }
}

/// A manifest verb as the editor shows it.
public enum ManifestVerb: Hashable, Sendable {
    case load
    case unload
}

/// One good in the manifest editor; `price` and `offer` are set at a
/// rival port only.
public struct ManifestGoodRow: Hashable, Sendable {
    public let good: Good
    /// "$5", nil without an offer.
    public let price: String?
    /// "12", or "no offer".
    public let offer: String?
}

/// Labels and good rows for one port's manifest. At a rival port a load
/// buys and an unload sells, so the editor shows Buy and Sell with the
/// current price and offer. Spec: `platform-shells` / Buy and Sell in
/// the manifest editor.
public struct ManifestEditorModel: Sendable {
    /// The rival owning the port, nil for the player's.
    public let rival: RivalSummary?

    public init(snapshot: WorldSnapshot, port: EntityID) {
        rival = snapshot.buildings[port]?.owner.rivalID.flatMap(snapshot.rival)
    }

    public func label(for verb: ManifestVerb) -> String {
        switch (verb, rival != nil) {
        case (.load, false): "Load"
        case (.unload, false): "Unload"
        case (.load, true): "Buy"
        case (.unload, true): "Sell"
        }
    }

    /// Every good in catalog order; goods without an offer stay listed,
    /// since the offer may appear later.
    public func rows(for verb: ManifestVerb) -> [ManifestGoodRow] {
        guard let rival else { return Good.allCases.map { ManifestGoodRow(good: $0, price: nil, offer: nil) } }
        return Good.allCases.map { good in
            let quantity = verb == .load
                ? RivalMarket.sellQuantity(of: good, stock: rival.stock)
                : RivalMarket.buyQuantity(of: good, stock: rival.stock)
            guard quantity > 0 else { return ManifestGoodRow(good: good, price: nil, offer: "no offer") }
            let price = good.rivalPrice(verb == .load ? .bought : .sold)
            return ManifestGoodRow(good: good, price: "$\(price)", offer: "\(quantity)")
        }
    }
}
