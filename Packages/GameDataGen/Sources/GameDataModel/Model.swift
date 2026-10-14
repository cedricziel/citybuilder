/// Game content after loading, merging and validation, in load order:
/// packs in manifest order, then items in pack order.
public struct GameData: Equatable, Sendable {
    public var goods: [Good] = []
    public var buildings: [Building] = []
    public var cultures: [Culture] = []
    public var techs: [Tech] = []
    public var ages: [Age] = []

    /// Buildings that name `tech` in `unlockedBy`, in building order.
    public func unlocks(of tech: String) -> [String] {
        buildings.filter { $0.unlockedBy == tech }.map(\.id)
    }
}

/// The house tiers the simulation knows. They stay in Swift until the
/// `tier-needs-data` change makes them data.
public let houseTiers = ["peasants", "citizens", "merchants"]

/// An amount per good, kept in the order the pack wrote it.
public typealias GoodAmounts = [GoodAmount]

public struct GoodAmount: Equatable, Sendable {
    public var good: String
    public var amount: Int
}

/// A pack file and, when known, the line of the item or field.
public struct Origin: Equatable, Sendable, CustomStringConvertible {
    public var file: String
    public var line: Int?

    public var description: String {
        line.map { "\(file):\($0)" } ?? file
    }
}

public struct Good: Equatable, Sendable {
    public var id: String
    public var name: String
    public var unit: String
    public var basePrice: Int
    public var market: MarketLimits
    public var origin: Origin
}

/// Units per season the town market sells to (`buy`) and buys from
/// (`sell`) the player; 0 when the pack leaves one out.
public struct MarketLimits: Equatable, Sendable {
    public var buy: Int
    public var sell: Int

    public init(buy: Int = 0, sell: Int = 0) {
        self.buy = buy
        self.sell = sell
    }
}

public struct Recipe: Equatable, Sendable {
    public var inputs: GoodAmounts
    public var outputs: GoodAmounts
    public var cycleTicks: Int
}

public enum Placement: Equatable, Sendable {
    case shore(minLand: Int, minWater: Int)
    case terrain(type: String, minTiles: Int)
}

public struct Building: Equatable, Sendable {
    public var id: String
    public var name: String?
    public var legacyIds: [String]
    public var footprint: Size
    public var cost: Int
    public var upkeep: Int
    public var buildTicks: Int
    public var storage: Int?
    /// Ticks per planted forest tile, for buildings that plant.
    public var plantTicks: Int?
    public var category: String?
    public var materials: GoodAmounts
    public var recipe: Recipe?
    public var unlockedBy: String?
    public var obsoletedBy: String?
    public var culture: String?
    public var placement: Placement?
    public var hasCodeEffect: Bool
    public var origin: Origin
}

public struct Size: Equatable, Sendable {
    public var width: Int
    public var height: Int
}

public struct LuxuryChain: Equatable, Sendable {
    public var raw: String
    public var good: String
    public var garden: String
    public var producer: String
}

public struct Culture: Equatable, Sendable {
    public var id: String
    public var name: String
    public var blurb: String
    /// Display name per house tier, keyed by `houseTiers`.
    public var tiers: [String: String]
    public var luxury: LuxuryChain
    public var signature: String
    public var residentNames: [String]
    public var origin: Origin
}

public struct EraGate: Equatable, Sendable {
    public var tier: String
    public var residents: Int
}

public struct Tech: Equatable, Sendable {
    public var id: String
    public var name: String?
    public var cost: Int
    public var age: String
    public var prerequisites: [String]
    public var era: String?
    public var eraGate: EraGate?
    public var origin: Origin
}

public struct Age: Equatable, Sendable {
    public var id: String
    public var name: String?
    public var startYear: Int
    public var blurb: String
    public var signature: String
    public var rivalResidents: Int
    public var origin: Origin
}
