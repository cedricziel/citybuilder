import Foundation

/// The player's culture, chosen at new game and fixed for the whole
/// game. Spec: `cultures`.
public enum Culture: String, CaseIterable, Codable, Hashable, Sendable {
    case northernEuropean = "northern-european"
    case mediterranean
    case eastAsian = "east-asian"
    case middleEastern = "middle-eastern"

    public var displayName: String {
        switch self {
        case .northernEuropean: "Northern European"
        case .mediterranean: "Mediterranean"
        case .eastAsian: "East Asian"
        case .middleEastern: "Middle Eastern"
        }
    }

    public var blurb: String {
        switch self {
        case .northernEuropean: "Half-timbered towns under steep tiled roofs."
        case .mediterranean: "Whitewashed walls, terracotta roofs and bell towers."
        case .eastAsian: "Timber halls under dark, wide-eaved roofs."
        case .middleEastern: "Sandstone, flat roofs and domes."
        }
    }

    /// The good this culture's merchants want on top of the shared
    /// needs. Spec: `culture-content` / Each culture has a luxury.
    var luxury: Good {
        luxuryChain.good
    }

    /// Every culture's garden and producer, in culture order.
    static let luxuryBuildings: [BuildingKind] = allCases.flatMap { [$0.luxuryChain.garden, $0.luxuryChain.producer] }

    /// The garden, producer and goods of the culture's luxury (design D3).
    var luxuryChain: LuxuryChain {
        switch self {
        case .northernEuropean: LuxuryChain(raw: .hops, good: .beer, garden: .hopGarden, producer: .brewery)
        case .mediterranean: LuxuryChain(raw: .grapes, good: .wine, garden: .vineyard, producer: .winery)
        case .eastAsian: LuxuryChain(raw: .teaLeaves, good: .tea, garden: .teaGarden, producer: .teaHouse)
        case .middleEastern: LuxuryChain(raw: .coffeeCherries, good: .coffee, garden: .coffeeGrove, producer: .roastery)
        }
    }
}

/// A culture's luxury: the garden grows `raw`, the producer turns it
/// into `good`. Both buildings are culture-only.
public struct LuxuryChain: Hashable, Sendable {
    public let raw: Good
    public let good: Good
    public let garden: BuildingKind
    public let producer: BuildingKind
}

public extension HouseTier {
    /// The tier's needs in `culture`: merchants add the culture's
    /// luxury (design D1).
    func needs(in culture: Culture) -> [Good] {
        self == .merchants ? needs + [culture.luxury] : needs
    }

    /// The culture's name for this tier (design D2).
    func displayName(in culture: Culture) -> String {
        switch (culture, self) {
        case (.northernEuropean, _): displayName
        case (.mediterranean, .peasants): "Plebeians"
        case (.mediterranean, .citizens): "Citizens"
        case (.mediterranean, .merchants): "Patricians"
        case (.eastAsian, .peasants): "Farmers"
        case (.eastAsian, .citizens): "Artisans"
        case (.eastAsian, .merchants): "Scholars"
        case (.middleEastern, .peasants): "Farmers"
        case (.middleEastern, .citizens): "Craftsmen"
        case (.middleEastern, .merchants): "Merchants"
        }
    }
}
