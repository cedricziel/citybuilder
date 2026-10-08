import Foundation

/// Mead hall upkeep, forum tax and temple garden knowledge, one building
/// at a time so per-owner totals can sum them. Spec: `culture-signatures`.
extension World {
    /// How strongly `effect` reaches `target` from the culture signatures
    /// among `sources`: 0 when none covers it, 1 unserved, 2 served.
    /// Several covering sources count once, at the best rate (design D3).
    static func cultureRate(of effect: SignatureEffect, on target: Building, from sources: [Building]) -> Int64 {
        guard isAffected(target.kind, by: effect) else { return 0 }
        var rate: Int64 = 0
        for source in sources where source.id != target.id && haveSameOwner(source, target) {
            let distance = footprintDistance(source, target)
            guard source.kind.signatureReaches.contains(where: { $0.effect == effect && distance <= $0.tiles })
            else { continue }
            rate = max(rate, source.servedRate)
        }
        return rate
    }

    /// The house's tax before the monument bonus: its tier tax plus the
    /// forum's 1 or 2 per resident (design D5).
    func houseTax(house id: EntityID, population: HousePopulation, sources: [Building]) -> Int64 {
        let forum = buildings[id].map { Self.cultureRate(of: .marketTax, on: $0, from: sources) } ?? 0
        return Int64(population.population) * (population.tier.taxPerResident + forum) * Economy.taxPerPopUnit
    }

    /// Catalog upkeep, halved (rounded down) near a mead hall and waived
    /// near a served one, before difficulty scaling (design D4).
    func upkeep(of building: Building, sources: [Building]) -> Int64 {
        let upkeep = BuildingCatalog.spec(for: building.kind).upkeep
        guard upkeep > 0 else { return 0 }
        switch Self.cultureRate(of: .upkeepRelief, on: building, from: sources) {
        case 0: return upkeep
        case 1: return upkeep / 2
        default: return 0
        }
    }

    /// Knowledge the house adds each resident interval: 1 per resident at
    /// citizens or above, plus the temple garden's 1 or 2 (design D6).
    func residentKnowledge(house id: EntityID, population: HousePopulation, sources: [Building]) -> Int {
        guard population.contemplates else { return 0 }
        let temple = buildings[id].map { Self.cultureRate(of: .contemplation, on: $0, from: sources) } ?? 0
        return Int(population.population) * (1 + Int(temple))
    }
}
