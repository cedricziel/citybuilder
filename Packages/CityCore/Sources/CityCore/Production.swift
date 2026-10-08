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
    // swiftlint:disable:next cyclomatic_complexity
    public static func recipe(for kind: BuildingKind) -> ProductionRecipe? {
        switch kind {
        case .lumberjackHut:
            ProductionRecipe(outputs: [.wood: 1], cycleTicks: 30)
        case .sawmill:
            ProductionRecipe(inputs: [.wood: 1], outputs: [.planks: 1], cycleTicks: 25)
        case .farm:
            ProductionRecipe(outputs: [.food: 1], cycleTicks: 40)
        case .bakery:
            ProductionRecipe(inputs: [.flour: 1], outputs: [.bread: 1], cycleTicks: 50)
        case .grainFarm:
            ProductionRecipe(outputs: [.grain: 1], cycleTicks: 40)
        case .windmill:
            ProductionRecipe(inputs: [.grain: 2], outputs: [.flour: 1], cycleTicks: 40)
        case .quernHouse:
            ProductionRecipe(inputs: [.grain: 2], outputs: [.flour: 1], cycleTicks: 80)
        case .mine:
            ProductionRecipe(outputs: [.ore: 1], cycleTicks: 50)
        case .charcoalBurner:
            ProductionRecipe(inputs: [.wood: 2], outputs: [.charcoal: 1], cycleTicks: 40)
        case .smelter:
            ProductionRecipe(inputs: [.ore: 1, .charcoal: 1], outputs: [.iron: 1], cycleTicks: 50)
        case .toolsmith:
            ProductionRecipe(inputs: [.iron: 1, .planks: 1], outputs: [.tools: 1], cycleTicks: 60)
        case .hopGarden, .vineyard, .teaGarden, .coffeeGrove:
            kind.culture.map { ProductionRecipe(outputs: [$0.luxuryChain.raw: 1], cycleTicks: 40) }
        case .brewery, .winery, .teaHouse, .roastery:
            kind.culture.map {
                ProductionRecipe(inputs: [$0.luxuryChain.raw: 2], outputs: [$0.luxury: 1], cycleTicks: 50)
            }
        case .monument:
            // One project stage; see `World.monumentStages`.
            ProductionRecipe(inputs: [.wood: 2, .planks: 2, .bread: 1], outputs: [:], cycleTicks: 60)
        case .house, .warehouse, .road, .townCenter, .port, .library,
             .guildHall, .gallery, .steamEngine, .powerPlant,
             .meadHall, .forum, .templeGarden, .caravanserai:
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
