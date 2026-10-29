import Foundation

/// What a rival race is run to. Measured for a rival as the player's
/// goal of the same kind would be. Spec: `difficulty-and-goals` / Lose
/// conditions.
public enum RaceTarget: Hashable, Codable, Sendable {
    case age(Age)
    case population(Int, atLeast: HouseTier)

    public var goal: Goal {
        switch self {
        case let .age(age): .age(age)
        case let .population(count, tier): .population(count, atLeast: tier)
        }
    }
}

/// A way to lose a scenario besides bankruptcy, checked on the goal
/// interval.
public enum LoseCondition: Hashable, Codable, Sendable {
    /// Lost when this year starts with a goal that is not a bonus goal unmet.
    case deadline(year: Int)
    /// Lost when a rival reaches the target before the player does.
    case rivalRace(RaceTarget)
    /// Once the player's residents reached the floor, lost when they stay
    /// below it for a season.
    case collapse(below: Int)
}

public struct LoseConditionState: Hashable, Codable, Sendable {
    public let condition: LoseCondition
    /// A rival race the player reached first, so it can no longer be
    /// lost, or a collapse floor the player's residents have reached.
    public internal(set) var settled = false
    /// The goal check that first found the residents below the floor.
    public internal(set) var belowFloorSince: UInt64?

    public init(condition: LoseCondition) {
        self.condition = condition
    }
}

/// Why a scenario was lost.
public enum LossReason: Hashable, Codable, Sendable {
    case bankruptcy
    case deadline
    case rivalRace(RivalID)
    case collapse
}

extension World {
    /// A scenario game that is neither won nor lost yet.
    var isScenarioRunning: Bool {
        !goals.isEmpty && !scenarioWon && scenarioLoss == nil
    }

    /// Ends a running scenario as lost. Player commands go on unless the
    /// economy is over (design D5).
    mutating func loseScenario(_ reason: LossReason, events: inout [WorldEvent]) {
        guard isScenarioRunning else { return }
        scenarioLoss = reason
        events.append(.scenarioLost(reason))
    }

    /// The first lose condition that fires at this goal check, updating
    /// the race and collapse state on the way.
    mutating func checkLoseConditions() -> LossReason? {
        for index in loseConditions.indices {
            if let reason = check(&loseConditions[index]) { return reason }
        }
        return nil
    }

    private func check(_ state: inout LoseConditionState) -> LossReason? {
        switch state.condition {
        case let .deadline(year):
            return date.year >= year ? .deadline : nil
        case let .rivalRace(target):
            guard !state.settled else { return nil }
            if conditionHolds(target.goal) {
                state.settled = true
                return nil
            }
            return rivals.first { reaches(target, $0) }.map { .rivalRace($0.id) }
        case let .collapse(floor):
            let below = population(of: .player) < floor
            if !below { state.settled = true }
            guard state.settled else { return nil }
            return heldForSeason(below, since: &state.belowFloorSince) ? .collapse : nil
        }
    }

    private func reaches(_ target: RaceTarget, _ rival: RivalTown) -> Bool {
        switch target {
        case let .age(age): rival.age >= age
        case let .population(count, tier): residents(of: rival.owner, atLeast: tier) >= count
        }
    }
}
