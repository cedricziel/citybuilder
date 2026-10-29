import Foundation

/// The seasonal events' saved state. Spec: `seasonal-events`. Saves
/// without it decode the default (see the `KeyedDecodingContainer` overload
/// below): events off, nothing planned, warned or under way.
public struct SeasonalEventsState: Codable, Hashable, Sendable {
    /// The New Game toggle. Off by default, so fixtures and old saves tick
    /// as before.
    public internal(set) var enabled = false
    /// False when a chapter turns the random draw off (`add-event-counterplay` D9).
    public internal(set) var randomEvents = true
    /// A chapter's events, which replace their year's draw and run whatever
    /// `enabled` says. One whose onset isn't among its event's seasons could
    /// never start, so it is dropped.
    public internal(set) var schedule: [ScheduledSeasonalEvent] = [] {
        didSet {
            if !schedule.allSatisfy(\.isValid) {
                schedule = schedule.filter(\.isValid)
            }
        }
    }

    /// This year's decision, stored when it is made so an age change or a
    /// reload never redraws it.
    public internal(set) var plan: SeasonalEventPlan?
    /// A hazard warned for next season.
    public internal(set) var warned: SeasonalEventOnset?
    /// The event under way.
    public internal(set) var active: ActiveSeasonalEvent?
    public internal(set) var counters = SeasonalEventCounters()

    public init() {}

    /// True while an event is warned or under way.
    public var isBusy: Bool {
        warned != nil || active != nil
    }
}

extension KeyedDecodingContainer {
    /// Saves written before seasonal events have none.
    /// A save's schedule entries that could never start are dropped, so it
    /// still loads.
    func decode(_ type: SeasonalEventsState.Type, forKey key: Key) throws -> SeasonalEventsState {
        var state = try decodeIfPresent(type, forKey: key) ?? SeasonalEventsState()
        state.schedule = state.schedule.filter(\.isValid)
        return state
    }
}

/// An event a chapter puts in a year, with its onset season.
public struct ScheduledSeasonalEvent: Codable, Hashable, Sendable {
    public let year: Int
    public let event: SeasonalEvent
    public let onset: Season

    public init(year: Int, event: SeasonalEvent, onset: Season) {
        self.year = year
        self.event = event
        self.onset = onset
    }

    /// The onset is one of the event's seasons.
    public var isValid: Bool {
        event.seasons.contains(onset)
    }
}

/// The decision for a year: an event and its onset season, or none.
public struct SeasonalEventPlan: Codable, Hashable, Sendable {
    public let year: Int
    public let onset: SeasonalEventOnset?
}

/// An event and the season it starts in.
public struct SeasonalEventOnset: Codable, Hashable, Sendable {
    public let event: SeasonalEvent
    public let season: Season

    public init(event: SeasonalEvent, season: Season) {
        self.event = event
        self.season = season
    }
}

/// An event under way, and the tick it ends on at the latest.
public struct ActiveSeasonalEvent: Codable, Hashable, Sendable {
    public let event: SeasonalEvent
    public let startTick: UInt64
    public let lastTick: UInt64
}

/// What the town lost to an event, for its end banner.
public struct SeasonalEventToll: Hashable, Sendable {
    /// Buildings burnt down, or residents who left with fever.
    public let count: Int

    public init(count: Int) {
        self.count = count
    }
}

/// Running totals since the game started.
public struct SeasonalEventCounters: Codable, Hashable, Sendable {
    public internal(set) var buildingsLostToFire = 0
    public internal(set) var firesPutOut = 0
    public internal(set) var residentsLeftWithFever = 0

    public init() {}
}

/// The difficulty's seasonal-event knobs. Spec: `difficulty-and-goals` /
/// Difficulty shapes seasonal events.
public extension Difficulty {
    /// Chance in percent that a year has a seasonal event.
    var seasonalEventChancePercent: UInt64 {
        switch self {
        case .easy: 35
        case .normal: 50
        case .hard: 65
        }
    }

    /// The first year with a seasonal event; the start year is year 1.
    var firstSeasonalEventYear: Int {
        self == .easy ? 4 : 3
    }

    var firesPerFireEvent: Int {
        self == .hard ? 2 : 1
    }

    var fireSpreadTicks: UInt64 {
        switch self {
        case .easy: 200
        case .normal: 150
        case .hard: 100
        }
    }

    var feverLeaveTicks: UInt64 {
        switch self {
        case .easy: 300
        case .normal: 200
        case .hard: 150
        }
    }

    var festivalWindowSeasons: Int {
        self == .easy ? 2 : 1
    }

    var festivalTaxBonusPercent: Int {
        self == .easy ? 15 : 10
    }
}
