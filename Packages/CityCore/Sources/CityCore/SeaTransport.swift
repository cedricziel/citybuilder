import Foundation

/// A reference to a port building. Same shape as `EntityID` — this
/// alias documents the *intent* at the call site so route validation
/// signatures read clearly.
public typealias PortID = EntityID

/// An identifier for a route.
public typealias RouteID = EntityID

/// Catalog metadata for a ship class — capacity, base speed, etc. The
/// `default` class is enough scaffolding for M2; M5 may grow this into
/// a real `ShipCatalog` once multiple classes are spec'd.
public struct ShipClass: Hashable, Codable, Sendable {
    public let capacity: Int
    public let baseSpeed: Fixed

    public init(capacity: Int, baseSpeed: Fixed) {
        self.capacity = capacity
        self.baseSpeed = baseSpeed
    }

    public static let `default` = ShipClass(
        capacity: 100,
        baseSpeed: Fixed(raw: 2048) // 0.5 tiles per tick (spec default)
    )
}

/// State machine value for a ship. Allowed transitions are documented
/// in spec `sea-transport` / Requirement: Ship state machine; the M5
/// `tickShips` system enforces them.
public enum ShipState: Hashable, Codable, Sendable {
    case idle
    case sailing
    case docked
    case returning
}

/// A continuous-position entity moving over water. Position lives in
/// `Fixed` coordinates anchored to the same grid as terrain tiles
/// (1.0 unit = 1 tile). All tick-time motion math goes through `Fixed`
/// arithmetic so two simulations with identical inputs produce
/// byte-identical state across Apple and Linux toolchains.
public struct Ship: Hashable, Codable, Sendable {
    public let id: EntityID
    public var position: Fixed2D
    public var heading: Fixed
    public var routeID: RouteID?
    public var waypointIdx: Int
    public var cargo: [Good: Int]
    public var state: ShipState
    public var shipClass: ShipClass
    /// Index of the manifest action being executed at the current
    /// `.docked` port. Resumes mid-manifest after load.
    public var dockedManifestIndex: Int
    /// Ticks waited at the current `.docked` port for the dock-timeout
    /// policy. Reset on entering `.docked`, ticked by the M5 system,
    /// persisted so a load mid-wait resumes the countdown.
    public var dockedTicksWaited: Int
    /// Spec: `sea-transport` / Ships have an owner.
    public internal(set) var owner: Owner

    public init(
        id: EntityID,
        position: Fixed2D,
        heading: Fixed,
        routeID: RouteID?,
        waypointIdx: Int,
        cargo: [Good: Int],
        state: ShipState,
        shipClass: ShipClass,
        dockedManifestIndex: Int = 0,
        dockedTicksWaited: Int = 0,
        owner: Owner = .player
    ) {
        self.id = id
        self.position = position
        self.heading = heading
        self.routeID = routeID
        self.waypointIdx = waypointIdx
        self.cargo = cargo
        self.state = state
        self.shipClass = shipClass
        self.dockedManifestIndex = dockedManifestIndex
        self.dockedTicksWaited = dockedTicksWaited
        self.owner = owner
    }
}

public extension Ship {
    /// Reads a missing `owner` (saves before rivals) as the player's.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(EntityID.self, forKey: .id)
        self.position = try container.decode(Fixed2D.self, forKey: .position)
        self.heading = try container.decode(Fixed.self, forKey: .heading)
        self.routeID = try container.decodeIfPresent(RouteID.self, forKey: .routeID)
        self.waypointIdx = try container.decode(Int.self, forKey: .waypointIdx)
        self.cargo = try container.decode([Good: Int].self, forKey: .cargo)
        self.state = try container.decode(ShipState.self, forKey: .state)
        self.shipClass = try container.decode(ShipClass.self, forKey: .shipClass)
        self.dockedManifestIndex = try container.decode(Int.self, forKey: .dockedManifestIndex)
        self.dockedTicksWaited = try container.decode(Int.self, forKey: .dockedTicksWaited)
        self.owner = try container.decodeIfPresent(Owner.self, forKey: .owner) ?? .player
    }
}

/// A single point in a route's polyline — either an open-water steering
/// point in `Fixed` coordinates or a port reference. The M3 validator
/// checks that `.sea` points lie on water tiles and that `.port` ids
/// resolve to extant port buildings.
public enum Waypoint: Hashable, Codable, Sendable {
    case sea(position: Fixed2D)
    case port(id: PortID)
}

/// A single per-port manifest entry executed when a ship docks. Two
/// verbs in v0 per spec (`loadUpTo`, `unloadUpTo`); a third
/// `waitUntilFull` was considered and deferred.
public enum ManifestAction: Hashable, Codable, Sendable {
    case loadUpTo(good: Good, qty: Int)
    case unloadUpTo(good: Good, qty: Int)
}

/// State machine value for a route. M3 introduces validation; routes
/// transition to `.broken` if `validate(route:)` flips from `.valid`
/// (e.g. a port referenced by a `.port(id:)` waypoint is demolished).
public enum RouteState: Hashable, Codable, Sendable {
    case active
    case paused
    case broken(reason: BrokenReason)

    public enum BrokenReason: Hashable, Codable, Sendable {
        case segmentCrossesLand(segmentIndex: Int)
        case unknownPort(portID: PortID)
        case fewerThanTwoPorts
    }
}

/// A route entity persists independently of any ship. Ships are
/// assigned to it; if all assigned ships are destroyed the route
/// remains for re-assignment. Waypoints and manifest are editable
/// while ships are en route — the M3 EditRoute command recomputes
/// each assigned ship's `waypointIdx`.
public struct Route: Hashable, Codable, Sendable {
    public let id: RouteID
    public var waypoints: [Waypoint]
    public var manifest: [PortID: [ManifestAction]]
    public var speed: Fixed
    public var state: RouteState

    public init(
        id: RouteID,
        waypoints: [Waypoint],
        manifest: [PortID: [ManifestAction]],
        speed: Fixed,
        state: RouteState
    ) {
        self.id = id
        self.waypoints = waypoints
        self.manifest = manifest
        self.speed = speed
        self.state = state
    }
}
