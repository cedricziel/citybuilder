import Foundation

/// An order's number, from 1. Spec: `orders`.
public typealias OrderID = UInt32

/// Who sent an order. Encoded as one string, `"crown"` or `"rival-<id>"`,
/// like `Owner`.
public enum OrderIssuer: Hashable, Sendable {
    case crown
    case rival(RivalID)

    public var rivalID: RivalID? {
        if case let .rival(id) = self { id } else { nil }
    }
}

extension OrderIssuer: Codable {
    private static let rivalPrefix = "rival-"

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        if raw == "crown" {
            self = .crown
        } else if raw.hasPrefix(Self.rivalPrefix), let id = RivalID(raw.dropFirst(Self.rivalPrefix.count)) {
            self = .rival(id)
        } else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath, debugDescription: "Unknown order issuer: \(raw)"
            ))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .crown: try container.encode("crown")
        case let .rival(id): try container.encode("\(Self.rivalPrefix)\(id)")
        }
    }
}

public enum OrderState: String, Codable, Hashable, Sendable {
    case offered, accepted, fulfilled, failed, expired, declined

    /// An offer or an accepted order.
    public var isOpen: Bool {
        self == .offered || self == .accepted
    }
}

/// One timed request. Spec: `orders`.
public struct Order: Codable, Hashable, Sendable, Identifiable {
    public let id: OrderID
    public let template: OrderTemplate
    public let issuer: OrderIssuer
    public let good: Good
    public let quantity: Int
    /// Money paid on fulfilment.
    public let reward: Int64
    public let favourGain: Int
    public let favourLoss: Int
    public let issuedTick: UInt64
    /// Offers lapse at this tick unless accepted.
    public let offerEndsTick: UInt64
    /// On time through this tick.
    public let deadlineTick: UInt64
    public internal(set) var state: OrderState
    /// Units that have reached the issuer.
    public internal(set) var delivered: Int

    init(
        id: OrderID, template: OrderTemplate, issuer: OrderIssuer, good: Good, quantity: Int, reward: Int64,
        favourGain: Int, favourLoss: Int, issuedTick: UInt64, offerEndsTick: UInt64, deadlineTick: UInt64,
        state: OrderState = .offered, delivered: Int = 0
    ) {
        self.id = id
        self.template = template
        self.issuer = issuer
        self.good = good
        self.quantity = quantity
        self.reward = reward
        self.favourGain = favourGain
        self.favourLoss = favourLoss
        self.issuedTick = issuedTick
        self.offerEndsTick = offerEndsTick
        self.deadlineTick = deadlineTick
        self.state = state
        self.delivered = delivered
    }

    public var remaining: Int {
        max(0, quantity - delivered)
    }
}

/// Goods of an accepted crown order walking the roads from a store to a
/// town center. Not a `Carrier`: orders keep their own state and tick step.
public struct OrderShipment: Codable, Hashable, Sendable {
    public let id: EntityID
    public let order: OrderID
    public let good: Good
    public let amount: Int
    public let path: [TileCoordinate]
    public internal(set) var pathIndex: Int
    public let from: EntityID
    public let to: EntityID

    init(
        id: EntityID, order: OrderID, good: Good, amount: Int, path: [TileCoordinate], pathIndex: Int = 0,
        from: EntityID, to: EntityID
    ) {
        self.id = id
        self.order = order
        self.good = good
        self.amount = amount
        self.path = path
        self.pathIndex = pathIndex
        self.from = from
        self.to = to
    }

    var hasArrived: Bool {
        pathIndex >= path.count - 1
    }

    /// What the renderer draws: a goods walker on its way to the town center.
    public var asCarrier: Carrier {
        Carrier(
            id: id, path: path, pathIndex: pathIndex,
            mission: .deliver(good: good, amount: amount, fromProducer: from, toWarehouse: to)
        )
    }
}

