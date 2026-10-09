import CityCore
import Foundation

/// Tap target classification surfaced from the scene to the
/// route-authoring view-model. The scene finds the tapped tile via
/// `IsoMath.nearestTile` and `resolve` classifies it; the view-model
/// only sees the resolved target.
public enum RouteAuthoringTapTarget: Hashable, Sendable {
    case port(id: EntityID)
    case water(tile: TileCoordinate)
    case land(tile: TileCoordinate)
}

public extension RouteAuthoringTapTarget {
    /// A port of any owner, else water or land. Spec: `platform-shells`
    /// / Buy and Sell in the manifest editor (rival ports are tappable).
    static func resolve(tile: TileCoordinate, in snapshot: WorldSnapshot) -> RouteAuthoringTapTarget {
        if let id = snapshot.occupiedTiles[tile], snapshot.buildings[id]?.kind == .port {
            return .port(id: id)
        }
        return snapshot.terrain(at: tile) == .water ? .water(tile: tile) : .land(tile: tile)
    }
}

/// Visual-feedback signal the view-model raises when a tap is
/// rejected. The scene reads it on the next render frame to draw a
/// red flash at `location`, then clears it via
/// `consumeRejectedTapFeedback()`. Persisted-feedback design avoids
/// coupling the view-model to a SwiftUI publisher.
public struct RejectedTapFeedback: Hashable, Sendable {
    public let location: TileCoordinate
    public let issuedAtTick: UInt64

    public init(location: TileCoordinate, issuedAtTick: UInt64) {
        self.location = location
        self.issuedAtTick = issuedAtTick
    }
}

/// View-model for the route-authoring input mode. The scene calls
/// `tapHandler(target:)` for each tap; the SwiftUI overlay drives
/// `commit()` / `cancel()`. The renderer reads
/// `inProgressWaypoints` + `redSegments` to draw the live polyline
/// (M8 `RoutePolylineProjector` projects the points; this view-model
/// supplies the source-of-truth waypoint sequence).
///
/// Spec: `rendering-2_5d` / Requirement: Route-authoring input mode.
@MainActor
@Observable
public final class RouteAuthoringViewModel {
    public private(set) var inProgressWaypoints: [Waypoint] = []
    /// Indices into `inProgressWaypoints` whose outgoing segment to
    /// the next waypoint crosses land. The renderer strokes these
    /// segments in red.
    public private(set) var redSegments: Set<Int> = []
    /// Last rejected tap, consumed by the scene to draw a red flash.
    public private(set) var rejectedTapFeedback: RejectedTapFeedback?

    /// Per-port manifest the player has authored inside this mode.
    /// `commit()` packages it into the `CreateRoute` command.
    public private(set) var manifest: [PortID: [ManifestAction]] = [:]

    /// Speed used in the issued `CreateRoute` command. Defaults to
    /// the ship class default so the issued route runs at sensible
    /// pace; the manifest-editor sheet may override.
    public var speed: Fixed = ShipClass.default.baseSpeed

    /// Snapshot the view-model uses to validate taps (water-tile
    /// detection, segment crossing). The session refreshes this on
    /// every render frame.
    public var snapshot: WorldSnapshot?

    /// Sink the view-model uses to enqueue commands. Injected by the
    /// session shell so tests can pass a no-op or a recorder.
    public var commandSink: (Command) -> Void

    /// Reason the most recent `commit()` was rejected, surfaced to
    /// the SwiftUI overlay as a validation banner.
    public private(set) var commitRejectionReason: CommitRejection?

    public enum CommitRejection: String, Hashable, Sendable {
        case fewerThanTwoPorts = "fewer_than_two_ports"
        case landCrossingSegment = "land_crossing_segment"
    }

    public init(commandSink: @escaping (Command) -> Void = { _ in }) {
        self.commandSink = commandSink
    }

    // MARK: - Tap handling

