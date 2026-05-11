import Foundation

/// Single-currency money balance and the economy systems (build cost,
/// upkeep, tax, bankruptcy) that mutate it.
///
/// Per spec economy.
public struct Economy: Hashable, Codable, Sendable {
    public static let startingBalance: Int64 = 1000
    public static let taxIntervalTicks: UInt64 = 50 // every 5 sim-seconds
    public static let upkeepIntervalTicks: UInt64 = 50
    public static let bankruptcyGraceTicks: UInt64 = 50 // ~5 sim-seconds
    public static let taxPerPopUnit: Int64 = 1

    public var balance: Int64 = startingBalance
    public var bankruptcyDeficitTicks: UInt64 = 0
    public var gameOver: Bool = false

    public init() {}

    public mutating func deduct(_ amount: Int64) {
        balance -= amount
    }

    public mutating func credit(_ amount: Int64) {
        balance += amount
    }
}

public extension World {
    /// True if the world's economy has crossed the bankruptcy grace period
    /// with a non-positive balance.
    var isBankrupt: Bool {
        economy.gameOver
    }
}
