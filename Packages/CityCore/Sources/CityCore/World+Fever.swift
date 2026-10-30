import Foundation

/// Fever: houses in the marked district can't advance and lose residents,
/// unless a fuelled physician is near. Spec: `seasonal-events` / Fever
/// holds a district back.
extension World {
    static let physicianReach = 8

    /// The player houses a fever under way holds back: in the marked
    /// district, with no fuelled player physician within 8 tiles. Entity order.
    func feverHouses() -> [Building] {
        guard seasonalEvents.active?.event.effect == .fever, let area = seasonalEvents.marked else { return [] }
        let physicians = buildings.values.filter {
            $0.kind == .physician && $0.owner == .player && $0.state == .operational && $0.fuelled
        }
        return buildings.values
            .filter { house in
                house.kind == .house && house.owner == .player && house.state == .operational && area.contains(house)
                    && !physicians.contains { Self.footprintDistance($0, house) <= Self.physicianReach }
            }
            .sorted { $0.id.raw < $1.id.raw }
    }

    /// Every leave interval from the onset, the last one on the season's
    /// last tick, each held-back house of 2 or more loses one resident. Not
    /// a shortage: the decline grace never sees it.
    mutating func runFeverSystem(events: inout [WorldEvent]) {
        guard let active = seasonalEvents.active, (tickCount - active.startTick + 1).isMultiple(of: difficulty.feverLeaveTicks)
        else { return }
        for house in feverHouses() where (populations[house.id]?.population ?? 0) >= 2 {
            populations[house.id]?.population -= 1
            seasonalEvents.fever?.residentsLeft += 1
            seasonalEvents.counters.residentsLeftWithFever += 1
            events.append(.residentLeftWithFever(house: house.id))
        }
    }
}
