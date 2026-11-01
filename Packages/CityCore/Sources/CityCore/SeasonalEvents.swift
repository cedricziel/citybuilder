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
    /// The fires of a fire event under way.
    public internal(set) var fire: FireEventState?
    /// A fever under way: the residents it has sent away.
    public internal(set) var fever: ResidentsToll?
    /// A blight under way: the residents who left hungry. Nil in saves
    /// from before the toll, which then count none.
    public internal(set) var blight: ResidentsToll?
    /// The area a blight or a fever threatens, from its warning to its end.
    public internal(set) var marked: MarkedArea?
    /// A festival requested and not yet held or called off.
    public internal(set) var festival: FestivalRequest?
    /// The last tick of a festival being held. It runs on past the event,
    /// so it never blocks the next year's.
    public internal(set) var festivalUntil: UInt64?
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
    /// Buildings burnt down, residents who left with fever, or residents
    /// who left hungry in a blight.
    public let count: Int
    /// Fires that broke out; a fire event without any ends "no fire broke out".
    public let fires: Int

    public init(count: Int, fires: Int = 0) {
        self.count = count
        self.fires = fires
    }
}

/// A fire event's ignitions and the buildings burning. Spec:
/// `seasonal-events` / Fire starts, spreads and burns down.
public struct FireEventState: Codable, Hashable, Sendable {
    /// Ticks of the ignitions still to come, earliest first.
    public internal(set) var ignitionTicks: [UInt64]
    /// Ignitions so far, found a candidate or not: the next one's index.
    public internal(set) var ignitions = 0
    /// Burning buildings, in the order they caught fire.
    public internal(set) var fires: [Fire] = []
    /// Every building that caught fire in this event, in that order; none
    /// catches twice.
    public internal(set) var caught: [EntityID] = []
    public internal(set) var lost = 0
}

/// A burning building and the watchman sent to it, if any.
public struct Fire: Codable, Hashable, Sendable {
    public let building: EntityID
    public let ignitionTick: UInt64
    public internal(set) var watchman: Watchman?
}

/// A fire watch's watchman: he walks `path` one tile a tick from
/// `departureTick` and douses the fire for 30 ticks once there.
public struct Watchman: Codable, Hashable, Sendable {
    public static let douseTicks: UInt64 = 30

    public let watch: EntityID
    public let path: [TileCoordinate]
    public let departureTick: UInt64

    public var arrivalTick: UInt64 {
        departureTick + UInt64(path.count)
    }

    /// The tick the fire is out.
    public var outTick: UInt64 {
        arrivalTick + Self.douseTicks
    }
}

/// A watchman as the renderer draws him: walking `path` toward the fire, then standing on its last
/// tile while he douses it. Spec: `rendering-2_5d` / Seasonal events are drawn on the map.
public struct WatchmanWalker: Hashable, Sendable {
    /// The fire watch he comes from; one watchman per watch.
    public let watch: EntityID
    /// The burning building he answers.
    public let fire: EntityID
    public let path: [TileCoordinate]
    public let pathIndex: Int
    public let isDousing: Bool

    public init(watch: EntityID, fire: EntityID, path: [TileCoordinate], pathIndex: Int, isDousing: Bool) {
        self.watch = watch
        self.fire = fire
        self.path = path
        self.pathIndex = pathIndex
        self.isDousing = isDousing
    }

    public var currentTile: TileCoordinate? {
        path.indices.contains(pathIndex) ? path[pathIndex] : nil
    }
}

/// Running totals since the game started.
public struct SeasonalEventCounters: Codable, Hashable, Sendable {
    public internal(set) var buildingsLostToFire = 0
    public internal(set) var firesPutOut = 0
    public internal(set) var residentsLeftWithFever = 0
    /// Residents who left a house short of food while a blight was under way.
    public internal(set) var residentsLeftHungryInBlight = 0

    public init() {}

    /// Saves from before a counter have none of it.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        buildingsLostToFire = try container.decodeIfPresent(Int.self, forKey: .buildingsLostToFire) ?? 0
        firesPutOut = try container.decodeIfPresent(Int.self, forKey: .firesPutOut) ?? 0
        residentsLeftWithFever = try container.decodeIfPresent(Int.self, forKey: .residentsLeftWithFever) ?? 0
        residentsLeftHungryInBlight = try container.decodeIfPresent(Int.self, forKey: .residentsLeftHungryInBlight) ?? 0
    }
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

/// The tiles a blight or a fever threatens: everything within `radius` of
/// the footprint it was picked around (`add-event-counterplay` D6, D7).
public struct MarkedArea: Codable, Hashable, Sendable {
    public let around: TileBoundingBox
    public let radius: Int

    public init(around: TileBoundingBox, radius: Int) {
        self.around = around
        self.radius = radius
    }

    /// The building's footprint comes within the radius.
    public func contains(_ building: Building) -> Bool {
        around.gap(to: building.bounds) <= radius
    }
}

/// The residents a fever or a blight under way has sent away: with fever,
/// or hungry.
public struct ResidentsToll: Codable, Hashable, Sendable {
    public internal(set) var residentsLeft = 0
}

/// The town's two festival orders: bread, then the culture's luxury. Spec:
/// `seasonal-events` / The town asks for a festival.
public struct FestivalRequest: Codable, Hashable, Sendable {
    public let orders: [OrderID]
}
