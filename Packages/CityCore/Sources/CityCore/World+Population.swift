import Foundation

/// House growth, consumption and tier changes. Spec:
/// `population-and-needs`.
extension World {
    mutating func runPopulationSystem(signatureSources sources: [Building], service: HubService) {
        // Houses draw from shared buffers, so visit them in a fixed order.
        let houses = buildings.values
            .filter { $0.kind == .house && $0.state == .operational }
            .sorted { $0.id.raw < $1.id.raw }
        let tracked = HouseTier.allNeeds(in: culture)
        let inbound = porterInbound()
        let feverHeld = Set(feverHouses().map(\.id))
        for building in houses {
            var pop = populations[building.id] ?? HousePopulation()
            let modifiers = houseModifiers(of: building, sources: sources)
            let hub = service.hubOf[building.id]?.hub
            consumeIfDue(&pop, building: building)
            updateSatisfaction(&pop, of: tracked, hub: hub, inbound: inbound[building.id] ?? [:])
            let pastGrace = isPastGrace(pop, owner: building.owner)
            updateGrowth(&pop, owner: building.owner, modifiers: modifiers, pastGrace: pastGrace)
            updateTier(
                &pop, building: building, modifiers: modifiers, hub: hub, pastGrace: pastGrace,
                feverHeld: feverHeld.contains(building.id)
            )
            populations[building.id] = pop
        }
    }

    private mutating func consumeIfDue(_ pop: inout HousePopulation, building: Building) {
        guard tickCount.isMultiple(of: HousePopulation.consumptionIntervalTicks) else { return }
        guard pop.population > 0 else {
            // Otherwise a house that emptied in a shortage never refills.
            pop.clearShortages()
            return
        }
        for good in pop.tier.needs(in: culture) {
            let amount = HousePopulation.amount(of: good, residents: pop.population)
            let drawn = pop.takeStock(good, amount: amount)
            recordHouseUse(of: good, drawn: drawn, by: building)
            pop.recordConsumption(of: good, short: drawn < amount)
        }
        // Only a need that binds the house counts, so cloth holds no run
        // before Weaving that would cut the grace short once it binds.
        pop.keepShortIntervals(for: bindingNeeds(of: pop.tier, for: building.owner, advancing: false))
    }

    /// Consumption intervals in a row a need of `tier` may stay short
    /// before a house declines. Spec: `population-and-needs` / Houses
    /// decline only after a grace period.
    func declineGrace(of tier: HouseTier) -> Int {
        difficulty.declineGraceIntervals(base: tier.declineGrace)
    }

    /// A house declines only once a need that binds it has been short for
    /// its grace. An empty house eats nothing and has no run to count, so
    /// it falls as soon as a need is unmet and can start again.
    private func isPastGrace(_ pop: HousePopulation, owner: Owner) -> Bool {
        let binding = bindingNeeds(of: pop.tier, for: owner, advancing: false)
        guard pop.population > 0 else { return !binding.allSatisfy(pop.isSatisfied) }
        let grace = declineGrace(of: pop.tier)
        return binding.contains { pop.shortIntervals(of: $0) >= grace }
    }

    /// A need of the house's tier is met while its last consumption was not
    /// short and its stock plus what porters bring covers the next one; any
    /// other good while the house's hub holds it. `goods` is every tier's
    /// needs, so a house knows them before it advances. Spec:
    /// `population-and-needs` / Town center supplies house needs.
    private func updateSatisfaction(_ pop: inout HousePopulation, of goods: [Good], hub: EntityID?, inbound: [Good: Int]) {
        let needs = pop.tier.needs(in: culture)
        for good in goods {
            let met = if needs.contains(good) {
                !pop.isShort(good) && pop.stock(of: good) + (inbound[good] ?? 0) >= pop.nextConsumption(of: good)
            } else {
                hubHolds(good, hub)
            }
            pop.setSatisfied(good, met)
        }
    }

    /// True when `hub` holds some `good`.
    func hubHolds(_ good: Good, _ hub: EntityID?) -> Bool {
        hub.map { (stockpiles[$0]?.quantity(of: good) ?? 0) > 0 } ?? false
    }

    /// Inspired houses grow twice as fast; a house above its capacity
    /// shrinks even with its needs met (spec `age-signatures`).
    private func updateGrowth(_ pop: inout HousePopulation, owner: Owner, modifiers: HouseModifiers, pastGrace: Bool) {
        pop.ticksAtCurrentSatisfaction &+= 1
        let met = bindingNeeds(of: pop.tier, for: owner, advancing: false).allSatisfy(pop.isSatisfied)
        let streak = pop.ticksAtCurrentSatisfaction
        let capacity = modifiers.capacity(of: pop.tier)
        let growthInterval = HousePopulation.growthIntervalTicks / modifiers.paceDivisor
        let canGrow = met && streak >= growthInterval && pop.population < capacity
        let mustShrink = streak >= HousePopulation.declineIntervalTicks
            && (pop.population > capacity || (pastGrace && pop.population > 0))
        if canGrow {
            pop.population &+= 1
            pop.ticksAtCurrentSatisfaction = 0
        } else if mustShrink {
            pop.population &-= 1
            pop.ticksAtCurrentSatisfaction = 0
        }
    }

    /// Spec: `population-and-needs` / Houses advance and decline
    /// between tiers.
    private func updateTier( // swiftlint:disable:this function_parameter_count
        _ pop: inout HousePopulation, building: Building, modifiers: HouseModifiers, hub: EntityID?, pastGrace: Bool,
        feverHeld: Bool
    ) {
        // Spec: `population-and-needs` / Market hubs gate tier advancement.
        // A need the house already eats counts while it is met: porters keep
        // its stock, and they may have just emptied the hub into it. A need
        // the next tier adds counts only while the serving hub holds it.
        let eaten = Set(pop.tier.needs(in: culture))
        // Spec: `seasonal-events` / Fever holds a district back.
        let canAdvance = !feverHeld && pop.tier.next.map { next in
            pop.population >= modifiers.capacity(of: pop.tier)
                && bindingNeeds(of: next, for: building.owner, advancing: true).allSatisfy { good in
                    eaten.contains(good) ? pop.isSatisfied(good) : hubHolds(good, hub)
                }
        } ?? false
        let mustDecline = pop.tier.previous != nil && pastGrace
        guard canAdvance || mustDecline else {
            pop.ticksAtTierCondition = 0
            return
        }
        pop.ticksAtTierCondition &+= 1
        guard pop.ticksAtTierCondition >= HousePopulation.tierChangeTicks / modifiers.paceDivisor else { return }
        pop.ticksAtTierCondition = 0
        if canAdvance, let next = pop.tier.next {
            pop.tier = next
        } else if let previous = pop.tier.previous {
            pop.tier = previous
            pop.population = min(pop.population, modifiers.capacity(of: previous))
        }
        pop.keepShortages(for: pop.tier.needs(in: culture))
    }

    /// The needs of `tier` that hold a house of `owner` to it (spec
    /// `population-and-needs` / Cloth binds merchants only where it can be
    /// made). A player's house needs cloth to advance to merchants always,
    /// but to stay or grow there only once Weaving is researched, so saves
    /// from before the wool chain and the Guild Town scenario keep their
    /// merchants. A rival cannot make or buy cloth, so it never binds one.
    func bindingNeeds(of tier: HouseTier, for owner: Owner, advancing: Bool) -> [Good] {
        let needs = tier.needs(in: culture)
        let clothBinds = owner == .player && (advancing || research.isResearched(.weaving))
        return clothBinds ? needs : needs.filter { $0 != .cloth }
    }
}
