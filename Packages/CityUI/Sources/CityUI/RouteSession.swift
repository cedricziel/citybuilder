import CityCore
import Foundation

/// What the scene draws for routes: the in-progress route in route
/// mode, else the selected route. Spec: `rendering-2_5d` / Route overlay
/// from the session.
public struct RouteOverlay: Equatable, Sendable {
    public let waypoints: [Waypoint]
    /// Indices of segments that cross land, drawn red.
    public let redSegments: Set<Int>
    /// A rejected land tap to flash, reported once.
    public let flash: TileCoordinate?

    public init(waypoints: [Waypoint], redSegments: Set<Int> = [], flash: TileCoordinate? = nil) {
        self.waypoints = waypoints
        self.redSegments = redSegments
        self.flash = flash
    }
}

/// Route mode on the session (design D1). Spec: `platform-shells` /
/// Route mode.
public extension GameSession {
    /// The HUD offers routes once the player has a port or a ship, or a
    /// route exists.
    var showsRoutesButton: Bool {
        !world.routes.isEmpty
            || world.ships.values.contains { $0.owner == .player }
            || world.buildings.values.contains { $0.kind == .port && $0.owner == .player }
    }

    /// Enters route mode, optionally starting at `port`.
    func beginRouteAuthoring(from port: EntityID? = nil) {
        pendingPlacement = nil
        tileMenuRequest = nil
        selectedTool = .inspect
        routeList.select(nil)
        let authoring = RouteAuthoringViewModel { [weak self] in self?.world.enqueue($0) }
        authoring.snapshot = world.snapshot()
        if let port {
            authoring.tapHandler(target: .port(id: port))
        }
        routeAuthoring = authoring
    }

    func commitRouteAuthoring() {
        if routeAuthoring?.commit() == true {
            routeAuthoring = nil
        }
    }

    func cancelRouteAuthoring() {
        routeAuthoring = nil
    }

    /// The route overlay for this frame; consumes a rejected-tap flash.
    func routeOverlay() -> RouteOverlay? {
        if let routeAuthoring {
            return RouteOverlay(
                waypoints: routeAuthoring.inProgressWaypoints,
                redSegments: routeAuthoring.redSegments,
                flash: routeAuthoring.consumeRejectedTapFeedback()?.location
            )
        }
        guard let id = routeList.selectedRouteID, let route = world.routes[id] else { return nil }
        return RouteOverlay(waypoints: route.waypoints)
    }
}

extension GameSession {
    func handleRouteTap(at tile: TileCoordinate) {
        guard let routeAuthoring, let snapshot = routeAuthoring.snapshot else { return }
        routeAuthoring.tapHandler(target: .resolve(tile: tile, in: snapshot))
    }
}
