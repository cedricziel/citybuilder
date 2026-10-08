import Foundation

/// Goods catalog. Identifiers stay stable across milestones; the full
/// catalog grows in M4 when production chains land.
public enum Good: String, CaseIterable, Codable, Sendable {
    case wood
    case planks
    case food
    case bread
    case grain
    case flour
    case ore
    case charcoal
    case iron
    case tools
    case hops
    case beer
    case grapes
    case wine
    case teaLeaves = "tea-leaves"
    case tea
    case coffeeCherries = "coffee-cherries"
    case coffee
}

/// Goods catalog metadata. Unit / display name. Lightweight today; expands
/// when the M4 production system needs it.
public struct GoodSpec: Hashable, Sendable {
    public let good: Good
    public let displayName: String
    public let stackUnit: String

    public init(good: Good, displayName: String, stackUnit: String) {
        self.good = good
        self.displayName = displayName
        self.stackUnit = stackUnit
    }
}

public enum GoodsCatalog {
    private static let specs: [Good: GoodSpec] = [
        .wood: GoodSpec(good: .wood, displayName: "Wood", stackUnit: "logs"),
        .planks: GoodSpec(good: .planks, displayName: "Planks", stackUnit: "bundles"),
        .food: GoodSpec(good: .food, displayName: "Food", stackUnit: "rations"),
        .bread: GoodSpec(good: .bread, displayName: "Bread", stackUnit: "loaves"),
        .grain: GoodSpec(good: .grain, displayName: "Grain", stackUnit: "sheaves"),
        .flour: GoodSpec(good: .flour, displayName: "Flour", stackUnit: "sacks"),
        .ore: GoodSpec(good: .ore, displayName: "Ore", stackUnit: "loads"),
        .charcoal: GoodSpec(good: .charcoal, displayName: "Charcoal", stackUnit: "baskets"),
        .iron: GoodSpec(good: .iron, displayName: "Iron", stackUnit: "bars"),
        .tools: GoodSpec(good: .tools, displayName: "Tools", stackUnit: "sets"),
        .hops: GoodSpec(good: .hops, displayName: "Hops", stackUnit: "bales"),
        .beer: GoodSpec(good: .beer, displayName: "Beer", stackUnit: "casks"),
        .grapes: GoodSpec(good: .grapes, displayName: "Grapes", stackUnit: "baskets"),
        .wine: GoodSpec(good: .wine, displayName: "Wine", stackUnit: "amphorae"),
        .teaLeaves: GoodSpec(good: .teaLeaves, displayName: "Tea Leaves", stackUnit: "baskets"),
        .tea: GoodSpec(good: .tea, displayName: "Tea", stackUnit: "chests"),
        .coffeeCherries: GoodSpec(good: .coffeeCherries, displayName: "Coffee Cherries", stackUnit: "sacks"),
        .coffee: GoodSpec(good: .coffee, displayName: "Coffee", stackUnit: "sacks")
    ]

    public static var all: [GoodSpec] {
        Array(specs.values)
    }

    public static func spec(for good: Good) -> GoodSpec {
        guard let result = specs[good] else {
            preconditionFailure("Good \(good) missing from catalog")
        }
        return result
    }
}

/// Storage container holding mixed goods with a single total capacity.
public struct Stockpile: Hashable, Codable, Sendable {
    public private(set) var capacity: Int
    public private(set) var contents: [Good: Int] = [:]

    public init(capacity: Int) {
        self.capacity = max(0, capacity)
    }

    public var totalStored: Int {
        contents.values.reduce(0, +)
    }

    public var freeSpace: Int {
        max(0, capacity - totalStored)
    }

    public func quantity(of good: Good) -> Int {
        contents[good] ?? 0
    }

    /// Deposit up to `amount`. Returns the number actually accepted (may be
    /// less than amount if capacity runs out).
    @discardableResult
    public mutating func deposit(_ good: Good, amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        let accepted = min(amount, freeSpace)
        contents[good, default: 0] += accepted
        return accepted
    }

    /// Withdraw up to `amount`. Returns the number actually returned.
    @discardableResult
    public mutating func withdraw(_ good: Good, amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        let available = quantity(of: good)
        let taken = min(amount, available)
        contents[good, default: 0] -= taken
        if contents[good] == 0 { contents.removeValue(forKey: good) }
        return taken
    }
}
