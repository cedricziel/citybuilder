import Foundation

/// House growth, consumption and tier changes. Spec:
/// `population-and-needs`.
extension World {
    mutating func runPopulationSystem(signatureSources sources: [Building]) {
        // Houses draw from shared buffers, so visit them in a fixed order.
        let houses = buildings.values
            .filter { $0.kind == .house && $0.state == .operational }
            .sorted { $0.id.raw < $1.id.raw }
        for building in houses {
            var pop = populations[building.id] ?? HousePopulation()
            let modifiers = houseModifiers(of: building, sources: sources)
            consumeIfDue(&pop, building: building)
            updateSatisfaction(&pop, building: building)
            updateGrowth(&pop, modifiers: modifiers)
            updateTier(&pop, building: building, modifiers: modifiers)
            populations[building.id] = pop
        }
    }

    private mutating func consumeIfDue(_ pop: inout HousePopulation, building: Building) {
        guard pop.population > 0, tickCount.isMultiple(of: HousePopulation.consumptionIntervalTicks) else { return }
        for good in pop.tier.needs(in: culture) {
            let amount = pop.consumption(of: good, in: culture)
            pop.setShort(good, consume(good, amount: amount, by: building) < amount)
        }
    }

    /// A need is met while a buffer on the house's road network holds
    /// the good and the last consumption of it was not short.
    private func updateSatisfaction(_ pop: inout HousePopulation, building: Building) {
        let footprint = BuildingCatalog.spec(for: building.kind).footprint
        for good in HouseTier.merchants.needs(in: culture) {
            let inReach = hasGoodInReach(good, fromAnchor: building.anchor, footprint: footprint)
            pop.setSatisfied(good, inReach && !pop.isShort(good))
        }
    }

    /// Inspired houses grow twice as fast; a house above its capacity
    /// shrinks even with its needs met (spec `age-signatures`).
    private func updateGrowth(_ pop: inout HousePopulation, modifiers: HouseModifiers) {
        pop.ticksAtCurrentSatisfaction &+= 1
        let met = pop.allNeedsSatisfied(in: culture)
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
    private func updateTier(_ pop: inout HousePopulation, building: Building, modifiers: HouseModifiers) {
        let footprint = BuildingCatalog.spec(for: building.kind).footprint
        let canAdvance = pop.tier.next.map { next in
            pop.population >= modifiers.capacity(of: pop.tier)
                && next.needs(in: culture).allSatisfy { hasGoodInReach($0, fromAnchor: building.anchor, footprint: footprint) }
        } ?? false
        let mustDecline = pop.tier.previous != nil && !pop.allNeedsSatisfied(in: culture)
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
}
