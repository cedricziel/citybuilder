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

    public var currentTile: TileCoordinate? {
        path.indices.contains(pathIndex) ? path[pathIndex] : nil
    }

    var hasArrived: Bool {
        pathIndex >= path.count - 1
    }

    /// Units of `good` in the basket.
    func units(of good: Good) -> Int {
        basket.first { $0.good == good }?.units ?? 0
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
    /// The hub serving each house, with the road distance to it.
    var hubOf: [EntityID: (hub: EntityID, distance: Int)] = [:]
    /// The houses each hub serves, in entity order.
    var housesOf: [EntityID: [EntityID]] = [:]
    /// The operational hubs, in entity order.
    var hubs: [Building] = []
}

extension World {
    /// Operational buildings with hub data, in entity order.
    func operationalHubs() -> [Building] {
        goodsBuffers().filter { $0.state == .operational && $0.kind.hub != nil }
    }

    /// Each operational house's serving hub: the nearest operational hub of
    /// its owner within the hub's radius by road, ties to the lower ID.
    /// Depends on buildings and roads only, so a tick builds it once.
    func hubService() -> HubService {
        var service = HubService(hubs: operationalHubs())
        let houses = buildings.values
            .filter { $0.kind == .house && $0.state == .operational }
            .sorted { $0.id.raw < $1.id.raw }
        let reach = service.hubs.map { hub in
            (hub, anyAdjacentRoad(anchor: hub.anchor, footprint: hub.footprint).map {
                roadGraph.distances(from: $0, upTo: hub.kind.hub?.radius ?? 0)
            } ?? [:])
        }
        for house in houses {
            guard let road = anyAdjacentRoad(anchor: house.anchor, footprint: house.footprint) else { continue }
            for (hub, distances) in reach where hub.owner == house.owner {
                guard let distance = distances[road] else { continue }
                if service.hubOf[house.id].map({ distance < $0.distance }) ?? true {
                    service.hubOf[house.id] = (hub.id, distance)
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
    mutating func runPorterSystem(service: HubService) {
        advancePorters()
        var inbound = porterInbound()
        var out: [EntityID: Int] = [:]
        for porter in porters {
            out[porter.hub, default: 0] += 1
        }
        for hub in service.hubs {
            dispatchPorters(from: hub, out: out[hub.id] ?? 0, service: service, inbound: &inbound)
        }
    }

    private mutating func advancePorters() {
        var kept: [Porter] = []
        for var porter in porters {
            guard porter.hasArrived else {
                porter.pathIndex += 1
                kept.append(porter)
                continue
            }
            if porter.returning {
                for load in porter.basket {
                    stockpiles[porter.hub]?.deposit(load.good, amount: load.units)
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

    /// Sends porters from `hub` while it has fewer than it keeps out, each
    /// to the served house with the lowest stock ratio.
    private mutating func dispatchPorters(
        from hub: Building, out: Int, service: HubService, inbound: inout [EntityID: [Good: Int]]
    ) {
        let houses = service.housesOf[hub.id] ?? []
        guard let spec = hub.kind.hub,
              let hubRoad = anyAdjacentRoad(anchor: hub.anchor, footprint: hub.footprint)
        else { return }
        var out = out
        while out < spec.porters(serving: houses.count) {
            guard let trip = nextTrip(from: hub.id, among: houses, service: service, inbound: inbound),
                  let houseRoad = anyAdjacentRoad(anchor: trip.anchor, footprint: trip.footprint),
                  let path = roadPath(from: hubRoad, to: houseRoad)
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
            let better = best.map { best in
                lowest.isBelow(best.rank.ratio) || (!best.rank.ratio.isBelow(lowest) && distance < best.rank.distance)
            } ?? true
            if better {
                best = (house, (lowest, distance))
            }
        }
        return best?.house
    }

    /// One basket for `house`: per need the hub holds, in the tier's order,
    /// what keeps the house within capacity and at most one consumption,
    /// up to `units` in all.
    private func fillBasket(for house: EntityID, from hub: EntityID, units: Int, inbound: [Good: Int]) -> [Porter.Load] {
        guard let pop = populations[house] else { return [] }
        let held = stockpiles[hub] ?? Stockpile(capacity: 0)
        var left = units
        var basket: [Porter.Load] = []
        for good in pop.tier.needs(in: culture) where left > 0 {
            let room = pop.stockCapacity(of: good) - pop.stock(of: good) - (inbound[good] ?? 0)
            let take = min(room, pop.nextConsumption(of: good), held.quantity(of: good), left)
            guard take > 0 else { continue }
            basket.append(Porter.Load(good: good, units: take))
            left -= take
        }
        return basket
    }
}
