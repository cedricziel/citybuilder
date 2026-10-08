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
        case .farm:
            ProductionRecipe(outputs: [.food: 1], cycleTicks: 40)
        case .bakery:
            ProductionRecipe(inputs: [.food: 2], outputs: [.bread: 1], cycleTicks: 50)
        case .house, .warehouse, .road, .townCenter, .port:
            nil
        case .shipyard:
            // Shipyard recipe: 20 wood + 10 planks per ship hull. The
            // recipe completion side-effect is "emit a Ship entity" —
            // handled by a special-case M5 system, not by the generic
            // output-stockpile flow that other producers use.
            ProductionRecipe(inputs: [.wood: 20, .planks: 10], outputs: [:], cycleTicks: 200)
        }
    }
}
