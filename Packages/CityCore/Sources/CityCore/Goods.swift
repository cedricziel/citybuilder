import Foundation

/// A good's catalog entry. `GoodsCatalog` is generated from the game-data
/// packs; the good's name and unit are catalog keys on `Good`.
public struct GoodSpec: Hashable, Sendable {
    public let good: Good

    public init(good: Good) {
        self.good = good
    }
}

/// Storage container holding mixed goods. A pooled stockpile (producers,
/// houses) shares one total `capacity` between its goods; a per-good one
/// (town centers, warehouses, ports) holds up to `capacity` of each good,
/// so one good can never crowd out another. Spec:
/// `warehouses-and-logistics` / Stores hold each good separately.
public struct Stockpile: Hashable, Codable, Sendable {
    /// The total for a pooled stockpile, the limit per good otherwise.
    public private(set) var capacity: Int
    /// True when `capacity` limits each good on its own.
    public private(set) var limitsEachGood: Bool
    public private(set) var contents: [Good: Int] = [:]
    /// The only goods it takes, nil for every good: a granary's food goods.
    public private(set) var accepted: Set<Good>?

    /// A pooled stockpile: `capacity` units in all.
    public init(capacity: Int) {
        self.capacity = max(0, capacity)
        limitsEachGood = false
    }

    /// A per-good stockpile: up to `perGood` units of each good it
    /// accepts, every good unless `accepted` names some.
    public init(perGood: Int, accepting accepted: Set<Good>? = nil) {
        capacity = max(0, perGood)
        limitsEachGood = true
        self.accepted = accepted
    }

    public var totalStored: Int {
        contents.values.reduce(0, +)
    }

    /// Units any good could still add: for a per-good stockpile, the room
    /// summed over every good.
    public var freeSpace: Int {
        limitsEachGood
            ? Good.allCases.reduce(0) { $0 + room(for: $1) }
            : max(0, capacity - totalStored)
    }

    /// Units of `good` that still fit. Stock above a per-good limit (from
    /// a save made before the limit) stays until it is used, and leaves
    /// no room meanwhile.
    public func room(for good: Good) -> Int {
        guard accepts(good) else { return 0 }
        return limitsEachGood ? max(0, capacity - quantity(of: good)) : max(0, capacity - totalStored)
    }

    public func accepts(_ good: Good) -> Bool {
        accepted?.contains(good) ?? true
    }

    public func quantity(of good: Good) -> Int {
        contents[good] ?? 0
    }

    /// Deposit up to `amount`. Returns the number actually accepted (may be
    /// less than amount if there is not room).
    @discardableResult
    public mutating func deposit(_ good: Good, amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        let accepted = min(amount, room(for: good))
        contents[good, default: 0] += accepted
        return accepted
    }

    /// Makes `capacity` a per-good limit, keeping every unit held, as a
    /// store migrated from a pooled save does: stock above the limit
    /// stays as overflow.
    mutating func limitEachGood(to perGood: Int) {
        capacity = max(0, perGood)
        limitsEachGood = true
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

    private enum CodingKeys: String, CodingKey {
        case capacity, limitsEachGood, contents, accepted
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        capacity = try container.decode(Int.self, forKey: .capacity)
        limitsEachGood = try container.decodeIfPresent(Bool.self, forKey: .limitsEachGood) ?? false
        contents = try container.decode([Good: Int].self, forKey: .contents)
        accepted = try container.decodeIfPresent(Set<Good>.self, forKey: .accepted)
    }
}