/// The player's standing with the crown and with each rival. Spec: `orders`
/// / Favour has steps.
public struct FavourLedger: Codable, Hashable, Sendable {
    public internal(set) var crown = 0
    public internal(set) var rivals: [RivalID: Int] = [:]

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case crown, rivals
    }

    /// Rival favour is written under string keys, so equal saves are equal
    /// bytes whatever order the dictionary iterates in.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        crown = try container.decode(Int.self, forKey: .crown)
        let raw = try container.decode([String: Int].self, forKey: .rivals)
        rivals = Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in RivalID(key).map { ($0, value) } })
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(crown, forKey: .crown)
        try container.encode(Dictionary(uniqueKeysWithValues: rivals.map { (String($0.key), $0.value) }), forKey: .rivals)
    }

    public func value(for issuer: OrderIssuer) -> Int {
        switch issuer {
        case .crown: crown
        case let .rival(id): rivals[id, default: 0]
        }
    }

    mutating func adjust(_ issuer: OrderIssuer, by change: Int) {
        let value = min(max(value(for: issuer) + change, OrderRules.favourRange.lowerBound), OrderRules.favourRange.upperBound)
        switch issuer {
        case .crown: crown = value
        case let .rival(id): rivals[id] = value
        }
    }
}

/// Everything orders keep in the world. Saves without it decode an empty
/// state (see the `KeyedDecodingContainer` overload below).
public struct OrdersState: Codable, Hashable, Sendable {
    /// Open orders and the last few closed ones, oldest first.
    public internal(set) var orders: [Order] = []
    public internal(set) var shipments: [OrderShipment] = []
    public internal(set) var favour = FavourLedger()
    public internal(set) var fulfilledCount = 0
    public internal(set) var failedCount = 0
    public internal(set) var nextOrderRaw: OrderID = 1

    public init() {}
}

extension KeyedDecodingContainer {
    /// Saves written before orders have none; they start empty and the
    /// schedule, derived from the tick count, issues the next one.
    func decode(_ type: OrdersState.Type, forKey key: Key) throws -> OrdersState {
        try decodeIfPresent(type, forKey: key) ?? OrdersState()
    }
}

/// The rules that define the system rather than tune it. Spec: `orders`.
public enum OrderRules {
    /// The first season orders are issued in: the start of year 2.
    public static let firstSeason = 4
    public static let maxAccepted = 2
    public static let boardSize = 3
    /// Seasons an offer stays on the board.
    public static let offerSeasons = 1
    /// A rival posts at most every this many seasons.
    public static let rivalEverySeasons = 2
    /// Closed seasons whose output sizes an order.
    public static let outputWindowSeasons = 4
    /// Share of what the stores hold of a good that an order may ask for.
    public static let storeCapPercent = 75
    public static let favourRange = -10 ... 20
    /// Favour at which step 1 and step 2 begin.
    public static let stepThresholds = [6, 12]
    /// Research cost saved at each step of the crown's favour, in percent.
    public static let crownResearchDiscountPercent = [0, 3, 5]
    /// Price improvement at each step of a rival's favour, in percent.
    public static let rivalPriceBonusPercent = [0, 5, 10]
    /// Closed orders kept for the board's history.
    public static let closedOrdersKept = 8

    public static func step(of favour: Int) -> Int {
        stepThresholds.filter { favour >= $0 }.count
    }
}

public extension Difficulty {
    /// Seasons between crown orders, in percent of the age's `orderEvery`.
    var orderCadencePercent: Int {
        switch self {
        case .easy: 150
        case .normal: 100
        case .hard: 75
        }
    }

    /// Order quantity, in percent.
    var orderSizePercent: Int {
        switch self {
        case .easy: 80
        case .normal: 100
        case .hard: 120
        }
    }

    /// Order window, in percent.
    var orderWindowPercent: Int {
        switch self {
        case .easy: 130
        case .normal: 100
        case .hard: 85
        }
    }
}
