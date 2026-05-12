import Foundation

/// Result of `World.validate(route:)`. `.valid` is the "good" branch;
/// `.invalid` carries one of the `RouteState.BrokenReason` cases the
/// route would transition to if applied.
public enum RouteValidationResult: Hashable, Sendable {
    case valid
    case invalid(RouteState.BrokenReason)
}

public extension World {
    /// Pure, deterministic check that a candidate route satisfies all
    /// rules needed to be `.active`. No side effects on the world.
    /// Spec: `sea-transport` / Requirement: Route validation.
    func validate(route: Route) -> RouteValidationResult {
        // 1. At least two `.port` waypoints.
        let portCount = route.waypoints.reduce(0) { count, waypoint in
            if case .port = waypoint { return count + 1 }
            return count
        }
        if portCount < 2 { return .invalid(.fewerThanTwoPorts) }

        // 2. Every `.port(id:)` references an extant port building.
        for waypoint in route.waypoints {
            if case let .port(id) = waypoint, !isPortBuilding(id: id) {
                return .invalid(.unknownPort(portID: id))
            }
        }

        // 3. Every segment between consecutive waypoints stays on water.
        //    Sub-tile sampling at step ≤ 0.25 tile so a corner-crossing
        //    diagonal is detected (spec scenario: segment sampling
        //    resolution is sub-tile).
        for segmentIdx in 0 ..< max(0, route.waypoints.count - 1) {
            let start = waypointPosition(route.waypoints[segmentIdx])
            let end = waypointPosition(route.waypoints[segmentIdx + 1])
            if segmentCrossesLand(from: start, to: end) {
                return .invalid(.segmentCrossesLand(segmentIndex: segmentIdx))
            }
        }

        return .valid
    }

    /// True when `id` resolves to a port-kind building. M3 stand-in:
    /// any extant building counts. M4 will narrow this to
    /// `buildings[id]?.kind == .port` once `.port` lands as a real
    /// BuildingKind.
    func isPortBuilding(id: EntityID) -> Bool {
        buildings[id] != nil
    }

    /// Anchor position of a waypoint in Fixed2D space. For `.port` we
    /// use the building's anchor tile.
    func waypointPosition(_ waypoint: Waypoint) -> Fixed2D {
        switch waypoint {
        case let .sea(pos):
            return pos
        case let .port(id):
            guard let anchor = buildings[id]?.anchor else { return .zero }
            return Fixed2D(
                x: Fixed(Int32(anchor.x)),
                y: Fixed(Int32(anchor.y))
            )
        }
    }

    private func segmentCrossesLand(from start: Fixed2D, to end: Fixed2D) -> Bool {
        // Sample at 0.25-tile increments along the segment. Total
        // sample count = ceil(length / 0.25); length computed in
        // Fixed via Fixed2D.distance.
        let length = start.distance(to: end)
        // step in raw Fixed units = 0.25 tile = 1024.
        let stepRaw: Int32 = 1024
        // Number of samples (inclusive of endpoints) = ceil(length / step).
        let lenRaw = Int64(length.raw)
        let samples = max(1, Int((lenRaw + Int64(stepRaw) - 1) / Int64(stepRaw)))
        for sampleIdx in 0 ... samples {
            // t = sampleIdx / samples, in Fixed.
            let tRaw = Int64(sampleIdx) * Int64(Fixed.scale) / Int64(samples)
            let oneMinusT = Int64(Fixed.scale) - tRaw
            let px = (Int64(start.x.raw) * oneMinusT + Int64(end.x.raw) * tRaw) / Int64(Fixed.scale)
            let py = (Int64(start.y.raw) * oneMinusT + Int64(end.y.raw) * tRaw) / Int64(Fixed.scale)
            let tileX = Int(px / Int64(Fixed.scale))
            let tileY = Int(py / Int64(Fixed.scale))
            guard contains(TileCoordinate(x: tileX, y: tileY)) else { continue }
            let kind = terrainGrid[tileY * mapWidth + tileX]
            if kind != .water { return true }
        }
        return false
    }
}

// MARK: - Command application (M3 lifecycle commands)

extension World {
    mutating func applyCreateRoute(
        waypoints: [Waypoint],
        manifest: [PortID: [ManifestAction]],
        speed: Fixed
    ) {
        let candidate = Route(
            id: EntityID(raw: nextEntityRaw),
            waypoints: waypoints,
            manifest: manifest,
            speed: speed,
            state: .active
        )
        guard case .valid = validate(route: candidate) else { return }
        nextEntityRaw &+= 1
        routes[candidate.id] = candidate
    }

    mutating func applyEditRoute(
        id: RouteID,
        waypoints: [Waypoint],
        manifest: [PortID: [ManifestAction]]
    ) {
        guard var route = routes[id] else { return }
        let candidate = Route(
            id: id,
            waypoints: waypoints,
            manifest: manifest,
            speed: route.speed,
            state: route.state
        )
        guard case .valid = validate(route: candidate) else { return }
        route.waypoints = waypoints
        route.manifest = manifest
        routes[id] = route
        // Recompute waypoint indices for every ship assigned to this
        // route. The spec wants the smallest-index waypoint that lies
        // ahead of the ship; a heading-aware dot-product check picks
        // it, falling back to 0 when nothing qualifies.
        struct Assigned { let id: EntityID; let position: Fixed2D; let heading: Fixed }
        let assignments: [Assigned] = ships.compactMap { shipID, ship in
            ship.routeID == id
                ? Assigned(id: shipID, position: ship.position, heading: ship.heading)
                : nil
        }
        var newIdxByShip: [EntityID: Int] = [:]
        for entry in assignments {
            newIdxByShip[entry.id] = nextWaypointIdx(
                forShipAt: entry.position,
                heading: entry.heading,
                waypoints: waypoints
            )
        }
        for (shipID, newIdx) in newIdxByShip {
            ships[shipID]?.waypointIdx = newIdx
        }
    }

    mutating func applyDeleteRoute(id: RouteID) {
        guard routes[id] != nil else { return }
        routes.removeValue(forKey: id)
        for (shipID, ship) in ships where ship.routeID == id {
            ships[shipID]?.state = .returning
        }
    }

    mutating func applyAssignShipToRoute(shipID: EntityID, routeID: RouteID) {
        guard routes[routeID] != nil, ships[shipID] != nil else { return }
        ships[shipID]?.routeID = routeID
        ships[shipID]?.waypointIdx = 0
        ships[shipID]?.state = .sailing
    }

    mutating func applyUnassignShip(shipID: EntityID) {
        guard ships[shipID] != nil else { return }
        ships[shipID]?.routeID = nil
        ships[shipID]?.state = .idle
    }

    private func nextWaypointIdx(
        forShipAt position: Fixed2D,
        heading: Fixed,
        waypoints: [Waypoint]
    ) -> Int {
        let headingDir = Fixed2D(x: Fixed.cos(heading), y: Fixed.sin(heading))
        for (idx, waypoint) in waypoints.enumerated() {
            let toWaypoint = waypointPosition(waypoint) - position
            if (toWaypoint.dot(headingDir)).raw > 0 { return idx }
        }
        return 0
    }
}
