import Foundation

/// House growth, consumption and tier changes. Spec:
/// `population-and-needs`.
extension World {
    mutating func runPopulationSystem(signatureSources sources: [Building]) {
        // Houses draw from shared buffers, so visit them in a fixed order.
        let houses = buildings.values
            .filter { $0.kind == .house && $0.state == .operational }
            .sorted { $0.id.raw < $1.id.raw }
        let reach = supplyReach()
        let tracked = HouseTier.allNeeds(in: culture)
        for building in houses {
            var pop = populations[building.id] ?? HousePopulation()
            let modifiers = houseModifiers(of: building, sources: sources)
            consumeIfDue(&pop, building: building)
            updateSatisfaction(&pop, of: tracked, building: building, reach: reach)
            updateGrowth(&pop, owner: building.owner, modifiers: modifiers)
            updateTier(&pop, building: building, modifiers: modifiers, reach: reach)
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
            let drawn = consume(good, amount: amount, by: building)
            recordHouseUse(of: good, drawn: drawn, by: building)
            pop.setShort(good, drawn < amount)
        }
    }

    /// A need is met while a buffer on the house's road network holds
    /// the good and the last consumption of it was not short. `goods` is
    /// every tier's needs, so a house knows them before it advances.
    private func updateSatisfaction(_ pop: inout HousePopulation, of goods: [Good], building: Building, reach: SupplyReach) {
        let footprint = BuildingCatalog.spec(for: building.kind).footprint
        for good in goods {
            let inReach = hasGoodInReach(good, fromAnchor: building.anchor, footprint: footprint, reach: reach)
            pop.setSatisfied(good, inReach && !pop.isShort(good))
        }
    }

    /// Inspired houses grow twice as fast; a house above its capacity
    /// shrinks even with its needs met (spec `age-signatures`).
    private func updateGrowth(_ pop: inout HousePopulation, owner: Owner, modifiers: HouseModifiers) {
        pop.ticksAtCurrentSatisfaction &+= 1
        let met = bindingNeeds(of: pop.tier, for: owner, advancing: false).allSatisfy(pop.isSatisfied)
        let streak = pop.ticksAtCurrentSatisfaction
        let capacity = modifiers.capacity(of: pop.tier)
        let growthInterval = HousePopulation.growthIntervalTicks / modifiers.paceDivisor
        let canGrow = met && streak >= growthInterval && pop.population < capacity
        let mustShrink = streak >= HousePopulation.declineIntervalTicks
            && (pop.population > capacity || (!met && pop.population > 0))
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
    private func updateTier(
        _ pop: inout HousePopulation, building: Building, modifiers: HouseModifiers, reach: SupplyReach
    ) {
        let footprint = BuildingCatalog.spec(for: building.kind).footprint
        let canAdvance = pop.tier.next.map { next in
            pop.population >= modifiers.capacity(of: pop.tier)
                && bindingNeeds(of: next, for: building.owner, advancing: true)
                .allSatisfy { hasGoodInReach($0, fromAnchor: building.anchor, footprint: footprint, reach: reach) }
        } ?? false
        let mustDecline = pop.tier.previous != nil
            && !bindingNeeds(of: pop.tier, for: building.owner, advancing: false).allSatisfy(pop.isSatisfied)
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
