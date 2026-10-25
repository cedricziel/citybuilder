import Foundation

/// Orders: issuing, the board and settlement. Spec: `orders`. A separate
/// system with its own tick step; it never draws from the world's RNG.
extension World {
    private static let seasonTicks = CalendarState.ticksPerSeason

    /// After the calendar, before the goals: advances shipments, settles
    /// orders, and at a season boundary issues new ones (design D10).
    mutating func runOrderSystem(events: inout [WorldEvent]) {
        guard calendar.isActive, !economy.gameOver else { return }
        advanceOrderShipments()
        settleOrders(events: &events)
        guard tickCount > 0, tickCount.isMultiple(of: Self.seasonTicks) else { return }
        issueOrders(events: &events)
    }

    // MARK: - Queries

    public func order(_ id: OrderID) -> Order? {
        orders.orders.first { $0.id == id }
    }

    /// The board's order: accepted orders first, then offers, each by
    /// deadline and then number.
    public var boardOrders: [Order] {
        orders.orders.filter(\.state.isOpen).sorted {
            ($0.state == .offered ? 1 : 0, $0.deadlineTick, $0.id) < ($1.state == .offered ? 1 : 0, $1.deadlineTick, $1.id)
        }
    }

    public var acceptedOrderCount: Int {
        orders.orders.count { $0.state == .accepted }
    }

    // MARK: - Settlement

    private mutating func settleOrders(events: inout [WorldEvent]) {
        for index in orders.orders.indices {
            let order = orders.orders[index]
            switch order.state {
            case .accepted where order.delivered >= order.quantity:
                fulfil(index, events: &events)
            case .accepted where tickCount > order.deadlineTick:
                fail(index, events: &events)
            case .offered where tickCount >= order.offerEndsTick:
                orders.orders[index].state = .expired
                orders.orders[index].closedTick = tickCount
                events.append(.orderExpired(order: order.id))
            default:
                break
            }
        }
        trimClosedOrders()
    }

    private mutating func fulfil(_ index: Int, events: inout [WorldEvent]) {
        let order = orders.orders[index]
        orders.orders[index].state = .fulfilled
        orders.orders[index].closedTick = tickCount
        economy.credit(order.reward)
        orders.favour.adjust(order.issuer, by: order.favourGain)
        orders.fulfilledCount += 1
        events.append(.orderFulfilled(order: order.id, reward: order.reward))
    }

    /// Costs favour, never money; what was delivered was paid for already.
    private mutating func fail(_ index: Int, events: inout [WorldEvent]) {
        let order = orders.orders[index]
        orders.orders[index].state = .failed
        orders.orders[index].closedTick = tickCount
        orders.favour.adjust(order.issuer, by: -order.favourLoss)
        orders.failedCount += 1
        events.append(.orderFailed(order: order.id))
    }

    private mutating func trimClosedOrders() {
        let closed = orders.orders.filter { !$0.state.isOpen }
        guard closed.count > OrderRules.closedOrdersKept else { return }
        let drop = Set(closed.prefix(closed.count - OrderRules.closedOrdersKept).map(\.id))
        orders.orders.removeAll { drop.contains($0.id) }
    }

    // MARK: - Commands

    mutating func applyAcceptOrder(_ id: OrderID, events: inout [WorldEvent]) {
        guard let index = orderIndex(id), orders.orders[index].state == .offered,
              acceptedOrderCount < OrderRules.maxAccepted
        else { return }
        orders.orders[index].state = .accepted
        events.append(.orderAccepted(order: id))
    }

    mutating func applyDeclineOrder(_ id: OrderID) {
        guard let index = orderIndex(id), orders.orders[index].state == .offered else { return }
        orders.orders[index].state = .declined
        orders.orders[index].closedTick = tickCount
    }

    /// Only an accepted order with nothing sent or delivered can be given up.
    mutating func applyAbandonOrder(_ id: OrderID, events: inout [WorldEvent]) {
        guard let index = orderIndex(id), orders.orders[index].state == .accepted,
              orders.orders[index].delivered == 0, !orders.shipments.contains(where: { $0.order == id })
        else { return }
        fail(index, events: &events)
    }

    private func orderIndex(_ id: OrderID) -> Int? {
        orders.orders.firstIndex { $0.id == id }
    }

    // MARK: - Issuing

    private mutating func issueOrders(events: inout [WorldEvent]) {
        let season = Int(tickCount / Self.seasonTicks)
        guard season >= OrderRules.firstSeason else { return }
        let every = max(1, (age.orderEvery * difficulty.orderCadencePercent + 50) / 100)
        if (season - OrderRules.firstSeason).isMultiple(of: every) {
            issueCrownOrder(events: &events)
        }
        let slots = rivals.sorted { $0.id < $1.id }.filter { (season + Int($0.id)).isMultiple(of: OrderRules.rivalEverySeasons) }
        for rival in slots {
            issueRivalOrder(for: rival, events: &events)
        }
    }