    public func tapHandler(target: RouteAuthoringTapTarget) {
        commitRejectionReason = nil
        switch target {
        case let .port(id):
            inProgressWaypoints.append(.port(id: id))
            recomputeRedSegments()
        case let .water(tile):
            let pos = Fixed2D(x: Fixed(Int32(tile.x)), y: Fixed(Int32(tile.y)))
            inProgressWaypoints.append(.sea(position: pos))
            recomputeRedSegments()
        case let .land(tile):
            // Land taps are rejected with a red-flash signal at the
            // tap location. The in-progress route is unchanged.
            rejectedTapFeedback = RejectedTapFeedback(
                location: tile,
                issuedAtTick: snapshot?.tickCount ?? 0
            )
        }
    }

    public func consumeRejectedTapFeedback() -> RejectedTapFeedback? {
        let consumed = rejectedTapFeedback
        rejectedTapFeedback = nil
        return consumed
    }

    // MARK: - Commit / cancel

    public func commit() {
        guard let snapshot else { return }
        let portWaypoints = inProgressWaypoints.compactMap { waypoint -> EntityID? in
            if case let .port(id) = waypoint { return id }
            return nil
        }
        guard portWaypoints.count >= 2 else {
            commitRejectionReason = .fewerThanTwoPorts
            return
        }
        recomputeRedSegments(in: snapshot)
        guard redSegments.isEmpty else {
            commitRejectionReason = .landCrossingSegment
            return
        }
        commandSink(.createRoute(
            waypoints: inProgressWaypoints,
            manifest: manifest,
            speed: speed
        ))
        reset()
    }

    public func cancel() {
        reset()
    }

    private func reset() {
        inProgressWaypoints.removeAll()
        redSegments.removeAll()
        manifest.removeAll()
        commitRejectionReason = nil
        rejectedTapFeedback = nil
    }

    // MARK: - Manifest editing

    public func setManifest(_ actions: [ManifestAction], forPort port: EntityID) {
        if actions.isEmpty {
            manifest.removeValue(forKey: port)
        } else {
            manifest[port] = actions
        }
    }

    // MARK: - Validation

    public func recomputeRedSegments() {
        guard let snapshot else { return }
        recomputeRedSegments(in: snapshot)
    }

    private func recomputeRedSegments(in snapshot: WorldSnapshot) {
        redSegments.removeAll()
        for idx in 0 ..< max(0, inProgressWaypoints.count - 1) {
            let start = RoutePolylineProjectorPosition.position(
                for: inProgressWaypoints[idx], snapshot: snapshot
            )
            let end = RoutePolylineProjectorPosition.position(
                for: inProgressWaypoints[idx + 1], snapshot: snapshot
            )
            if segmentCrossesLand(from: start, to: end, snapshot: snapshot) {
                redSegments.insert(idx)
            }
        }
    }

    /// Sub-tile-step (0.25 tile) sampler used by the M3 validator
    /// inside CityCore; replicated here in scene coordinates so the
    /// live overlay can recompute per-tap without an extra
    /// round-trip through the simulation.
    private func segmentCrossesLand(
        from start: Fixed2D, to end: Fixed2D, snapshot: WorldSnapshot
    ) -> Bool {
        let stepRaw: Int32 = 1024
        let dx = Int64(end.x.raw) - Int64(start.x.raw)
        let dy = Int64(end.y.raw) - Int64(start.y.raw)
        let lenSquared = dx * dx + dy * dy
        let lenRaw = Int64(approxSqrt(lenSquared))
        let samples = max(1, Int((lenRaw + Int64(stepRaw) - 1) / Int64(stepRaw)))
        for sampleIdx in 0 ... samples {
            let tRaw = Int64(sampleIdx) * Int64(Fixed.scale) / Int64(samples)
            let oneMinusT = Int64(Fixed.scale) - tRaw
            let pointX = (Int64(start.x.raw) * oneMinusT + Int64(end.x.raw) * tRaw)
                / Int64(Fixed.scale)
            let pointY = (Int64(start.y.raw) * oneMinusT + Int64(end.y.raw) * tRaw)
                / Int64(Fixed.scale)
            let tileX = Int(pointX / Int64(Fixed.scale))
            let tileY = Int(pointY / Int64(Fixed.scale))
            let coord = TileCoordinate(x: tileX, y: tileY)
            guard let terrain = snapshot.terrain(at: coord) else { continue }
            if terrain != .water { return true }
        }
        return false
    }

