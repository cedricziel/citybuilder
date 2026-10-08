import Foundation

/// Spec: `calendar-and-events`.
public enum Season: Int, CaseIterable, Codable, Hashable, Sendable {
    case spring, summer, autumn, winter

    public var displayName: String {
        switch self {
        case .spring: "Spring"
        case .summer: "Summer"
        case .autumn: "Autumn"
        case .winter: "Winter"
        }
    }
}

public struct GameDate: Hashable, Sendable {
    public let year: Int
    public let season: Season

    public init(year: Int, season: Season) {
        self.year = year
        self.season = season
    }

    /// Years ≤ 0 read as BC: year 0 is 1 BC (design D2 of
    /// `add-historical-ages`).
    public var displayText: String {
        year > 0 ? "\(season.displayName) \(year)" : "\(season.displayName) \(1 - year) BC"
    }
}

/// Only the start year is stored; the date is derived from the tick
/// count so the two can never disagree. `isActive` gates seasonal
/// farming and history events (design D2).
public struct CalendarState: Codable, Hashable, Sendable {
    public static let ticksPerSeason: UInt64 = 600
    public static let ticksPerYear: UInt64 = ticksPerSeason * 4

    public var startYear: Int
    public var isActive: Bool

    public init(startYear: Int, isActive: Bool) {
        self.startYear = startYear
        self.isActive = isActive
    }

    public static let inactive = CalendarState(startYear: 1200, isActive: false)

    public func date(atTick tick: UInt64) -> GameDate {
        let season = Season(rawValue: Int((tick / Self.ticksPerSeason) % 4)) ?? .spring
        return GameDate(year: startYear + Int(tick / Self.ticksPerYear), season: season)
    }
}

public enum HistoryEvent: Int, CaseIterable, Hashable, Sendable {
    case bountifulHarvest, tradeCaravan, travellingScholar, ratsInTheGranary

    public var isHarmful: Bool {
        self == .ratsInTheGranary
    }

    public var title: String {
        switch self {
        case .bountifulHarvest: "Bountiful harvest"
        case .tradeCaravan: "Trade caravan"
        case .travellingScholar: "Travelling scholar"
        case .ratsInTheGranary: "Rats in the granary"
        }
    }

    public var description: String {
        switch self {
        case .bountifulHarvest: "The fields gave more than expected: 8 food reaches the stores."
        case .tradeCaravan: "A caravan passes through and pays well: +$150."
        case .travellingScholar: "A visiting scholar shares what they know: +20 knowledge."
        case .ratsInTheGranary: "Rats got into the stores: half the food is lost."
        }
    }
}

extension World {
    static let harvestFood = 8
    static let caravanPayment: Int64 = 150
    static let scholarKnowledge = 20

    public var date: GameDate {
        calendar.date(atTick: tickCount)
    }

    var isCropWinter: Bool {
        calendar.isActive && date.season == .winter
    }

    /// The event for the start of `year`, decided from the seed and the
    /// year alone so the world's own RNG is never consumed (design D4).
    public func historyEvent(forYear year: Int) -> HistoryEvent? {
        var rng = DeterministicRNG(seed: seed &+ UInt64(truncatingIfNeeded: year) &* 0x9E37_79B9_7F4A_7C15)
        guard rng.next() % 100 < difficulty.eventChancePercent else { return nil }
        // Harmful events are weighted by difficulty (design D2 of
        // `add-difficulty-and-goals`).
        let weighted = HistoryEvent.allCases.flatMap { event in
            Array(repeating: event, count: event.isHarmful ? difficulty.harmfulEventWeight : 1)
        }
        return weighted[Int(rng.next() % UInt64(weighted.count))]
    }

    public mutating func applyHistoryEvent(_ event: HistoryEvent) {
        switch event {
        case .bountifulHarvest:
            guard let buffer = goodsBuffers().first(where: { $0.state == .operational }),
                  var stockpile = stockpiles[buffer.id]
            else { return }
            let room = stockpile.capacity - stockpile.totalStored
            stockpile.deposit(.food, amount: min(Self.harvestFood, max(room, 0)))
            stockpiles[buffer.id] = stockpile
        case .tradeCaravan:
            economy.credit(Self.caravanPayment)
        case .travellingScholar:
            research.knowledge += Self.scholarKnowledge
        case .ratsInTheGranary:
            for buffer in goodsBuffers() where buffer.state == .operational {
                let food = stockpiles[buffer.id]?.quantity(of: .food) ?? 0
                stockpiles[buffer.id]?.withdraw(.food, amount: food / 2)
            }
        }
    }

    mutating func runCalendarSystem(events: inout [WorldEvent]) {
        guard tickCount > 0, tickCount.isMultiple(of: CalendarState.ticksPerSeason) else { return }
        let today = date
        events.append(.seasonChanged(today.season))
        guard calendar.isActive, tickCount.isMultiple(of: CalendarState.ticksPerYear),
              let event = historyEvent(forYear: today.year)
        else { return }
        applyHistoryEvent(event)
        events.append(.historyEvent(event))
    }
}
