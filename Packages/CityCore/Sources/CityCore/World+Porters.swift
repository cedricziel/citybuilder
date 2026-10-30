import Foundation

/// A market porter: walks a basket of house goods from a hub to a house,
/// then back to the hub. Spec: `population-and-needs` / Market porters
/// supply houses (visible-distribution design D4). Porters are their own
/// entities, not carriers, so a basket never meets the carriers'
/// redirects, inbound counts or producer slots.
public struct Porter: Hashable, Codable, Sendable {
    /// Units of one good in a basket.
    public struct Load: Hashable, Codable, Sendable {
        public let good: Good
        public var units: Int

        public init(good: Good, units: Int) {
            self.good = good
            self.units = units
        }
    }

    public let id: EntityID
    public let hub: EntityID
    public let house: EntityID
    public var path: [TileCoordinate]
    public var pathIndex = 0
    /// The goods carried, in the house tier's order of needs.
    public var basket: [Load]
    /// True on the walk back to the hub.
    public var returning = false

    public init(
        id: EntityID, hub: EntityID, house: EntityID, path: [TileCoordinate], pathIndex: Int = 0, basket: [Load],
        returning: Bool = false
    ) {
        self.id = id
        self.hub = hub
        self.house = house
        self.path = path
        self.pathIndex = pathIndex
        self.basket = basket
        self.returning = returning
    }

    public var currentTile: TileCoordinate? {
        path.indices.contains(pathIndex) ? path[pathIndex] : nil
    }

    var hasArrived: Bool {
        pathIndex >= path.count - 1
    }
}

extension KeyedDecodingContainer {
    /// Saves from before market porters decode none.
    func decode(_ type: [Porter].Type, forKey key: Key) throws -> [Porter] {
        try decodeIfPresent(type, forKey: key) ?? []
    }
}

/// Which hub serves each house this tick. Spec: `population-and-needs` /
/// Town center supplies house needs.
struct HubService {
    /// The hub serving a house, the road distance to it, and the house's
    /// road tile nearest it.
    struct Serving {
        let hub: EntityID
        let distance: Int
        let road: TileCoordinate
    }

    /// The hub serving each house.
    var hubOf: [EntityID: Serving] = [:]
    /// The houses each hub serves, in entity order.
    var housesOf: [EntityID: [EntityID]] = [:]
    /// Road distance from each hub's road tiles, out to its radius.
    var reach: [EntityID: [TileCoordinate: Int]] = [:]
    /// The operational hubs, in entity order.
    let hubs: [Building]
}

