import Foundation

/// The player's culture, chosen at new game and fixed for the whole
/// game. Spec: `cultures`. Cases and values are generated from the packs.
extension Culture {
    /// The good this culture's merchants want on top of the shared
    /// needs. Spec: `culture-content` / Each culture has a luxury.
    var luxury: Good {
        luxuryChain.good
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
        culture.tierName(self)
    }
}
