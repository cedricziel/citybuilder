import CityCore

extension BuildingKind {
    /// The building's name in a sentence, lower case and in full ("town center", "charcoal burner"):
    /// the raw value names it in full, the palette's label is short ("Town Ctr.").
    var spokenName: String {
        rawValue.replacingOccurrences(of: "-", with: " ")
    }
}

/// Spec: `platform-shells` / Market lines in the inspector.
extension InspectorViewModel {
    /// A house's stock of each need of its tier, and the market serving it.
    static func houseMarketLines(
        house: EntityID, population: HousePopulation, culture: Culture, in snapshot: WorldSnapshot
    ) -> [String] {
        let stock = population.tier.needs(in: culture).map { good in
            "\(goodName(good)) \(population.stock(of: good))/\(population.stockCapacity(of: good))"
        }
        var lines = stock.isEmpty ? [] : [GameText.string("inspector.stock", stock.joined(separator: " · "))]
        if let serving = snapshot.marketServing[house], let hub = snapshot.buildings[serving.hub] {
            lines.append(GameText.string("inspector.market", hub.kind.spokenName, GameText.string("count.roadTile", serving.distance)))
        }
        return lines
    }

    /// The houses an operational hub serves, its reach, and its porters out of those it keeps.
    static func hubLines(for building: Building, in snapshot: WorldSnapshot) -> [String] {
        guard let spec = building.kind.hub, building.state == .operational else { return [] }
        let served = snapshot.marketServing.values.count { $0.hub == building.id }
        let out = snapshot.porters.count { $0.hub == building.id }
        return [
            GameText.string("inspector.serves", GameText.string("count.house", served), spec.radius),
            GameText.string("inspector.porters", out, spec.porters(serving: served))
        ]
    }
}
