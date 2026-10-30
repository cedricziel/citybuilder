import Foundation

/// The festival: two town orders, and when both are filled, four seasons of
/// faster advancement and more tax near the market. Spec: `seasonal-events`
/// / The town asks for a festival; `orders` / The town issues festival orders.
extension World {
    private static let seasonTicks = CalendarState.ticksPerSeason
    /// Seasons a held festival runs, the one it is held in included.
    static let festivalSeasons: UInt64 = 4
    /// A festival house advances twice as fast: 60 ticks instead of 120.
    static let festivalPaceDivisor: UInt64 = 2

    public var isFestivalRunning: Bool {
        seasonalEvents.festivalUntil.map { tickCount <= $0 } ?? false
    }

    /// The festival's first season, when a crowd fills the plaza.
    var isFestivalCrowd: Bool {
        seasonalEvents.festivalUntil.map { tickCount + (Self.festivalSeasons - 1) * Self.seasonTicks <= $0 } ?? false
    }

    /// The town's festival templates for the player's culture: bread, then
    /// the luxury.
    var festivalTemplates: [OrderTemplate] {
        [.bread, culture.luxury].compactMap { good in
            OrderTemplate.allCases.first { $0.issuer == .town && $0.good == good }
        }
    }

    /// Half a season of the town's output of the template's good over the
    /// last four closed seasons, clamped to the template's bounds and capped
    /// at what the stores a shipment starts from can hold. Nil when the town
    /// made none of it.
    func festivalQuantity(for template: OrderTemplate) -> Int? {
        guard let half = recentOrderUnits(for: template) else { return nil }
        let cap = orderStoreCapacity(forCrown: true) * OrderRules.storeCapPercent / 100
        let quantity = min(max(half, template.minUnits), template.maxUnits, cap)
        return quantity > 0 ? quantity : nil
    }

    /// The festival's quantities, or nil when it is not eligible: the
    /// player needs an operational marketplace and both goods made.
    func festivalQuantities() -> [(OrderTemplate, Int)]? {
        let hasMarket = buildings.values.contains {
            $0.kind == .marketplace && $0.owner == .player && $0.state == .operational
        }
        let templates = festivalTemplates
        guard hasMarket, templates.count == 2 else { return nil }
        let sized = templates.compactMap { template in festivalQuantity(for: template).map { (template, $0) } }
        return sized.count == templates.count ? sized : nil
    }

    /// Issues the town's two orders, due at the end of the difficulty's
    /// window, and keeps the festival open until a tick after it.
    mutating func requestFestival(_ onset: SeasonalEventOnset, events: inout [WorldEvent]) {
        guard let sized = festivalQuantities() else { return }
        let window = UInt64(difficulty.festivalWindowSeasons) * Self.seasonTicks
        let deadline = tickCount / Self.seasonTicks * Self.seasonTicks + window - 1
        let ids = sized.map { template, quantity in
            offer(template, by: .town, quantity: quantity, offerEndsTick: deadline + 1, deadlineTick: deadline, events: &events)
        }
        seasonalEvents.festival = FestivalRequest(orders: ids)
        seasonalEvents.active = ActiveSeasonalEvent(event: onset.event, startTick: tickCount, lastTick: deadline + 1)
        events.append(.seasonalEventWarned(event: onset.event, onset: onset.season))
    }

    /// Holds the festival once both orders are filled; calls it off once
    /// either closes unfilled.
    mutating func settleFestival(events: inout [WorldEvent]) {
        guard let request = seasonalEvents.festival, let active = seasonalEvents.active else { return }
        let pair = request.orders.compactMap(order)
        if pair.count == request.orders.count, pair.allSatisfy({ $0.state == .fulfilled }) {
            let heldSeason = tickCount / Self.seasonTicks
            seasonalEvents.festivalUntil = (heldSeason + Self.festivalSeasons) * Self.seasonTicks - 1
            seasonalEvents.festival = nil
            seasonalEvents.active = nil
            events.append(.seasonalEventStarted(event: active.event))
        } else if pair.count < request.orders.count || pair.contains(where: { !$0.state.isOpen && $0.state != .fulfilled }) {
            endSeasonalEvent(events: &events)
        }
    }

    /// Closes the festival's open orders: half a festival is no festival.
    /// Shipments on the road go back to their stores.
    mutating func callOffFestival(events: inout [WorldEvent]) {
        for id in seasonalEvents.festival?.orders ?? [] {
            guard let index = orderIndex(id) else { continue }
            switch orders.orders[index].state {
            case .offered:
                expire(index, events: &events)
            case .accepted:
                fail(index, events: &events)
            default:
                break
            }
        }
        seasonalEvents.festival = nil
    }

    /// Player houses within the reach of an operational player marketplace
    /// while a festival runs; none otherwise.
    func festivalHouses(service: HubService) -> Set<EntityID> {
        guard isFestivalRunning else { return [] }
        let reaches = service.hubs
            .filter { $0.kind == .marketplace && $0.owner == .player }
            .compactMap { service.reach[$0.id] }
        guard !reaches.isEmpty else { return [] }
        let houses = buildings.values.filter { $0.kind == .house && $0.owner == .player && $0.state == .operational }
        return Set(houses.filter { house in
            adjacentRoads(anchor: house.anchor, footprint: house.footprint).contains { road in
                reaches.contains { $0[road] != nil }
            }
        }.map(\.id))
    }

    /// `tax` with the difficulty's festival bonus, rounded down.
    func festivalTax(_ tax: Int64) -> Int64 {
        tax * Int64(100 + difficulty.festivalTaxBonusPercent) / 100
    }
}
