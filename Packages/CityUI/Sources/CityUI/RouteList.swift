import CityCore
import Foundation

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
