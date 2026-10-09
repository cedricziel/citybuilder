import CityCore
import Foundation

/// View-model for the route-list panel. Shows every route in the
/// world, lets the player select one (which drives the polyline
/// overlay's visibility), and exposes Pause / Resume / Assign ship /
/// Delete as commands.
///
/// Spec: `sea-transport` / Requirement: Route lifecycle commands
/// (consumer side). The view itself is a thin SwiftUI list bound to
/// these mutations.
@MainActor
@Observable
public final class RouteListViewModel {
    public private(set) var selectedRouteID: EntityID?

    /// Snapshot the view-model reads routes and ships from. The session
    /// refreshes it every tick.
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
        setPaused(routeID, true)
    }

    public func resume(_ routeID: EntityID) {
        setPaused(routeID, false)
    }

    private func setPaused(_ routeID: EntityID, _ paused: Bool) {
        guard snapshot?.routes[routeID] != nil else { return }
        commandSink(.setRoutePaused(id: routeID, paused: paused))
    }

    // MARK: - Rows and ships

    /// One display row per route, in `routes` order. Spec:
    /// `platform-shells` / Routes button and route list.
    public var rows: [RouteListRow] {
        guard let snapshot else { return [] }
        var shipCounts: [EntityID: Int] = [:]
        for case let routeID? in snapshot.ships.map(\.routeID) {
            shipCounts[routeID, default: 0] += 1
        }
        return routes.enumerated().map { index, route in
            RouteListRow(route: route, position: index + 1, ships: shipCounts[route.id] ?? 0, snapshot: snapshot)
        }
    }

    private nonisolated static func isIdle(_ ship: Ship) -> Bool {
        ship.owner == .player && ship.state == .idle && ship.routeID == nil
    }

    public var idleShipCount: Int {
        snapshot?.ships.count(where: Self.isIdle) ?? 0
    }

    public var canAssignShip: Bool {
        idleShipCount > 0
    }

    /// Sends the lowest-ID idle player ship to the route. Spec:
    /// `platform-shells` / Assigning a ship to a route.
    public func assignIdleShip(to routeID: EntityID) {
        // Snapshot ships are in ID order, so the first idle one has the lowest ID.
        guard snapshot?.routes[routeID] != nil, let ship = snapshot?.ships.first(where: Self.isIdle) else { return }
        commandSink(.assignShipToRoute(shipID: ship.id, routeID: routeID))
    }
}

/// What the route list shows for one route.
public struct RouteListRow: Identifiable, Hashable, Sendable {
    public let id: EntityID
    /// "Route 2", by list position.
    public let title: String
    /// Port stops joined by " → ".
    public let stops: String
    /// "Active · 1 ship".
    public let status: String
    public let isPaused: Bool

    init(route: Route, position: Int, ships: Int, snapshot: WorldSnapshot) {
        id = route.id
        title = "Route \(position)"
        stops = route.waypoints
            .filter { if case .port = $0 { true } else { false } }
            .map { RouteStopLabel.text(for: $0, in: snapshot) }
            .joined(separator: " → ")
        let state = switch route.state {
        case .active: "Active"
        case .paused: "Paused"
        case .broken: "Broken"
        }
        status = "\(state) · \(ships) \(ships == 1 ? "ship" : "ships")"
        isPaused = route.state == .paused
    }
}

/// How a route stop reads in the overlay and the route list.
public enum RouteStopLabel {
    /// "Your port (3, 4)", "<rival>'s port" or "Sea".
    public static func text(for waypoint: Waypoint, in snapshot: WorldSnapshot) -> String {
        guard case let .port(id) = waypoint else { return "Sea" }
        guard let port = snapshot.buildings[id] else { return "Missing port" }
        if let rival = port.owner.rivalID.flatMap(snapshot.rival) {
            return "\(rival.name)'s port"
        }
        return "Your port (\(port.anchor.x), \(port.anchor.y))"
    }
}
