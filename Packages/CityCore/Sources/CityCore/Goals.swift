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
    /// At least this many orders fulfilled. Spec: `difficulty-and-goals` /
    /// Orders goal.
    case orders(Int)
    /// At least `count` operational player buildings of a kind.
    case buildings(BuildingKind, Int)
    /// Monuments completed plus gallery commissions run to their end.
    case signatureProjects(Int)
    case research(Tech)
    /// A balance of at least this much.
    case treasury(Int)
    /// Tax minus upkeep over the last completed season.
    case netIncome(Int)
    /// Money earned selling at the town market and at rival ports since
    /// the game started.
    case tradeEarnings(Int)
    /// Units of a good unloaded from player ships into player ports on the
    /// home island since the game started.
    case landedByShip(Good, Int)
}

/// Spec: `difficulty-and-goals` / Goals, Holding goals, Bonus goals.
public struct GoalState: Hashable, Codable, Sendable {
    /// How long a holding goal's condition must hold: one season.
    public static let holdTicks = CalendarState.ticksPerSeason

    public let goal: Goal
    public internal(set) var isMet: Bool
    /// Not needed for the win; each one met is a laurel.
    public let isBonus: Bool
    /// Met only once the condition has held for `holdTicks`.
    public let holdsForSeason: Bool
    /// The goal check that started the current hold.
    public internal(set) var heldSince: UInt64?

    public init(goal: Goal, isMet: Bool = false, isBonus: Bool = false, holdsForSeason: Bool = false) {
        self.goal = goal
        self.isMet = isMet
        self.isBonus = isBonus
        self.holdsForSeason = holdsForSeason
    }
}

/// Built-in scenarios. Spec: `difficulty-and-goals` / Built-in scenarios.
public enum Scenario: String, CaseIterable, Hashable, Sendable {
    case firstHarvest = "first-harvest"
    case guildTown = "guild-town"
    case steamAndSmoke = "steam-and-smoke"
    case islandRivalry = "island-rivalry"

    public var titleKey: String {
        "scenario.\(self).title"
    }

    public var blurbKey: String {
        "scenario.\(self).blurb"
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

    /// Bonus goals met: the laurels a won scenario carries.
    public var laurels: Int {
        goals.count { $0.isBonus && $0.isMet }
    }

    /// Current value toward a goal, and its target.
    public func progress(toward goal: Goal) -> (current: Int, target: Int) {
        switch goal {
        case let .population(count, tier): (residents(atLeast: tier), count)
        case let .age(target): (age >= target ? 1 : 0, 1)
        case let .stock(good, count): (storedQuantity(of: good), count)
        case .outgrowRivals: (population(of: .player), (rivals.map { population(of: $0.owner) }.max() ?? 0) + 1)
        case let .orders(count): (orders.fulfilledCount, count)
        case let .buildings(kind, count): (operationalCount(of: kind), count)
        case let .signatureProjects(count): (goalCounters.signatureProjects, count)
        case let .research(tech): (research.isResearched(tech) ? 1 : 0, 1)
        case let .treasury(amount): (Int(clamping: economy.balance), amount)
        case let .netIncome(amount): (lastSeasonNetIncome, amount)
        case let .tradeEarnings(amount): (Int(clamping: goalCounters.tradeEarnings), amount)
        case let .landedByShip(good, count): (goalCounters.landedAtHome[good] ?? 0, count)
        }
    }

    private func operationalCount(of kind: BuildingKind) -> Int {
        buildings.values.count { $0.kind == kind && $0.owner == .player && $0.state == .operational }
    }

    private var lastSeasonNetIncome: Int {
        guard let money = statistics.seasons.last?.money else { return 0 }
        return Int(clamping: money.tax - money.upkeep)
    }

    func conditionHolds(_ goal: Goal) -> Bool {
        let progress = progress(toward: goal)
        return progress.current >= progress.target
    }

    /// Marks goals met (they stay met), wins once every goal that is not a
    /// bonus goal is met, and otherwise checks the lose conditions
    /// (design D3 of `add-difficulty-and-goals`, D4 and D5 of
    /// `add-campaigns`).
    mutating func runGoalSystem(events: inout [WorldEvent]) {
        guard isScenarioRunning, tickCount.isMultiple(of: Self.goalCheckIntervalTicks) else { return }
        for index in goals.indices where !goals[index].isMet {
            updateGoal(at: index)
        }
        if goals.allSatisfy({ $0.isMet || $0.isBonus }) {
            scenarioWon = true
            events.append(.scenarioWon)
            return
        }
        if let reason = checkLoseConditions() {
            loseScenario(reason, events: &events)
        }
    }

    private mutating func updateGoal(at index: Int) {
        let holds = conditionHolds(goals[index].goal)
        goals[index].isMet = goals[index].holdsForSeason
            ? heldForSeason(holds, since: &goals[index].heldSince)
            : holds
    }

    /// True once `holds` has been true at every goal check for a season.
    /// `since` is the check that started the run, cleared when it breaks.
    func heldForSeason(_ holds: Bool, since: inout UInt64?) -> Bool {
        guard holds else {
            since = nil
            return false
        }
        let start = since ?? tickCount
        since = start
        return tickCount - start >= GoalState.holdTicks
    }
}
