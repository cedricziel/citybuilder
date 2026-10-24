import Foundation

/// A good's display name and stack unit. `GoodsCatalog` is generated from
/// the game-data packs.
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