    private var offerCount: Int {
        orders.orders.count { $0.state == .offered }
    }

    private mutating func issueCrownOrder(events: inout [WorldEvent]) {
        guard offerCount < OrderRules.boardSize else { return }
        var candidates = OrderTemplate.allCases.filter { $0.issuer == .crown && isAvailable($0) }
            .compactMap { template in orderQuantity(for: template).map { (template, $0) } }
        let last = orders.orders.last { $0.issuer == .crown }?.good
        let others = candidates.filter { $0.0.good != last }
        if !others.isEmpty { candidates = others }
        issue(from: candidates, by: .crown, events: &events)
    }

    private mutating func issueRivalOrder(for rival: RivalTown, events: inout [WorldEvent]) {
        guard offerCount < OrderRules.boardSize,
              !orders.orders.contains(where: { $0.issuer == .rival(rival.id) && $0.state.isOpen })
        else { return }
        let stock = rivalStock(rival.id)
        let candidates = OrderTemplate.allCases
            .filter { $0.issuer == .rival && isAvailable($0) && RivalMarket.buyQuantity(of: $0.good, stock: stock) > 0 }
            .compactMap { template in orderQuantity(for: template).map { (template, $0) } }
            .filter { Int64($0.1) * $0.0.good.rivalBuyPrice <= rival.treasury }
        issue(from: candidates, by: .rival(rival.id), events: &events)
    }

    private func isAvailable(_ template: OrderTemplate) -> Bool {
        template.minAge.map { age >= $0 } ?? true
    }

    private mutating func issue(from candidates: [(OrderTemplate, Int)], by issuer: OrderIssuer, events: inout [WorldEvent]) {
        guard !candidates.isEmpty else { return }
        var rng = DeterministicRNG(seed: seed &+ UInt64(orders.nextOrderRaw) &* 0x9E37_79B9_7F4A_7C15)
        let (template, quantity) = candidates[Int(rng.next() % UInt64(candidates.count))]
        let window = max(1, (template.seasons * difficulty.orderWindowPercent + 50) / 100)
        let order = Order(
            id: orders.nextOrderRaw, template: template, issuer: issuer, good: template.good, quantity: quantity,
            reward: Int64(quantity) * template.good.basePrice * Int64(template.rewardPercent) / 100,
            favourGain: template.favourGain, favourLoss: template.favourLoss, issuedTick: tickCount,
            offerEndsTick: tickCount + UInt64(OrderRules.offerSeasons) * Self.seasonTicks,
            deadlineTick: tickCount + UInt64(window) * Self.seasonTicks
        )
        orders.nextOrderRaw += 1
        orders.orders.append(order)
        events.append(.orderOffered(order: order.id, issuer: issuer))
    }

    // MARK: - Size

    /// The quantity `template` would ask for now, nil when the town does
    /// not make enough of the good (design D5).
    func orderQuantity(for template: OrderTemplate) -> Int? {
        let closed = statistics.seasons.suffix(OrderRules.outputWindowSeasons)
        let recent = closed.reduce(0) { $0 + ($1.goods[template.good]?.made ?? 0) }
        guard !closed.isEmpty, recent > 0 else { return nil }
        let units = recent * template.seasons * template.sizePercent / (closed.count * 100)
        let scaled = units * difficulty.orderSizePercent / 100
        let cap = orderStoreCapacity(of: template.good, forCrown: template.issuer == .crown) * OrderRules.storeCapPercent / 100
        let quantity = min(scaled, template.maxUnits, cap)
        return quantity >= template.minUnits ? quantity : nil
    }

    /// What the player's stores can hold of `good`: the stores a crown
    /// shipment can reach, or every store for a rival, whose goods go by ship.
    func orderStoreCapacity(of _: Good, forCrown: Bool) -> Int {
        let stores = forCrown ? crownReachableStores().map(\.id) : goodsBuffers(of: .player).filter { $0.state == .operational }.map(\.id)
        return stores.reduce(0) { $0 + (stockpiles[$1]?.capacity ?? 0) }
    }

    // MARK: - Favour perks

    /// Research cost saved by the crown's favour, in percent.
    var crownResearchDiscountPercent: Int {
        OrderRules.crownResearchDiscountPercent[OrderRules.step(of: orders.favour.crown)]
    }

    /// Price improvement at rival `id`'s port, in percent.
    func rivalPriceBonusPercent(_ id: RivalID) -> Int {
        OrderRules.rivalPriceBonusPercent[OrderRules.step(of: orders.favour.value(for: .rival(id)))]
    }

    /// The unit price at rival `id`'s port from the player's side, with
    /// favour. Spec: `rival-trade` / Favour improves a rival's prices.
    func rivalPrice(_ good: Good, _ direction: TradeDirection, from id: RivalID) -> Int64 {
        good.rivalPrice(direction, bonusPercent: rivalPriceBonusPercent(id))
    }
}
