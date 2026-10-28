import Foundation

/// Why a crown order cannot be sent now.
public enum OrderDispatchBlock: Equatable, Sendable {
    /// Not an accepted crown order with nothing sent.
    case notDispatchable
    /// The player has no operational town center.
    case noRoad
    /// The connected stores hold fewer units than the order asks for.
    case short(available: Int)
    /// A shipment would arrive after the deadline.
    case late
}

/// Units taken from one store and where they go.
public struct OrderLeg: Equatable, Sendable {
    public let store: EntityID
    public let center: EntityID
    public let amount: Int
    /// Empty when the store is the town center itself.
    public let path: [TileCoordinate]
}

public struct OrderDispatchPlan: Equatable, Sendable {
    public let legs: [OrderLeg]
}

public enum OrderDispatch: Equatable, Sendable {
    case ready(OrderDispatchPlan)
    case unavailable(OrderDispatchBlock)
}

/// Delivering crown orders from the stores. Spec: `orders` / Crown orders
/// are delivered by shipments from the stores.
extension World {
    /// A store that can ship, with the town center it reaches first.
    private struct Source {
        let store: Building
        let center: EntityID
        let path: [TileCoordinate]
    }

    private var playerTownCenters: [Building] {
        goodsBuffers(of: .player).filter { $0.kind == .townCenter && $0.state == .operational }
    }

    /// The operational player stores a shipment can start from: the town
    /// centers and the stores on a road network that reaches one.
    func crownReachableStores() -> [Building] {
        reachableSources().map(\.store)
    }

    private func reachableSources() -> [Source] {
        let centers = playerTownCenters
        let labels = roadGraph.componentLabels()
        var sources: [Source] = []
        for store in goodsBuffers(of: .player) where store.state == .operational {
            if store.kind == .townCenter {
                sources.append(Source(store: store, center: store.id, path: []))
                continue
            }
            guard let road = anyAdjacentRoad(anchor: store.anchor, footprint: BuildingCatalog.spec(for: store.kind).footprint),
                  let component = labels[road]
            else { continue }
            var best: (center: EntityID, path: [TileCoordinate])?
            for center in centers {
                guard let centerRoad = anyAdjacentRoad(anchor: center.anchor, footprint: BuildingCatalog.spec(for: center.kind).footprint),
                      labels[centerRoad] == component, let path = roadPath(from: road, to: centerRoad)
                else { continue }
                if best == nil || path.count < best!.path.count { best = (center.id, path) }
            }
            if let best { sources.append(Source(store: store, center: best.center, path: best.path)) }
        }
        return sources
    }

    private func isDispatchable(_ order: Order) -> Bool {
        order.state == .accepted && order.issuer == .crown && order.delivered == 0
            && !orders.shipments.contains { $0.order == order.id }
    }

    /// Units of the order's good in the stores a shipment can start from.
    /// Goods in producers, on the road and on ships do not count.
    public func orderAvailable(for id: OrderID) -> Int {
        guard let order = order(id), order.issuer == .crown else { return 0 }
        return reachableSources().reduce(0) { $0 + (stockpiles[$1.store.id]?.quantity(of: order.good) ?? 0) }
    }

    /// What sending the order would do, without changing the world.
    public func orderDispatch(for id: OrderID) -> OrderDispatch {
        guard let order = order(id), isDispatchable(order) else { return .unavailable(.notDispatchable) }
        guard !playerTownCenters.isEmpty else { return .unavailable(.noRoad) }
        let holding = reachableSources()
            .map { ($0, stockpiles[$0.store.id]?.quantity(of: order.good) ?? 0) }
            .filter { $0.1 > 0 }
            .sorted { ($0.0.path.count, $0.0.store.id.raw) < ($1.0.path.count, $1.0.store.id.raw) }
        let available = holding.reduce(0) { $0 + $1.1 }
        guard available >= order.quantity else { return .unavailable(.short(available: available)) }
        var left = order.quantity
        var legs: [OrderLeg] = []
        for (source, units) in holding where left > 0 {
            let amount = min(units, left)
            legs.append(OrderLeg(store: source.store.id, center: source.center, amount: amount, path: source.path))
            left -= amount
        }
        // A path of n tiles arrives n - 1 ticks after the dispatch.
        let slowest = legs.map { UInt64(max(0, $0.path.count - 1)) }.max() ?? 0
        guard tickCount + slowest <= order.deadlineTick else { return .unavailable(.late) }
        return .ready(OrderDispatchPlan(legs: legs))
    }

    mutating func applyDispatch(_ id: OrderID) {
        guard case let .ready(plan) = orderDispatch(for: id), let index = orders.orders.firstIndex(where: { $0.id == id }) else { return }
        let good = orders.orders[index].good
        for leg in plan.legs {
            stockpiles[leg.store]?.withdraw(good, amount: leg.amount)
            if leg.path.isEmpty {
                orders.orders[index].delivered += leg.amount
                continue
            }
            let shipment = EntityID(raw: nextEntityRaw)
            nextEntityRaw &+= 1
            orders.shipments.append(OrderShipment(
                id: shipment, order: id, good: good, amount: leg.amount, path: leg.path, from: leg.store, to: leg.center
            ))
        }
    }

    /// One tile a tick, like a carrier. A shipment whose order has closed
    /// goes back to the store it left.
    mutating func advanceOrderShipments() {
        guard !orders.shipments.isEmpty else { return }
        var moving: [OrderShipment] = []
        for var shipment in orders.shipments {
            guard shipment.hasArrived else {
                shipment.pathIndex += 1
                moving.append(shipment)
                continue
            }
            if let index = orders.orders.firstIndex(where: { $0.id == shipment.order && $0.state == .accepted }) {
                orders.orders[index].delivered += shipment.amount
            } else {
                returnShipment(shipment)
            }
        }
        orders.shipments = moving
    }

    /// Puts a shipment whose order closed back into the store it left, or
    /// into any other operational player store with room for it.
    private mutating func returnShipment(_ shipment: OrderShipment) {
        let kept = shipment.amount - (stockpiles[shipment.from]?.deposit(shipment.good, amount: shipment.amount) ?? 0)
        guard kept > 0 else { return }
        let stores = goodsBuffers(of: .player).filter { $0.state == .operational }
        _ = fill(shipment.good, upTo: kept, into: stores)
    }

    // MARK: - Rival orders

    /// Units rival `id` still wants of `good` for an accepted order, so its
    /// buy offer for them rises above the standing target.
    func orderDemand(rival id: RivalID, good: Good) -> Int {
        orders.orders.reduce(0) { $0 + (isOpenOrder($1, from: id, for: good) ? $1.remaining : 0) }
    }

    private func isOpenOrder(_ order: Order, from rival: RivalID, for good: Good) -> Bool {
        order.issuer == .rival(rival) && order.good == good && order.state == .accepted
    }

    /// Counts `units` sold at rival `id`'s port toward its accepted orders
    /// for `good`, lowest number first.
    mutating func countOrderDelivery(rival id: RivalID, good: Good, units: Int) {
        var left = units
        for index in orders.orders.indices where left > 0 {
            let order = orders.orders[index]
            guard isOpenOrder(order, from: id, for: good) else { continue }
            let counted = min(left, order.remaining)
            orders.orders[index].delivered += counted
            left -= counted
        }
    }
}
