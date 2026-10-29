import Foundation

/// Fire: ignition, spread to touching buildings, burning down to ruins,
/// and the fire watch's watchman. Spec: `seasonal-events` / Fire starts,
/// spreads and burns down; A fire watch puts out fires in reach.
extension World {
    static let burnDownTicks: UInt64 = 300
    static let fireWatchReach = 8

    /// One ignition in the first half of the onset season, and on Hard a
    /// second in its second half, from the seed and the year.
    func fireIgnitionTicks() -> [UInt64] {
        let half = CalendarState.ticksPerSeason / 2
        return (0 ..< difficulty.firesPerFireEvent).map { index in
            var rng = seasonalEventRNG(.ignition, year: date.year, index: UInt64(index))
            return tickCount + UInt64(index) * half + 1 + rng.next() % (half - 1)
        }
    }

    mutating func runFireSystem(events: inout [WorldEvent]) {
        guard var state = seasonalEvents.fire else { return }
        // A demolished building's fire is gone with it.
        state.fires.removeAll { buildings[$0.building]?.state != .burning }
        seasonalEvents.fire = state
        if state.ignitionTicks.first == tickCount {
            igniteNext(events: &events)
        }
        // A fire out on its spread or burn-down tick neither spreads nor burns down.
        for fire in seasonalEvents.fire?.fires ?? [] where fire.watchman?.outTick == tickCount {
            extinguish(fire.building, events: &events)
            seasonalEvents.counters.firesPutOut += 1
        }
        spreadFires(events: &events)
        burnDownFires(events: &events)
        dispatchWatchmen()
        if let state = seasonalEvents.fire, state.fires.isEmpty, state.ignitionTicks.isEmpty {
            endSeasonalEvent(events: &events)
        }
    }

    /// Sets an operational player house or producer that hasn't burnt in
    /// this event alight, chosen with the ignition's own generator; with
    /// none left the ignition is skipped.
    private mutating func igniteNext(events: inout [WorldEvent]) {
        guard var state = seasonalEvents.fire else { return }
        state.ignitionTicks.removeFirst()
        var rng = seasonalEventRNG(.ignition, year: date.year, index: UInt64(state.ignitions))
        state.ignitions += 1
        seasonalEvents.fire = state
        let candidates = unburntPlayerBuildings { Self.canIgnite($0.kind) }
        _ = rng.next()
        guard !candidates.isEmpty else { return }
        ignite(candidates[Int(rng.next() % UInt64(candidates.count))].id, events: &events)
    }

    /// Operational player buildings that haven't caught fire in this event
    /// and pass `test`, in entity order.
    private func unburntPlayerBuildings(_ test: (Building) -> Bool) -> [Building] {
        let caught = seasonalEvents.fire?.caught ?? []
        return buildings.values
            .filter { $0.owner == .player && $0.state == .operational && !caught.contains($0.id) && test($0) }
            .sorted { $0.id.raw < $1.id.raw }
    }

    mutating func ignite(_ id: EntityID, events: inout [WorldEvent]) {
        guard let building = buildings[id] else { return }
        buildings[id]?.state = .burning
        seasonalEvents.fire?.fires.append(Fire(building: id, ignitionTick: tickCount))
        seasonalEvents.fire?.caught.append(id)
        events.append(.buildingCaughtFire(building: id, kind: building.kind))
    }

    /// A fire that has burnt for the difficulty's spread time sets every
    /// flammable building touching it alight, unless it caught already.
    private mutating func spreadFires(events: inout [WorldEvent]) {
        guard let state = seasonalEvents.fire else { return }
        let spreading = state.fires.filter { tickCount == $0.ignitionTick + difficulty.fireSpreadTicks }
        for fire in spreading {
            guard let source = buildings[fire.building] else { continue }
            let neighbours = unburntPlayerBuildings { Self.isFlammable($0.kind) && Self.footprintDistance(source, $0) == 1 }
            for neighbour in neighbours {
                ignite(neighbour.id, events: &events)
            }
        }
    }

