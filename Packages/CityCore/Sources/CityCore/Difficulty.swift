import Foundation

/// Spec: `difficulty-and-goals` / Difficulty.
public enum Difficulty: String, CaseIterable, Codable, Hashable, Sendable {
    case easy, normal, hard

    public var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    public var startingBalance: Int64 {
        switch self {
        case .easy: 1500
        case .normal: 1000
        case .hard: 700
        }
    }

    /// Wood, planks and food in each town center at the start.
    public var starterStock: [(Good, Int)] {
        switch self {
        case .easy: [(.wood, 10), (.planks, 8), (.food, 4)]
        case .normal: [(.wood, 6), (.planks, 5), (.food, 2)]
        case .hard: [(.wood, 4), (.planks, 3), (.food, 1)]
        }
    }

    public var upkeepPercent: Int64 {
        switch self {
        case .easy: 75
        case .normal: 100
        case .hard: 125
        }
    }

    public var bankruptcyGraceTicks: UInt64 {
        switch self {
        case .easy: 150
        case .normal: 50
        case .hard: 30
        }
    }

    /// Chance in percent that a history event fires at the turn of a year.
    public var eventChancePercent: UInt64 {
        self == .hard ? 65 : 50
    }

    /// Draw weight of harmful history events; helpful ones weigh 1.
    public var harmfulEventWeight: Int {
        switch self {
        case .easy: 0
        case .normal: 1
        case .hard: 2
        }
    }

    /// Upkeep after scaling, never rounding a due payment down to zero.
    public func scaledUpkeep(_ base: Int64) -> Int64 {
        guard base > 0 else { return 0 }
        return max(1, base * upkeepPercent / 100)
    }
}
