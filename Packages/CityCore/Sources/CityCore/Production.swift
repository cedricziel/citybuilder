import Foundation

/// Production recipe: inputs (per cycle) → outputs (per cycle) + duration.
public struct ProductionRecipe: Hashable, Sendable {
    public let inputs: [Good: Int]
    public let outputs: [Good: Int]
    public let cycleTicks: UInt64

    public init(inputs: [Good: Int] = [:], outputs: [Good: Int], cycleTicks: UInt64) {
        self.inputs = inputs
        self.outputs = outputs
        self.cycleTicks = cycleTicks
    }
}

/// Per-building progress through its current production cycle.
public struct ProductionProgress: Hashable, Codable, Sendable {
    public var ticksThisCycle: UInt64 = 0
    public var isStalled: Bool = false

    public init() {}
}

public enum ProductionCatalog {
    public static func recipe(for kind: BuildingKind) -> ProductionRecipe? {
        switch kind {
        case .lumberjackHut:
            ProductionRecipe(outputs: [.wood: 1], cycleTicks: 30)
        case .sawmill:
            ProductionRecipe(inputs: [.wood: 1], outputs: [.planks: 1], cycleTicks: 25)
        case .house, .warehouse, .road, .townCenter:
            nil
        }
    }
}