extension World {
    /// The tiles orthogonally next to a footprint, outside it, row-major
    /// around each footprint tile, each once.
    static func tilesAround(anchor: TileCoordinate, footprint: Footprint) -> [TileCoordinate] {
        var tiles: [TileCoordinate] = []
        for dy in 0 ..< footprint.height {
            for dx in 0 ..< footprint.width {
                let x = anchor.x + dx, y = anchor.y + dy
                for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)] {
                    let inside = nx >= anchor.x && nx < anchor.x + footprint.width
                        && ny >= anchor.y && ny < anchor.y + footprint.height
                    let tile = TileCoordinate(x: nx, y: ny)
                    if !inside, !tiles.contains(tile) { tiles.append(tile) }
                }
            }
        }
        return tiles
    }

    /// Every road tile next to the footprint, in `tilesAround` order.
    func adjacentRoads(anchor: TileCoordinate, footprint: Footprint) -> [TileCoordinate] {
        Self.tilesAround(anchor: anchor, footprint: footprint).filter(roadGraph.isConnected)
    }

    /// Operational buildings with hub data, in entity order.
    func operationalHubs() -> [Building] {
        goodsBuffers().filter { $0.state == .operational && $0.kind.hub != nil }
    }

    /// Each operational house's serving hub: the nearest operational hub of
    /// its owner within the hub's radius by road, measured from any road
    /// next to the hub to any road next to the house; ties go to the lower
    /// ID. Depends on buildings and roads only, so a tick builds it once.
    func hubService() -> HubService {
        var service = HubService(hubs: operationalHubs())
        for hub in service.hubs {
            let roads = adjacentRoads(anchor: hub.anchor, footprint: hub.footprint)
            service.reach[hub.id] = roadGraph.distances(from: roads, upTo: hub.kind.hub?.radius ?? 0)
        }
        let houses = buildings.values
            .filter { $0.kind == .house && $0.state == .operational }
            .sorted { $0.id.raw < $1.id.raw }
        for house in houses {
            let roads = adjacentRoads(anchor: house.anchor, footprint: house.footprint)
            for hub in service.hubs where hub.owner == house.owner {
                let distances = service.reach[hub.id] ?? [:]
                guard let (road, distance) = roads.compactMap({ road in distances[road].map { (road, $0) } })
                    .min(by: { $0.1 < $1.1 })
                else { continue }
                if service.hubOf[house.id].map({ distance < $0.distance }) ?? true {
                    service.hubOf[house.id] = HubService.Serving(hub: hub.id, distance: distance, road: road)
                }
            }
            if let hub = service.hubOf[house.id]?.hub {
                service.housesOf[hub, default: []].append(house.id)
            }
        }
        return service
    }

    /// Units of each good porters are carrying to each house.
    func porterInbound() -> [EntityID: [Good: Int]] {
        var inbound: [EntityID: [Good: Int]] = [:]
        for porter in porters where !porter.returning {
            for load in porter.basket {
                inbound[porter.house, default: [:]][load.good, default: 0] += load.units
            }
        }
        return inbound
    }

    /// Porters walk, unload, return and set out. Spec: `population-and-needs`
    /// / Market porters supply houses.
    mutating func runPorterSystem(service: HubService, events: inout [WorldEvent]) {
        advancePorters(events: &events)
        var inbound = porterInbound()
        var out: [EntityID: Int] = [:]
        for porter in porters {
            out[porter.hub, default: 0] += 1
        }
        for hub in service.hubs {
            dispatchPorters(from: hub, out: out[hub.id] ?? 0, service: service, inbound: &inbound)
        }
    }

    private mutating func advancePorters(events: inout [WorldEvent]) {
        var kept: [Porter] = []
        for var porter in porters {
            guard porter.hasArrived else {
                porter.pathIndex += 1
                kept.append(porter)
                continue
            }
            if porter.returning {
                for load in porter.basket {
                    let placed = stockpiles[porter.hub]?.deposit(load.good, amount: load.units) ?? 0
                    if placed < load.units {
                        sendOn(Porter.Load(good: load.good, units: load.units - placed), from: porter, events: &events)
                    }
                }
                continue
            }
            if buildings[porter.house]?.state == .operational, var pop = populations[porter.house] {
                for index in porter.basket.indices {
                    porter.basket[index].units -= pop.addStock(porter.basket[index].good, amount: porter.basket[index].units)
                }
                populations[porter.house] = pop
            }
            porter.basket.removeAll { $0.units == 0 }
            porter.returning = true
            porter.path.reverse()
            porter.pathIndex = 0
            kept.append(porter)
        }
        porters = kept
    }

    /// Leftovers a porter's hub could not take, full or gone, go on as a
    /// carrier to the nearest store of the hub's owner with room; with none,
    /// they are lost, as a carrier's are.
    private mutating func sendOn(_ load: Porter.Load, from porter: Porter, events: inout [WorldEvent]) {
        let here = porter.currentTile ?? porter.path.last ?? TileCoordinate(x: 0, y: 0)
        let owner = buildings[porter.hub]?.owner ?? buildings[porter.house]?.owner ?? islandID(at: here).map(owner(ofIsland:))
        guard let owner,
              let (store, path) = findRoadConnectedBuffer(
                  fromRoad: here, good: load.good,
                  among: goodsBuffers(of: owner).filter { $0.state == .operational && $0.id != porter.hub }
              )
        else { return }
        let id = EntityID(raw: nextEntityRaw)
        nextEntityRaw &+= 1
        let mission = Carrier.Mission.retrieve(good: load.good, amount: load.units, fromWarehouse: porter.hub, toConsumer: store)
        carriers[id] = Carrier(id: id, path: path, mission: mission)
        events.append(.carrierDeparted(carrier: id, from: here, good: load.good))
    }

    /// Sends porters from `hub` while it has fewer than it keeps out, each
    /// to the served house with the lowest stock ratio.
    private mutating func dispatchPorters(
        from hub: Building, out: Int, service: HubService, inbound: inout [EntityID: [Good: Int]]
    ) {
        let houses = service.housesOf[hub.id] ?? []
        guard let spec = hub.kind.hub, let distances = service.reach[hub.id] else { return }
        var out = out
        while out < spec.porters(serving: houses.count) {
            // The path comes from the same search that found the house in reach, so a served house always has one.
            guard let trip = nextTrip(from: hub.id, among: houses, service: service, inbound: inbound),
                  let road = service.hubOf[trip.id]?.road, let path = roadGraph.path(to: road, along: distances)
            else { return }
            let basket = fillBasket(for: trip.id, from: hub.id, units: spec.basketUnits, inbound: inbound[trip.id] ?? [:])
            for load in basket {
                stockpiles[hub.id]?.withdraw(load.good, amount: load.units)
                inbound[trip.id, default: [:]][load.good, default: 0] += load.units
            }
            porters.append(Porter(id: EntityID(raw: nextEntityRaw), hub: hub.id, house: trip.id, path: path, basket: basket))
            nextEntityRaw &+= 1
            out += 1
        }
    }

    /// A stock ratio, held over capacity, compared without division.
    private struct StockRatio {
        let held: Int
        let capacity: Int

        func isBelow(_ other: StockRatio) -> Bool {
            held * other.capacity < other.held * capacity
        }
    }

    /// The served house with the lowest stock ratio over the needs `hub`
    /// holds, skipping houses with nothing to take; ties go to the shorter
    /// road, then the lower ID.
    private func nextTrip(
        from hub: EntityID, among houses: [EntityID], service: HubService, inbound: [EntityID: [Good: Int]]
    ) -> Building? {
        let held = stockpiles[hub] ?? Stockpile(capacity: 0)
        // The player's porters serve the highest tier first, so the houses a
        // player worked up keep their goods; a rival's spread by stock ratio,
        // since rivals grow residents rather than merchants.
        let tierFirst = buildings[hub]?.owner == .player
        var best: (house: Building, rank: (ratio: StockRatio, distance: Int))?
        for id in houses {
            guard let house = buildings[id], let pop = populations[id] else { continue }
            var lowest: StockRatio?
            for good in pop.tier.needs(in: culture) where held.quantity(of: good) > 0 {
                let ratio = StockRatio(held: pop.stock(of: good) + (inbound[id]?[good] ?? 0), capacity: pop.stockCapacity(of: good))
                if ratio.held < ratio.capacity, lowest.map(ratio.isBelow) ?? true {
                    lowest = ratio
                }
            }
            guard let lowest else { continue }
            let distance = service.hubOf[id]?.distance ?? 0
            let tier = pop.tier.rawValue
            let better = best.map { best in
                let bestTier = populations[best.house.id]?.tier.rawValue ?? 0
                // Of one tier, the player's oldest house comes first, as houses drew
                // from the stores in entity order before porters.
                if tierFirst { return tier > bestTier }
                return lowest.isBelow(best.rank.ratio) || (!best.rank.ratio.isBelow(lowest) && distance < best.rank.distance)
            } ?? true
            if better {
                best = (house, (lowest, distance))
            }
        }
        return best?.house
    }

    /// One basket for `house`, in two passes over the needs the hub holds, in
    /// the tier's order: first up to one consumption of each, then, with room
    /// left in the basket, each topped up to the house's capacity; `units` in
    /// all at most.
    private func fillBasket(for house: EntityID, from hub: EntityID, units: Int, inbound: [Good: Int]) -> [Porter.Load] {
        guard let pop = populations[house] else { return [] }
        let held = stockpiles[hub] ?? Stockpile(capacity: 0)
        let needs = pop.tier.needs(in: culture)
        var taken: [Good: Int] = [:]
        var left = units
        for firstPass in [true, false] {
            for good in needs where left > 0 {
                let room = pop.stockCapacity(of: good) - pop.stock(of: good) - (inbound[good] ?? 0) - taken[good, default: 0]
                let wanted = firstPass ? min(room, pop.nextConsumption(of: good)) : room
                let take = min(wanted, held.quantity(of: good) - taken[good, default: 0], left)
                guard take > 0 else { continue }
                taken[good, default: 0] += take
                left -= take
            }
        }
        return needs.compactMap { good in taken[good].map { Porter.Load(good: good, units: $0) } }
    }
}
