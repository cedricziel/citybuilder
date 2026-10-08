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
}

public extension HouseTier {
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
