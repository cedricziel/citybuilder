import Foundation

/// Fuel burns and signature reach. Spec: `age-signatures`.
extension World {
    /// Runs after `advanceBuildings` and before production, so production
    /// sees this tick's fuel state (design D5).
    mutating func runSignatureSystem(events: inout [WorldEvent]) {
        burnFuel(events: &events)
    }

    private mutating func burnFuel(events: inout [WorldEvent]) {
        let burners = buildings.values
            .compactMap { building in building.kind.fuel.map { (building, $0) } }
            .filter { $0.0.state == .operational && tickCount.isMultiple(of: $0.1.intervalTicks) }
            .sorted { $0.0.id.raw < $1.0.id.raw }
        for (burner, fuel) in burners {
            let burned = (stockpiles[burner.id]?.quantity(of: fuel.good) ?? 0) >= fuel.amount
            if burned {
                stockpiles[burner.id]?.withdraw(fuel.good, amount: fuel.amount)
            } else if burner.fuelled {
                events.append(.fuelRanOut(building: burner.id, kind: burner.kind))
            }
            buildings[burner.id]?.fuelled = burned
        }
    }

    /// Operational signature buildings whose effects are on: fuelled when
    /// they burn fuel, commissioned when they are galleries. Sorted by ID;
    /// at most a few dozen, so callers build it once per tick.
    func activeSignatureSources() -> [Building] {
        buildings.values
            .filter { $0.state == .operational && $0.isSignatureActive }
            .sorted { $0.id.raw < $1.id.raw }
    }

    /// Kinds of the `sources` whose `effect`-matching reach covers
    /// `target`, each with the matching effect. Several sources of one
    /// kind count once.
    static func signatureEffects(
        on target: Building,
        from sources: [Building],
        where matches: (SignatureEffect) -> Bool
    ) -> [BuildingKind: SignatureEffect] {
        var result: [BuildingKind: SignatureEffect] = [:]
        for source in sources where source.id != target.id && haveSameOwner(source, target) {
            let distance = footprintDistance(source, target)
            for reach in source.kind.signatureReaches where distance <= reach.tiles && matches(reach.effect) {
                result[source.kind] = reach.effect
            }
        }
        return result
    }

    /// Extra progress a workshop gains this tick (design D4).
    func workshopBonus(for workshop: Building, sources: [Building]) -> UInt64 {
        guard workshop.kind.isWorkshop, !sources.isEmpty else { return 0 }
        let effects = Self.signatureEffects(on: workshop, from: sources) {
            if case .workshopSpeed = $0 { return true }
            return false
        }
        return UInt64(effects.values.count { effect in
            guard case let .workshopSpeed(every) = effect else { return false }
            return tickCount.isMultiple(of: every)
        })
    }
}
