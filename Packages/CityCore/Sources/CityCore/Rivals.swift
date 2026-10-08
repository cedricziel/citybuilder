import Foundation

/// A rival town's number, 1…3. Spec: `rival-towns`.
public typealias RivalID = UInt8

/// Who a building or ship belongs to. Encoded as one string, `"player"`
/// or `"rival-<id>"` (design D1).
public enum Owner: Hashable, Sendable {
    case player
    case rival(RivalID)

    public var rivalID: RivalID? {
        if case let .rival(id) = self { id } else { nil }
    }
}

extension Owner: Codable {
    private static let rivalPrefix = "rival-"

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        if raw == "player" {
            self = .player
        } else if raw.hasPrefix(Self.rivalPrefix), let id = RivalID(raw.dropFirst(Self.rivalPrefix.count)) {
            self = .rival(id)
        } else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath, debugDescription: "Unknown owner: \(raw)"
            ))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .player: try container.encode("player")
        case let .rival(id): try container.encode("\(Self.rivalPrefix)\(id)")
        }
    }
}

/// A rival's banner colour (design D2).
public enum RivalColour: String, CaseIterable, Codable, Hashable, Sendable {
    case crimson, azure, emerald

    /// The player's colour in the standings.
    public static let playerHex = "#D4A017"

    public var hex: String {
        switch self {
        case .crimson: "#B03A2E"
        case .azure: "#2E6DB4"
        case .emerald: "#2E8B57"
        }
    }

    /// Rival 1 crimson, 2 azure, 3 emerald.
    static func forRival(_ id: RivalID) -> RivalColour {
        allCases[(Int(id) - 1) % allCases.count]
    }
}

/// Where a rival is in its build script (design D5).
public struct RivalAIState: Hashable, Codable, Sendable {
    /// 0…11 the opening, then 12…19 the growth loop.
    public internal(set) var scriptIndex: Int = 0
    /// Turns spent waiting on the current script step.
    public internal(set) var waitTurns: Int = 0

    public init(scriptIndex: Int = 0, waitTurns: Int = 0) {
        self.scriptIndex = scriptIndex
        self.waitTurns = waitTurns
    }
}

/// An AI-run town seated on one island (design D2).
public struct RivalTown: Hashable, Codable, Sendable {
    public let id: RivalID
    public let name: String
    public let islandID: IslandID
    public let culture: Culture
    public let colour: RivalColour
    public internal(set) var age: Age
    public internal(set) var treasury: Int64
    public let townCenterID: EntityID
    public internal(set) var ai: RivalAIState

    public var owner: Owner {
        .rival(id)
    }
}

public extension Difficulty {
    /// Rival towns in a new archipelago game.
    var rivalCount: Int {
        switch self {
        case .easy: 1
        case .normal: 2
        case .hard: 3
        }
    }

    var rivalTreasury: Int64 {
        switch self {
        case .easy: 600
        case .normal: 1000
        case .hard: 1400
        }
    }

    /// Ticks between two turns of one rival.
    var rivalTurnTicks: UInt64 {
        switch self {
        case .easy: 80
        case .normal: 50
        case .hard: 30
        }
    }
}
