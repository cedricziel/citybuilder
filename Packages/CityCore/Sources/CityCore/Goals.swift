import Foundation

/// Spec: `difficulty-and-goals` / Goals.
public enum Goal: Hashable, Codable, Sendable {
    /// At least `count` residents living at `tier` or above.
    case population(Int, atLeast: HouseTier)
    case age(Age)
    /// At least `count` of a good across the goods buffers.
    case stock(Good, Int)
    /// More residents than every rival town. Spec: `rival-towns` /
    /// Outgrow every rival.
    case outgrowRivals
}

public struct GoalState: Hashable, Codable, Sendable {
    public let goal: Goal
    public internal(set) var isMet: Bool

    public init(goal: Goal, isMet: Bool = false) {
        self.goal = goal
        self.isMet = isMet
    }
}

/// Built-in scenarios. Spec: `difficulty-and-goals` / Built-in scenarios.
public enum Scenario: String, CaseIterable, Hashable, Sendable {
    case firstHarvest = "first-harvest"
    case guildTown = "guild-town"
    case steamAndSmoke = "steam-and-smoke"
    case islandRivalry = "island-rivalry"

    public var title: String {
        switch self {
        case .firstHarvest: "First Harvest"
        case .guildTown: "The Guild Town"
        case .steamAndSmoke: "Steam and Smoke"
        case .islandRivalry: "Island Rivalry"
        }
    }

    public var blurb: String {
        switch self {
        case .firstHarvest: "Grow an Antiquity village to 40 people and store 20 bread."
        case .guildTown: "Raise 30 merchants and stock 30 tools."
        case .steamAndSmoke: "Lead a Renaissance town into the Industrial age."
        case .islandRivalry: "Out-build two rival towns and reach 80 residents."
        }
    }

    /// The layout the scenario is played on, nil when any will do.
    public var requiredLayout: WorldLayout? {
        self == .islandRivalry ? .archipelago : nil
    }

    public var age: Age {
        switch self {
        case .firstHarvest: .antiquity
        case .guildTown, .islandRivalry: .medieval
        case .steamAndSmoke: .renaissance
        }
    }

    public var difficulty: Difficulty {
        switch self {
        case .firstHarvest: .easy
        case .guildTown, .islandRivalry: .normal
        case .steamAndSmoke: .hard
        }
    }

    public var goals: [Goal] {
        switch self {
        case .firstHarvest: [.population(40, atLeast: .peasants), .stock(.bread, 20)]
        case .guildTown: [.population(30, atLeast: .merchants), .stock(.tools, 30)]
        case .steamAndSmoke: [.age(.industrial)]
        case .islandRivalry: [.outgrowRivals, .population(80, atLeast: .peasants)]
        }
    }
}

extension World {
    static let goalCheckIntervalTicks: UInt64 = 10

    /// Units of `good` held by the player's goods buffers.
    public func storedQuantity(of good: Good) -> Int {
        goodsBuffers(of: .player).reduce(0) { $0 + (stockpiles[$1.id]?.quantity(of: good) ?? 0) }
    }

    /// Current value toward a goal, and its target.
    public func progress(toward goal: Goal) -> (current: Int, target: Int) {
        switch goal {
        case let .population(count, tier): (residents(atLeast: tier), count)
        case let .age(target): (age >= target ? 1 : 0, 1)
        case let .stock(good, count): (storedQuantity(of: good), count)
        case .outgrowRivals: (population(of: .player), (rivals.map { population(of: $0.owner) }.max() ?? 0) + 1)
        }
    }

    /// Marks goals met (they stay met) and wins once all are met
    /// (design D3).
    mutating func runGoalSystem(events: inout [WorldEvent]) {
        guard !goals.isEmpty, !scenarioWon, tickCount.isMultiple(of: Self.goalCheckIntervalTicks) else { return }
        for index in goals.indices where !goals[index].isMet {
            let progress = progress(toward: goals[index].goal)
            goals[index].isMet = progress.current >= progress.target
        }
        if goals.allSatisfy(\.isMet) {
            scenarioWon = true
            events.append(.scenarioWon)
        }
    }
}
