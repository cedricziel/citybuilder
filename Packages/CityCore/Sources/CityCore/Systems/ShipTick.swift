import Foundation

// Per-tick ship integration + state machine + dock manifest execution.
// Spec: `sea-transport`, Requirements: Ship state machine, Per-tick
// ship integration, Dock timeout policy, Manifest actions.
//
// All arithmetic on the tick path uses `Fixed`; the SwiftLint
// `tick_float_ban` rule scopes to this directory and forbids
// `Float` / `Double` / `CGFloat` here.

public extension World {
    /// Arrival epsilon — a ship within this distance of its target
    /// waypoint counts as having arrived. `0.25` tile in `Fixed`.
    static let shipArrivalEpsilon = Fixed(raw: 1024)

    /// Default dock timeout — a docked ship that cannot make any
    /// progress on its current manifest action waits at most this
    /// many ticks before skipping the action. 3000 ticks = 5
    /// simulated minutes at 10 Hz.
    static let shipDockTimeout = 3000

    /// Per-tick ship system. Drives the four-state machine, ship
    /// integration, dock manifest execution, and the
    /// route-broken / returning transitions. Called once per tick
    /// after building advance and before economy.
    mutating func runShipSystem() {
        // Snapshot ship IDs at the start of the tick so additions
        // mid-system (the ship-emission factory invoked elsewhere)
        // do not race with the iteration.
        let shipIDs = ships.keys.sorted { $0.raw < $1.raw }
        for shipID in shipIDs {
            guard var ship = ships[shipID] else { continue }
            tickShip(&ship)
            ships[shipID] = ship
        }
    }

    private mutating func tickShip(_ ship: inout Ship) {
        // Route-broken detection: a `.sailing` ship whose route is no
        // longer `.active` transitions to `.returning`.
        if ship.state == .sailing, let routeID = ship.routeID {
            if let route = routes[routeID], case .broken = route.state {
                ship.state = .returning
            }
        }

        switch ship.state {
        case .idle:
            // No-op. The Assign command flips to .sailing.
            return
        case .sailing:
            tickShipSailing(&ship)
        case .docked:
            tickShipDocked(&ship)
        case .returning:
            tickShipReturning(&ship)
        }
    }

    private mutating func tickShipSailing(_ ship: inout Ship) {
        guard let routeID = ship.routeID, let route = routes[routeID] else { return }
        guard !route.waypoints.isEmpty else { return }
        let idx = ((ship.waypointIdx % route.waypoints.count) + route.waypoints.count)
            % route.waypoints.count
        let waypoint = route.waypoints[idx]
        let target = shipTargetPosition(for: waypoint)
        moveShip(&ship, toward: target, speed: route.speed)
        if ship.position.distance(to: target) <= Self.shipArrivalEpsilon {
            // Arrived at the waypoint.
            if case .port = waypoint {
                ship.state = .docked
                ship.dockedManifestIndex = 0
                ship.dockedTicksWaited = 0
            } else {
                ship.waypointIdx = (idx + 1) % route.waypoints.count
            }
        }
    }

    private mutating func tickShipDocked(_ ship: inout Ship) {
        guard let routeID = ship.routeID, let route = routes[routeID] else {
            // Route disappeared mid-dock — flip to returning.
            ship.state = .returning
            return
        }
        guard !route.waypoints.isEmpty else { return }
        let idx = ((ship.waypointIdx % route.waypoints.count) + route.waypoints.count)
            % route.waypoints.count
        guard case let .port(portID) = route.waypoints[idx] else {
            // Should not happen — sailing only docks on .port waypoints.
            ship.state = .sailing
            return
        }
        let actions = route.manifest[portID] ?? []
        // Drain the manifest until either it's exhausted or the current
        // action stalls. The same-docking-turn rule (spec scenario
        // "manifest actions execute in declared order") means an
        // unload that frees capacity lets a subsequent load proceed
        // without waiting another tick.
        var drainedThisTick = false
        while ship.dockedManifestIndex < actions.count {
            let action = actions[ship.dockedManifestIndex]
            let progressed = applyManifestAction(action, ship: &ship, portID: portID)
            if progressed {
                ship.dockedManifestIndex &+= 1
                ship.dockedTicksWaited = 0
                drainedThisTick = true
            } else {
                ship.dockedTicksWaited &+= 1
                if ship.dockedTicksWaited >= Self.shipDockTimeout {
                    ship.dockedManifestIndex &+= 1
                    ship.dockedTicksWaited = 0
                    drainedThisTick = true
                }
                break
            }
        }
        if ship.dockedManifestIndex >= actions.count {
            // Manifest exhausted (or never existed) — sail to next.
            ship.state = .sailing
            ship.waypointIdx = (idx + 1) % route.waypoints.count
            ship.dockedManifestIndex = 0
            ship.dockedTicksWaited = 0
        }
        _ = drainedThisTick
    }

