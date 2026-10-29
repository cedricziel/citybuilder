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
        let consumers = operationalConsumers()
        spawnCarriersFromProducers(consumers: consumers, tileToIsland: tileToIsland, events: &events)
        spawnSupplyCarriers(consumers: consumers, events: &events)
        spawnExportCarriers(tileToIsland: tileToIsland, events: &events)
    }

    private mutating func advanceCarriers(events: inout [WorldEvent]) {
        // Arrivals fill shared stockpiles, so carriers move in entity order.
        for id in carriers.keys.sorted(by: { $0.raw < $1.raw }) {
            guard var carrier = carriers[id] else { continue }
            guard carrier.hasArrived else {
                carrier.pathIndex += 1
                carriers[id] = carrier
                continue
            }
            let undelivered = applyCarrierArrival(carrier, events: &events)
            if undelivered > 0, let onward = rerouted(carrier, carrying: undelivered) {
                carriers[id] = onward
                continue
            }
            switch carrier.mission {
            case let .deliver(_, _, fromProducer, _),
                 let .deliverToConsumer(_, _, fromProducer, _),
                 let .deliverToConstructionSite(_, _, fromProducer, _):
                carrierCountByProducer[fromProducer, default: 1] -= 1
            case .retrieve:
                break
            }
            carriers.removeValue(forKey: id)
        }
    }

    /// Unloads an arrived carrier and returns the units its destination
    /// could not take: none when it had room, all of them when it is
    /// gone.
    private mutating func applyCarrierArrival(_ carrier: Carrier, events: inout [WorldEvent]) -> Int {
        // `currentTile` is `nil` only on a malformed empty path; arrived
        // carriers always have a positive pathIndex < path.count. Use
        // `path.last` as the safe destination fallback.
        let arrivalTile = carrier.currentTile ?? carrier.path.last ?? TileCoordinate(x: 0, y: 0)
        switch carrier.mission {
        case let .deliver(good, amount, _, destination),
             let .retrieve(good, amount, _, destination),
             let .deliverToConsumer(good, amount, _, destination):
            // A burning building takes no deliveries until it is out.
            let open = buildings[destination]?.state != .burning
            let placed = open ? stockpiles[destination]?.deposit(good, amount: amount) ?? 0 : 0
            if placed > 0 {
                events.append(.carrierArrived(carrier: carrier.id, at: arrivalTile, good: good, amount: placed))
            }
            return amount - placed
        case let .deliverToConstructionSite(good, amount, _, toBuilding):
            let delivered = applyConstructionDelivery(
                ConstructionDelivery(
                    building: toBuilding,
                    good: good,
                    amount: amount,
                    carrier: carrier,
                    arrivalTile: arrivalTile
                ),
                events: &events
            )
            return delivered ? 0 : amount
        }
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

    /// Returns false when the site is gone or already built, so the
    /// carrier takes the goods elsewhere.
    private mutating func applyConstructionDelivery(
        _ delivery: ConstructionDelivery,
        events: inout [WorldEvent]
    ) -> Bool {
        guard var site = buildings[delivery.building], site.state == .constructing else { return false }
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
        return true
    }

    private mutating func spawnCarriersFromProducers(
        consumers: [(Building, [Good: Int])],
        tileToIsland: [TileCoordinate: IslandID],
        events: inout [WorldEvent]
    ) {
        // Spawning carriers moves goods, not buildings, so list the
        // candidate destinations once for every producer.
        let candidates = DestinationCandidates(
            buffers: goodsBuffers().filter { $0.state == .operational },
            waitingSites: buildings.values
                .filter { $0.state == .constructing && $0.constructionState == .waitingForMaterials }
                .sorted { $0.id.raw < $1.id.raw },
            consumers: Self.consumersByGood(consumers),
            tileToIsland: tileToIsland,
            components: RoadComponents(roadGraph),
            inbound: InboundGoods(carriers.values)
        )
        for building in operationalProducersInEntityOrder() {
            let producerId = building.id
            guard let recipe = ProductionCatalog.recipe(for: building.kind) else { continue }
            let inFlight = carrierCountByProducer[producerId, default: 0]
            guard inFlight < CarrierConfig.perProducerCap, let producerStock = stockpiles[producerId] else { continue }
            let footprint = building.footprint
            guard let road = anyAdjacentRoad(anchor: building.anchor, footprint: footprint)
            else { continue }

            for (good, _) in recipe.outputs where producerStock.quantity(of: good) >= 1 {
                guard let haul = destination(of: good, from: building, road: road, among: candidates)
                else { continue }
                candidates.inbound.add(haul.mission)
                spawnCarrier(
                    CarrierSpawn(
                        producerId: producerId, road: road, good: good, mission: haul.mission, path: haul.path,
                        vehicle: haul.vehicle
                    ),
                    events: &events
                )
                break
            }
        }
    }

    /// Where producers may send output this tick, listed once.
    private struct DestinationCandidates {
        let buffers: [Building]
        let waitingSites: [Building]
        let consumers: [Good: [GoodConsumer]]
        let tileToIsland: [TileCoordinate: IslandID]
        let components: RoadComponents
        let inbound: InboundGoods
    }

    /// A short consumer a producer can reach: its road path and the
    /// amount its recipe or fuel uses at a time.
    private struct ShortConsumer {
        let id: EntityID
        let path: [TileCoordinate]
        let amount: Int
    }

    /// Where a producer's goods go, along which road, and how.
    private struct Haul {
        let mission: Carrier.Mission
        let path: [TileCoordinate]
        var vehicle: Vehicle?
    }

    /// Road component labels, worked out the first time a tick asks,
    /// so a consumer on another road network is skipped without a
    /// failed path search.
    private final class RoadComponents {
        private let graph: RoadGraph
        private(set) lazy var labels: [TileCoordinate: Int] = graph.componentLabels()

        init(_ graph: RoadGraph) {
            self.graph = graph
        }
    }

    /// Where `good` from `producer` goes, the road path there, and how: a
    /// waiting construction site first, then a short consumer, then the
    /// nearest goods buffer with room. A long hop or haul takes the owner's
    /// vehicle when enough is ready; a long haul to storage waits for a load
    /// (`storageHaul`).
    private mutating func destination(
        of good: Good,
        from producer: Building,
        road: TileCoordinate,
        among candidates: DestinationCandidates
    ) -> Haul? {
        let islandID = islandFor(building: producer, tileToIsland: candidates.tileToIsland)
        if let (siteId, path) = findWaitingSiteOnIsland(
            fromRoad: road, good: good, islandID: islandID,
            tileToIsland: candidates.tileToIsland, among: candidates.waitingSites
        ) {
            let mission = Carrier.Mission.deliverToConstructionSite(good: good, amount: 1, fromProducer: producer.id, toBuilding: siteId)
            return Haul(mission: mission, path: path)
        }
        let held = stockpiles[producer.id]?.quantity(of: good) ?? 0
        if !goesThroughStorage(good, for: producer.owner), let consumer = nearestShortConsumer(
            of: good, from: producer, road: road, among: candidates
        ) {
            let short = shortfall(of: good, at: consumer.id, amount: consumer.amount)
            let haul = CarrierConfig.haul(
                ready: min(held, short), along: consumer.path, vehicle: CarrierConfig.vehicle(in: age(of: producer.owner))
            )
            let mission = Carrier.Mission.deliverToConsumer(
                good: good, amount: haul.amount, fromProducer: producer.id, toConsumer: consumer.id
            )
            return Haul(mission: mission, path: consumer.path, vehicle: haul.vehicle)
        }
        return storageHaul(of: good, held: held, from: producer, road: road, among: candidates)
    }

    /// Goods any building costs as a construction material.
    private static let materialGoods = Set(BuildingCatalog.all.flatMap(\.materialCost.keys))

    /// True for goods that always go to storage first: construction
    /// materials, and goods a house tier of `owner`'s culture needs.
    /// Building sites and houses draw on storage, so a workshop must not
    /// take these before it. Spec: `warehouses-and-logistics` /
    /// Producers deliver to short consumers.
    func goesThroughStorage(_ good: Good, for owner: Owner) -> Bool {
        Self.materialGoods.contains(good) || HouseTier.allNeeds(in: culture(of: owner)).contains(good)
    }

    /// A consumer of a good, with the amount its recipe or fuel uses at a time.
    struct GoodConsumer {
        let building: Building
        let amount: Int
    }

    /// `consumers` (from `operationalConsumers()`) grouped by the goods
    /// they take, in entity order.
    static func consumersByGood(_ list: [(Building, [Good: Int])]) -> [Good: [GoodConsumer]] {
        var consumers: [Good: [GoodConsumer]] = [:]
        for (building, needs) in list {
            for (good, amount) in needs {
                consumers[good, default: []].append(GoodConsumer(building: building, amount: amount))
            }
        }
        return consumers
    }

    /// The short consumer of `good` with the shortest road path from
    /// `producer`'s road; ties go to the lower entity ID. Short means
    /// the same owner, and stock plus inbound below twice the recipe
    /// amount, as for supply carriers. Spec: `warehouses-and-logistics`
    /// / Producers deliver to short consumers.
    private func nearestShortConsumer(
        of good: Good,
        from producer: Building,
        road: TileCoordinate,
        among candidates: DestinationCandidates
    ) -> ShortConsumer? {
        let component = candidates.components.labels[road]
        var best: ShortConsumer?
        for consumer in candidates.consumers[good] ?? [] {
            let building = consumer.building
            guard building.id != producer.id, building.owner == producer.owner,
                  needsSupply(building.id, good: good, amount: consumer.amount),
                  let consumerRoad = anyAdjacentRoad(
                      anchor: building.anchor,
                      footprint: building.footprint
                  ),
                  candidates.components.labels[consumerRoad] == component,
                  let path = PathFinder.path(from: road, to: consumerRoad, in: roadGraph)
            else { continue }
            if best.map({ path.count < $0.path.count }) ?? true {
                best = ShortConsumer(id: building.id, path: path, amount: consumer.amount)
            }
        }
        return best
    }

    /// The goods buffer `producer` sends `held` units of `good` to, the path, and the haul. When the
    /// owner's age has a vehicle, a long haul waits for a vehicle load, up to `haulMaxWait` ticks,
    /// and counts the wait on the producer; then it returns nil. With too little ready and every
    /// buffer far away, it skips the path search.
    private mutating func storageHaul(
        of good: Good, held: Int, from producer: Building, road: TileCoordinate, among candidates: DestinationCandidates
    ) -> Haul? {
        let buffers = candidates.buffers
        let vehicle = CarrierConfig.vehicle(in: age(of: producer.owner))
        // Batching is for bulk nobody is waiting on: a good houses need, or
        // one a building of the owner is short of, never waits for a load.
        let awaited = HouseTier.allNeeds(in: culture(of: producer.owner)).contains(good)
            || candidates.consumers[good]?.contains {
                $0.building.owner == producer.owner && needsSupply($0.building.id, good: good, amount: $0.amount)
            } ?? false
        let waits = vehicle != nil && !awaited && producer.haulWaitTicks < UInt32(CarrierConfig.haulMaxWait)
        func wait() -> Haul? {
            buildings[producer.id]?.haulWaitTicks += 1
            return nil
        }
        if waits, held < CarrierConfig.haulMinLoad, allFar(from: road, among: buffers) {
            return wait()
        }
        let inbound = candidates.inbound.count(of:to:)
        guard var (warehouseId, path) = findRoadConnectedBuffer(fromRoad: road, good: good, among: buffers, inbound: inbound)
        else { return nil }
        func room(at store: EntityID) -> Int {
            let pile = stockpiles[store] ?? Stockpile(capacity: 0)
            return pile.room(for: good) - candidates.inbound.pending(of: good, to: store, in: pile)
        }
        // A long haul prefers the nearest store that takes a cart load over
        // a nearer one with room for only a unit or two.
        let minLoad = CarrierConfig.haulMinLoad
        if vehicle != nil, CarrierConfig.isLong(path), room(at: warehouseId) < minLoad, let roomier = findRoadConnectedBuffer(
            fromRoad: road, good: good, among: buffers, inbound: candidates.inbound.count(of:to:), room: minLoad
        ) {
            (warehouseId, path) = roomier
        }
        let ready = min(held, room(at: warehouseId))
        func deliver(_ amount: Int) -> Carrier.Mission {
            .deliver(good: good, amount: amount, fromProducer: producer.id, toWarehouse: warehouseId)
        }
        guard let vehicle, CarrierConfig.isLong(path) else {
            return Haul(mission: deliver(1), path: path)
        }
        if ready < CarrierConfig.haulMinLoad, waits {
            return wait()
        }
        return Haul(mission: deliver(min(ready, vehicle.capacity)), path: path, vehicle: vehicle)
    }

    /// True when every buffer's road lies at least the cart distance from
    /// `road` along the grid, so any road path to it is a long haul.
    private func allFar(from road: TileCoordinate, among buffers: [Building]) -> Bool {
        buffers.allSatisfy { buffer in
            anyAdjacentRoad(anchor: buffer.anchor, footprint: buffer.footprint).map {
                abs($0.x - road.x) + abs($0.y - road.y) >= CarrierConfig.haulDistance
            } ?? true
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
        var vehicle: Vehicle?
    }

    private mutating func spawnCarrier(
        _ spawn: CarrierSpawn,
        events: inout [WorldEvent]
    ) {
        stockpiles[spawn.producerId]?.withdraw(spawn.good, amount: spawn.mission.amount)
        let carrierId = EntityID(raw: nextEntityRaw)
        nextEntityRaw &+= 1
        carriers[carrierId] = Carrier(id: carrierId, path: spawn.path, mission: spawn.mission, vehicle: spawn.vehicle)
        carrierCountByProducer[spawn.producerId, default: 0] += 1
        buildings[spawn.producerId]?.haulWaitTicks = 0
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
            let footprint = site.footprint
            guard let siteRoad = anyAdjacentRoad(anchor: site.anchor, footprint: footprint),
                  let path = PathFinder.path(from: start, to: siteRoad, in: roadGraph)
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
        let footprint = building.footprint
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
    /// room for at least `needed` units of `good` beyond those `inbound`
    /// says are on their way.
    func findRoadConnectedBuffer(
        fromRoad start: TileCoordinate,
        good: Good,
        among buffers: [Building]? = nil,
        inbound: (Good, EntityID) -> Int = { _, _ in 0 },
        room needed: Int = 1
    ) -> (EntityID, [TileCoordinate])? {
        var best: (EntityID, [TileCoordinate])?
        for building in buffers ?? goodsBuffers().filter({ $0.state == .operational }) {
            let id = building.id
            guard let bufferRoad = anyAdjacentRoad(anchor: building.anchor, footprint: building.footprint),
                  let stock = stockpiles[id], stock.room(for: good) - inbound(good, id) >= needed,
                  let path = roadPath(from: start, to: bufferRoad)
            else { continue }
            if best == nil || path.count < best!.1.count {
                best = (id, path)
            }
        }
        return best
    }
}