    private func approxSqrt(_ value: Int64) -> Int64 {
        guard value > 0 else { return 0 }
        var current = value
        var next = (current + 1) / 2
        while next < current {
            current = next
            next = (current + value / current) / 2
        }
        return current
    }
}

/// View-model for the route-list panel. Shows every route in the
/// world, lets the player select one (which drives the M8 polyline
/// overlay's visibility), and exposes `Edit` / `Pause` / `Resume` /
/// `Delete` affordances that translate to the existing M3 command
/// set.
///
/// Spec: `sea-transport` / Requirement: Route lifecycle commands
/// (consumer side). The view itself is a thin SwiftUI list bound to
/// these mutations.
@MainActor
@Observable
public final class RouteListViewModel {
    public private(set) var selectedRouteID: EntityID?

    /// Snapshot the view-model reads from. The session refreshes it
    /// per render frame; the view-model only walks the `routes` dict.
    public var snapshot: WorldSnapshot?

    /// Sink the view-model uses to enqueue lifecycle commands.
    public var commandSink: (Command) -> Void

    public init(commandSink: @escaping (Command) -> Void = { _ in }) {
        self.commandSink = commandSink
    }

    /// All routes in deterministic ID order so the SwiftUI list does
    /// not jitter between snapshots.
    public var routes: [Route] {
        guard let snapshot else { return [] }
        return snapshot.routes.values.sorted { $0.id.raw < $1.id.raw }
    }

    public func select(_ routeID: EntityID?) {
        // Deselection clears; selecting a non-existent route is a no-op.
        guard let routeID else { selectedRouteID = nil; return }
        guard snapshot?.routes[routeID] != nil else { return }
        selectedRouteID = routeID
    }

    public func delete(_ routeID: EntityID) {
        guard snapshot?.routes[routeID] != nil else { return }
        commandSink(.deleteRoute(id: routeID))
        if selectedRouteID == routeID { selectedRouteID = nil }
    }

    public func pause(_ routeID: EntityID) {
        guard let snapshot, var route = snapshot.routes[routeID] else { return }
        route.state = .paused
        // Pause is modeled as an `editRoute` that preserves waypoints
        // + manifest but transitions state. The M3 apply path picks
        // up the new state on the next tick.
        commandSink(.editRoute(
            id: routeID, waypoints: route.waypoints, manifest: route.manifest
        ))
    }

    public func resume(_ routeID: EntityID) {
        guard let snapshot, var route = snapshot.routes[routeID] else { return }
        route.state = .active
        commandSink(.editRoute(
            id: routeID, waypoints: route.waypoints, manifest: route.manifest
        ))
    }
}

/// Stand-in for `CityRender2D.RoutePolylineProjector.position(for:)`.
/// Re-implemented here so CityUI does not have to depend on
/// CityRender2D (which links SpriteKit and is iOS/macOS-only). The
/// logic is identical: `.sea` returns the literal Fixed2D; `.port`
/// resolves to the building's recorded `shipAnchor` (or `anchor` as a
/// fallback) via the snapshot.
enum RoutePolylineProjectorPosition {
    static func position(for waypoint: Waypoint, snapshot: WorldSnapshot) -> Fixed2D {
        switch waypoint {
        case let .sea(pos):
            return pos
        case let .port(id):
            guard let building = snapshot.buildings[id] else { return .zero }
            let anchor = building.shipAnchor ?? building.anchor
            return Fixed2D(x: Fixed(Int32(anchor.x)), y: Fixed(Int32(anchor.y)))
        }
    }
}