    private mutating func tickShipReturning(_ ship: inout Ship) {
        // Find nearest port (by Fixed distance). Tie-break by EntityID
        // for determinism. Ports are the only valid drop-off.
        let portList = buildings.values
            .filter { $0.kind == .port }
            .sorted { $0.id.raw < $1.id.raw }
        guard !portList.isEmpty else {
            // No ports remain — idle the ship in place.
            ship.state = .idle
            ship.routeID = nil
            return
        }
        var nearest = portList[0]
        var nearestDist = ship.position.distance(to: portShipPosition(nearest))
        for candidate in portList.dropFirst() {
            let dist = ship.position.distance(to: portShipPosition(candidate))
            if dist < nearestDist {
                nearestDist = dist
                nearest = candidate
            }
        }
        let target = portShipPosition(nearest)
        moveShip(&ship, toward: target, speed: ship.shipClass.baseSpeed)
        if ship.position.distance(to: target) <= Self.shipArrivalEpsilon {
            ship.state = .idle
            ship.routeID = nil
            ship.dockedManifestIndex = 0
            ship.dockedTicksWaited = 0
        }
    }

    // MARK: - Integration helpers

    /// Advance `ship.position` toward `target` by at most `speed` (in
    /// Fixed tiles-per-tick). Snaps to the target if the remaining
    /// distance is ≤ speed. Updates `ship.heading` via `Fixed.atan2`.
    private func moveShip(_ ship: inout Ship, toward target: Fixed2D, speed: Fixed) {
        let delta = target - ship.position
        let distance = ship.position.distance(to: target)
        if distance.raw == 0 { return }
        // Heading first so an arrived-this-tick ship still reflects
        // the direction it was traveling.
        ship.heading = Fixed.atan2(delta.y, delta.x)
        if speed.raw >= distance.raw {
            ship.position = target
            return
        }
        // step = (delta / distance) * speed, in raw Int64 to avoid
        // intermediate overflow.
        let dRaw = Int64(distance.raw)
        let stepX = Int64(speed.raw) * Int64(delta.x.raw) / dRaw
        let stepY = Int64(speed.raw) * Int64(delta.y.raw) / dRaw
        ship.position = Fixed2D(
            x: Fixed(raw: ship.position.x.raw &+ Int32(truncatingIfNeeded: stepX)),
            y: Fixed(raw: ship.position.y.raw &+ Int32(truncatingIfNeeded: stepY))
        )
    }

    /// Target position a ship should integrate toward for a given
    /// waypoint. For `.sea` it's the literal position; for `.port`
    /// it's the port's `shipAnchor` water tile (or the building
    /// anchor if no anchor was recorded — pre-M4 stand-in saves).
    func shipTargetPosition(for waypoint: Waypoint) -> Fixed2D {
        switch waypoint {
        case let .sea(pos):
            return pos
        case let .port(id):
            return portShipPosition(forID: id)
        }
    }

    /// Convenience: ship-position for a given port building.
    private func portShipPosition(_ building: Building) -> Fixed2D {
        if let anchor = building.shipAnchor {
            return Fixed2D(x: Fixed(Int32(anchor.x)), y: Fixed(Int32(anchor.y)))
        }
        return Fixed2D(x: Fixed(Int32(building.anchor.x)), y: Fixed(Int32(building.anchor.y)))
    }

    private func portShipPosition(forID id: EntityID) -> Fixed2D {
        guard let building = buildings[id] else { return .zero }
        return portShipPosition(building)
    }

    // MARK: - Manifest execution

    /// Apply one manifest action and return `true` if any cargo
    /// transfer occurred (so the caller advances to the next
    /// action). Returns `false` when the port's stock/free-capacity
    /// prevents any progress (the caller stalls or times out).
    private mutating func applyManifestAction(
        _ action: ManifestAction,
        ship: inout Ship,
        portID: EntityID
    ) -> Bool {
        guard var portStockpile = stockpiles[portID] else { return false }
        defer { stockpiles[portID] = portStockpile }
        switch action {
        case let .loadUpTo(good, qty):
            let portStock = portStockpile.quantity(of: good)
            let shipFree = ship.shipClass.capacity - ship.cargo.values.reduce(0, +)
            let amount = min(qty, min(portStock, shipFree))
            if amount <= 0 { return false }
            let withdrawn = portStockpile.withdraw(good, amount: amount)
            ship.cargo[good, default: 0] += withdrawn
            return withdrawn > 0
        case let .unloadUpTo(good, qty):
            let shipStock = ship.cargo[good] ?? 0
            let portFree = portStockpile.capacity - portStockpile.totalStored
            let amount = min(qty, min(shipStock, portFree))
            if amount <= 0 { return false }
            let deposited = portStockpile.deposit(good, amount: amount)
            ship.cargo[good] = shipStock - deposited
            if ship.cargo[good] == 0 { ship.cargo.removeValue(forKey: good) }
            return deposited > 0
        }
    }
}
