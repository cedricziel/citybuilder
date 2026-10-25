import Foundation

/// The carrier system and the road lookups it uses. Kept out of
/// `Systems.swift` so that file stays under SwiftLint's length limit.
extension World {
    /// Carrier lifecycle: advance in-flight carriers along their path,
    /// deposit goods on arrival, then spawn fresh carriers from producers
    /// whose output stockpiles have something to ship.
    mutating func runCarrierSystem(events: inout [WorldEvent]) {
        advanceCarriers(events: &events)
        let tileToIsland = tileToIslandMap()
        spawnCarriersFromProducers(tileToIsland: tileToIsland, events: &events)
        spawnSupplyCarriers(events: &events)
        spawnExportCarriers(tileToIsland: tileToIsland, events: &events)
    }

    private mutating func advanceCarriers(events: inout [WorldEvent]) {
        // Arrivals fill shared stockpiles, so carriers move in entity order.
        for id in carriers.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let carrier = carriers[id] else { continue }
            if carrier.hasArrived {
                if let holding = applyCarrierArrival(carrier, events: &events) {
                    // Its destination had no room: it keeps the goods,
                    // so none are lost.
                    carriers[id] = holding
                    continue
                }
                switch carrier.mission {
                case let .deliver(_, _, fromProducer, _),
                     let .deliverToConstructionSite(_, _, fromProducer, _):
                    carrierCountByProducer[fromProducer, default: 1] -= 1
                case .retrieve:
                    break
                }
                carriers.removeValue(forKey: id)
            } else {
                var updated = carrier
                updated.pathIndex += 1
                carriers[id] = updated
            }
        }
    }

    /// Applies `carrier`'s arrival. Returns the carrier still holding what
    /// its destination, still standing, had no room for, sent on where it
    /// goes next; nil once it has nothing left.
    private mutating func applyCarrierArrival(_ carrier: Carrier, events: inout [WorldEvent]) -> Carrier? {
        // `currentTile` is `nil` only on a malformed empty path; arrived
        // carriers always have a positive pathIndex < path.count. Use
        // `path.last` as the safe destination fallback.
        let arrivalTile = carrier.currentTile ?? carrier.path.last ?? TileCoordinate(x: 0, y: 0)
        switch carrier.mission {
        case let .deliver(good, amount, producer, store):
            let kept = deposit(good, amount, into: store, by: carrier, events: &events)
            return kept > 0 ? rerouted(carrier, good: good, amount: kept, producer: producer, from: store) : nil
        case let .retrieve(good, amount, buffer, consumer):
            // A consumer that filled meanwhile gets the rest once it has room.
            let kept = deposit(good, amount, into: consumer, by: carrier, events: &events)
            guard kept > 0 else { return nil }
            var holding = carrier
            holding.mission = .retrieve(good: good, amount: kept, fromWarehouse: buffer, toConsumer: consumer)
            return holding
        case let .deliverToConstructionSite(good, amount, _, toBuilding):
            applyConstructionDelivery(
                ConstructionDelivery(
                    building: toBuilding,
                    good: good,
                    amount: amount,
                    carrier: carrier,
                    arrivalTile: arrivalTile
                ),
                events: &events
            )
            return nil
        }
    }

    /// Puts what fits of `amount` into `destination` and returns the units
    /// left over. A demolished destination takes nothing and keeps nothing,
    /// as before.
    private mutating func deposit(
        _ good: Good, _ amount: Int, into destination: EntityID, by carrier: Carrier, events: inout [WorldEvent]
    ) -> Int {
        guard var pile = stockpiles[destination] else { return 0 }
        let accepted = pile.deposit(good, amount: amount)
        stockpiles[destination] = pile
        if accepted > 0 {
            let tile = carrier.currentTile ?? carrier.path.last ?? TileCoordinate(x: 0, y: 0)
            events.append(.carrierArrived(carrier: carrier.id, at: tile, good: good, amount: accepted))
        }
        return amount - accepted
    }

    /// A producer's carrier left holding `amount` of `good` at `store`, which
    /// had no room: on to the nearest other store with room for it, counting
    /// what is already on its way there, else home to `producer`. At home
    /// with no room it waits there and looks again next tick, so carriers
    /// never pile up behind a full store.
    private func rerouted(
        _ carrier: Carrier, good: Good, amount: Int, producer: EntityID, from store: EntityID
    ) -> Carrier {
        let here = carrier.currentTile ?? carrier.path.last ?? TileCoordinate(x: 0, y: 0)
        let inbound = inboundDeliveries()
        let others = goodsBuffers().filter { $0.state == .operational && $0.id != store }
        if let (target, path) = findRoadConnectedBuffer(
            fromRoad: here, good: good, among: others, inbound: { inbound[$1]?[$0] ?? 0 }
        ) {
            return Carrier(id: carrier.id, path: path, mission: .deliver(
                good: good, amount: amount, fromProducer: producer, toWarehouse: target
            ))
        }
        let home = buildings[producer].flatMap {
            anyAdjacentRoad(anchor: $0.anchor, footprint: BuildingCatalog.spec(for: $0.kind).footprint)
        }
        guard store != producer, let home, let path = roadPath(from: here, to: home) else {
            var waiting = carrier
            waiting.mission = .deliver(good: good, amount: amount, fromProducer: producer, toWarehouse: store)
            return waiting
        }
        return Carrier(id: carrier.id, path: path, mission: .deliver(
            good: good, amount: amount, fromProducer: producer, toWarehouse: producer
        ))
    }

    /// Units of each good on their way to each store, so its room for a
    /// good is not promised twice.
    private func inboundDeliveries() -> [EntityID: [Good: Int]] {
        var inbound: [EntityID: [Good: Int]] = [:]
        for carrier in carriers.values {
            if case let .deliver(good, amount, _, store) = carrier.mission {
                inbound[store, default: [:]][good, default: 0] += amount
            }
        }
        return inbound
    }

    /// Side-effect of a `.deliverToConstructionSite` arrival: bumps
    /// the site's `materialsDelivered`, emits `carrierArrived`, and
    /// flips the substate to `.actively` (plus `constructionStarted`)
    /// when the recipe is satisfied. Spec
    /// `add-construction-stalls` / M5.
    /// Bundle of `.deliverToConstructionSite` arrival parameters,
    /// packed so the apply method stays under the lint parameter-count
    /// gate.
    private struct ConstructionDelivery {
        let building: EntityID
        let good: Good
        let amount: Int
        let carrier: Carrier
        let arrivalTile: TileCoordinate
    }

    private mutating func applyConstructionDelivery(
        _ delivery: ConstructionDelivery,
        events: inout [WorldEvent]
    ) {
        guard var site = buildings[delivery.building] else { return }
        site.materialsDelivered[delivery.good, default: 0] += delivery.amount
        let satisfied = site.hasAllMaterials
        let wasWaiting = site.constructionState == .waitingForMaterials
        if wasWaiting, satisfied {
            site.constructionState = .actively
        }
        buildings[delivery.building] = site
        events.append(.carrierArrived(
            carrier: delivery.carrier.id,
            at: delivery.arrivalTile,
            good: delivery.good,
            amount: delivery.amount
        ))
        if wasWaiting, satisfied {
            events.append(.constructionStarted(building: delivery.building))
        }
    }

    private mutating func spawnCarriersFromProducers(
        tileToIsland: [TileCoordinate: IslandID],
        events: inout [WorldEvent]
    ) {
        // Spawning carriers moves goods, not buildings, so list the
        // candidate destinations once for every producer.
        let buffers = goodsBuffers().filter { $0.state == .operational }
        let waitingSites = buildings.values
            .filter { $0.state == .constructing && $0.constructionState == .waitingForMaterials }
            .sorted { $0.id.raw < $1.id.raw }
        var inbound = inboundDeliveries()
        for building in operationalProducersInEntityOrder() {
            let producerId = building.id
            guard let recipe = ProductionCatalog.recipe(for: building.kind) else { continue }
            let inFlight = carrierCountByProducer[producerId, default: 0]
            guard inFlight < CarrierConfig.perProducerCap else { continue }
            guard let producerStock = stockpiles[producerId] else { continue }
            let footprint = BuildingCatalog.spec(for: building.kind).footprint
            guard let road = anyAdjacentRoad(anchor: building.anchor, footprint: footprint)
            else { continue }
            let islandID = islandFor(building: building, tileToIsland: tileToIsland)

            for (good, _) in recipe.outputs where producerStock.quantity(of: good) >= 1 {
                if let (siteId, sitePath) = findWaitingSiteOnIsland(
                    fromRoad: road, good: good, islandID: islandID, tileToIsland: tileToIsland, among: waitingSites
                ) {
                    spawnCarrier(
                        CarrierSpawn(
                            producerId: producerId,
                            road: road,
                            good: good,
                            mission: .deliverToConstructionSite(
                                good: good, amount: 1,
                                fromProducer: producerId, toBuilding: siteId
                            ),
                            path: sitePath
                        ),
                        events: &events
                    )
                    break
                }
                guard let (warehouseId, path) = findRoadConnectedBuffer(
                    fromRoad: road, good: good, among: buffers, inbound: { inbound[$1]?[$0] ?? 0 }
                )
                else { continue }
                inbound[warehouseId, default: [:]][good, default: 0] += 1
                spawnCarrier(
                    CarrierSpawn(
                        producerId: producerId,
                        road: road,
                        good: good,
                        mission: .deliver(
                            good: good, amount: 1,
                            fromProducer: producerId, toWarehouse: warehouseId
                        ),
                        path: path
                    ),
                    events: &events
                )
                break
            }
        }
    }

    /// Bundle of spawn arguments, packed so `spawnCarrier` stays
    /// under the lint parameter-count gate.
    private struct CarrierSpawn {
        let producerId: EntityID
        let road: TileCoordinate
        let good: Good
        let mission: Carrier.Mission
        let path: [TileCoordinate]
    }

    private mutating func spawnCarrier(
        _ spawn: CarrierSpawn,
        events: inout [WorldEvent]
    ) {
        stockpiles[spawn.producerId]?.withdraw(spawn.good, amount: 1)
        let carrierId = EntityID(raw: nextEntityRaw)
        nextEntityRaw &+= 1
        carriers[carrierId] = Carrier(id: carrierId, path: spawn.path, mission: spawn.mission)
        carrierCountByProducer[spawn.producerId, default: 0] += 1
        events.append(.carrierDeparted(
            carrier: carrierId, from: spawn.road, good: spawn.good
        ))
    }

    /// Closest road-connected site among the `waiting` construction sites
    /// (in entity order) on `islandID`
    /// that still needs `good` to complete its recipe. Returns nil if
    /// no such site is reachable. Spec: `add-construction-stalls` /
    /// `Producer prioritizes waiting construction sites`.
    private func findWaitingSiteOnIsland(
        fromRoad start: TileCoordinate,
        good: Good,
        islandID: IslandID?,
        tileToIsland: [TileCoordinate: IslandID],
        among waiting: [Building]
    ) -> (EntityID, [TileCoordinate])? {
        var best: (EntityID, [TileCoordinate])?
        for site in waiting {
            let id = site.id
            let cost = BuildingCatalog.spec(for: site.kind).materialCost
            let needed = (cost[good] ?? 0) - (site.materialsDelivered[good] ?? 0)
            guard needed > 0 else { continue }
            if let islandID {
                let onIsland = buildingIsOnIsland(
                    site, islandID: islandID, tileToIsland: tileToIsland
                )
                if !onIsland { continue }
            }
            let footprint = BuildingCatalog.spec(for: site.kind).footprint
            guard let siteRoad = anyAdjacentRoad(anchor: site.anchor, footprint: footprint)
            else { continue }
            guard let path = PathFinder.path(from: start, to: siteRoad, in: roadGraph)
            else { continue }
            if best == nil || path.count < best!.1.count {
                best = (id, path)
            }
        }
        return best
    }

    func islandFor(
        building: Building,
        tileToIsland: [TileCoordinate: IslandID]
    ) -> IslandID? {
        let footprint = BuildingCatalog.spec(for: building.kind).footprint
        for tile in footprint.tiles(anchor: building.anchor) {
            if let id = tileToIsland[tile] { return id }
        }
        return nil
    }

    /// Returns any road tile orthogonally adjacent to the footprint, or nil
    /// if the building isn't road-connected.
    func anyAdjacentRoad(anchor: TileCoordinate, footprint: Footprint) -> TileCoordinate? {
        // Runs per house, need and producer every tick, so it allocates
        // nothing: the footprint is a rectangle, tested by its bounds.
        func inside(_ tile: TileCoordinate) -> Bool {
            tile.x >= anchor.x && tile.x < anchor.x + footprint.width
                && tile.y >= anchor.y && tile.y < anchor.y + footprint.height
        }
        for dy in 0 ..< footprint.height {
            for dx in 0 ..< footprint.width {
                let x = anchor.x + dx, y = anchor.y + dy
                for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)] {
                    let neighbor = TileCoordinate(x: nx, y: ny)
                    if !inside(neighbor), roadGraph.isConnected(neighbor) { return neighbor }
                }
            }
        }
        return nil
    }

    /// Find the road-connected goods buffer with capacity for `good`.
    /// Returns (bufferId, road path) on the shortest path; nil if none
    /// reachable. Equal-length paths resolve to the lowest entity ID.
    /// `buffers` are the operational goods buffers in entity order, when
    /// the caller has already listed them. A buffer qualifies only with
    /// room for `good` beyond the units `inbound` says are on their way.
    func findRoadConnectedBuffer(
        fromRoad start: TileCoordinate,
        good: Good,
        among buffers: [Building]? = nil,
        inbound: (Good, EntityID) -> Int = { _, _ in 0 }
    ) -> (EntityID, [TileCoordinate])? {
        var best: (EntityID, [TileCoordinate])?
        for building in buffers ?? goodsBuffers().filter({ $0.state == .operational }) {
            let id = building.id
            guard let bufferRoad = anyAdjacentRoad(
                anchor: building.anchor,
                footprint: BuildingCatalog.spec(for: building.kind).footprint
            )
            else { continue }
            guard let stock = stockpiles[id], stock.room(for: good) > inbound(good, id) else { continue }
            guard let path = roadPath(from: start, to: bufferRoad)
            else { continue }
            if best == nil || path.count < best!.1.count {
                best = (id, path)
            }
        }
        return best
    }
}