    /// A building that burns for 300 ticks becomes ruins of its footprint:
    /// its stock and residents are gone, and carriers bound for it go on
    /// as they do from a demolished building.
    private mutating func burnDownFires(events: inout [WorldEvent]) {
        guard let state = seasonalEvents.fire else { return }
        for fire in state.fires where tickCount == fire.ignitionTick + Self.burnDownTicks {
            guard let building = buildings[fire.building] else { continue }
            buildings[fire.building] = Building(
                id: building.id, kind: .ruins, anchor: building.anchor, state: .operational,
                owner: building.owner, ruinOf: building.kind
            )
            stockpiles[fire.building] = nil
            populations[fire.building] = nil
            productions[fire.building] = nil
            seasonalEvents.fire?.fires.removeAll { $0.building == fire.building }
            seasonalEvents.fire?.lost += 1
            seasonalEvents.counters.buildingsLostToFire += 1
            events.append(.buildingBurntDown(building: fire.building, kind: building.kind))
        }
    }

    /// The fire is out: the building resumes with its stock and residents.
    mutating func extinguish(_ id: EntityID, events: inout [WorldEvent]) {
        buildings[id]?.state = .operational
        seasonalEvents.fire?.fires.removeAll { $0.building == id }
        events.append(.fireExtinguished(building: id))
    }

    /// Sends idle fire watches to the fires in their reach, oldest fire
    /// first, each to the nearest idle watch by road.
    mutating func dispatchWatchmen() {
        guard var state = seasonalEvents.fire, state.fires.contains(where: { $0.watchman == nil }) else { return }
        var busy = Set(state.fires.compactMap { $0.watchman?.watch })
        let watches = buildings.values
            .filter { $0.kind == .fireWatch && $0.owner == .player && $0.state == .operational }
            .sorted { $0.id.raw < $1.id.raw }
        func order(_ index: Int) -> (UInt64, UInt32) {
            (state.fires[index].ignitionTick, state.fires[index].building.raw)
        }
        let queue = state.fires.indices.filter { state.fires[$0].watchman == nil }.sorted { order($0) < order($1) }
        for index in queue {
            guard let target = buildings[state.fires[index].building],
                  let goal = anyAdjacentRoad(anchor: target.anchor, footprint: target.footprint)
            else { continue }
            let routes = watches.filter { !busy.contains($0.id) }.compactMap { watch in
                watchmanPath(from: watch, to: target, goal: goal).map { (watch: watch.id, path: $0) }
            }
            guard let nearest = routes.min(by: { ($0.path.count, $0.watch.raw) < ($1.path.count, $1.watch.raw) }) else { continue }
            busy.insert(nearest.watch)
            state.fires[index].watchman = Watchman(watch: nearest.watch, path: nearest.path, departureTick: tickCount)
        }
        seasonalEvents.fire = state
    }

    /// The road path from a watch to a burning building within its reach.
    private func watchmanPath(from watch: Building, to target: Building, goal: TileCoordinate) -> [TileCoordinate]? {
        guard Self.footprintDistance(watch, target) <= Self.fireWatchReach,
              let start = anyAdjacentRoad(anchor: watch.anchor, footprint: watch.footprint)
        else { return nil }
        return roadPath(from: start, to: goal)
    }

    /// The watchmen on their way, as walkers for the renderer.
    var watchmenOnTheRoad: [Carrier] {
        (seasonalEvents.fire?.fires ?? []).compactMap { fire in
            guard let man = fire.watchman, tickCount < man.arrivalTick else { return nil }
            return Carrier(
                id: man.watch, path: man.path, pathIndex: Int(tickCount - man.departureTick),
                mission: .deliver(good: .wood, amount: 0, fromProducer: man.watch, toWarehouse: fire.building)
            )
        }
    }

    /// Clearing ruins, or pulling a burning building down as a firebreak,
    /// costs the clearing fee; false, with the rejection reported, when the
    /// treasury can't pay. Other buildings come down for free.
    mutating func payToClear(_ building: Building, events: inout [WorldEvent]) -> Bool {
        guard building.kind == .ruins || building.state == .burning else { return true }
        guard charge(Self.clearingFee(of: building.ruinOf ?? building.kind), to: .player) else {
            events.append(.demolitionRejected(building: building.id, reason: .notEnoughMoney))
            return false
        }
        if building.kind == .ruins {
            events.append(.ruinsCleared(building: building.id))
        }
        return true
    }

    /// What clearing ruins costs: a quarter of the burnt kind's price,
    /// rounded up to $5, at least $10. Spec: `buildings-and-construction`
    /// / Ruins block their plot until cleared.
    static func clearingFee(of kind: BuildingKind) -> Int64 {
        max(10, (BuildingCatalog.spec(for: kind).cost + 19) / 20 * 5)
    }
}
