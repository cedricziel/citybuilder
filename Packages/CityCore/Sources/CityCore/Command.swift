import Foundation

/// A player- or system-issued command queued for application at the next tick
/// boundary. Per spec `simulation-core` ("Command applied at next tick") and
/// design D2.
///
/// Cases will grow over time. M1 only needs a non-empty placeholder so the
/// enum can compile and the queue can be exercised.
public enum Command: Codable, Equatable, Sendable {
    /// No-op command. Useful for testing the queue plumbing without other side
    /// effects. Removed once real commands exist for every behavior.
    case noop

    /// Mark a forest tile as harvested. Used by world-terrain to drive the
    /// "Forest tile can be cleared" scenario.
    case harvestForest(at: TileCoordinate)

    /// Place a building of the given kind at the given anchor tile.
    /// Validation runs at tick time via `World.canPlace`; rejected
    /// placements are dropped without effect. Buildings get a freshly
    /// allocated EntityID and are recorded in `occupiedTiles`.
    case place(BuildingKind, at: TileCoordinate)

    /// A rival AI placement, applied like `place` with the rival as
    /// owner and payer. Rejections are silent. Spec: `rival-towns` /
    /// Rival turns go through the command queue.
    case rivalPlace(RivalID, BuildingKind, at: TileCoordinate)

    /// Demolish the building anchored at the given tile (if any).
    case demolish(at: TileCoordinate)

    /// Make `tech` the current research. Spec: `research` / Choosing
    /// research.
    case chooseResearch(Tech)

    // MARK: - sea-transport / Route lifecycle commands (M3)

    /// Create a new route. The command applies at the next tick
    /// boundary; if `validate(route:)` returns `.invalid` the command
    /// is dropped and no route is added.
    case createRoute(
        waypoints: [Waypoint],
        manifest: [PortID: [ManifestAction]],
        speed: Fixed
    )

    /// Replace an extant route's waypoints/manifest. Recomputes the
    /// `waypointIdx` of each assigned ship to the smallest-index
    /// waypoint in the new list that lies ahead along the new route,
    /// falling back to 0 when none qualifies.
    case editRoute(
        id: RouteID,
        waypoints: [Waypoint],
        manifest: [PortID: [ManifestAction]]
    )

    /// Remove a route. Every ship currently assigned to it transitions
    /// to `.returning`; the route is removed from world storage.
    case deleteRoute(id: RouteID)

    /// Assign an existing ship to an existing route.
    case assignShipToRoute(shipID: EntityID, routeID: RouteID)

    /// Clear the ship's route assignment. The ship transitions to
    /// `.idle` next tick.
    case unassignShip(shipID: EntityID)

    /// Pay for a commission at a gallery. Spec: `age-signatures` /
    /// Gallery commissions inspire houses.
    case commission(EntityID)
}
