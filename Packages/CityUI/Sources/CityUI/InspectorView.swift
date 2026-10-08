import CityCore
import SwiftUI

/// Headless-testable inspector model. Given a world snapshot and a
/// selected EntityID (or tile), returns the human-readable bullets the
/// SwiftUI inspector renders.
public struct InspectorViewModel: Sendable {
    public let bullets: [String]

    public init(bullets: [String]) {
        self.bullets = bullets
    }

    /// Build an inspector model from a snapshot + a target tile. Returns
    /// an empty model when the tile is unoccupied — the view hides itself.
    public static func make(from snapshot: WorldSnapshot, tile: TileCoordinate, buildings: [EntityID: Building]) -> InspectorViewModel {
        guard let entityID = snapshot.occupiedTiles[tile],
              let building = buildings[entityID]
        else { return InspectorViewModel(bullets: []) }

        let spec = BuildingCatalog.spec(for: building.kind)
        let buildProgress = if building.state == .operational {
            "ready"
        } else {
            "\(building.ticksSincePlacement)/\(spec.buildDurationTicks) ticks"
        }
        var houseLines: [String] = []
        if let pop = snapshot.housePopulations[entityID] {
            let needs = pop.tier.needs(in: snapshot.culture).map { "\($0.rawValue) \(pop.isSatisfied($0) ? "✓" : "✗")" }
            houseLines = [
                "Tier: \(pop.tier.displayName(in: snapshot.culture))",
                "Residents: \(pop.population)/\(pop.capacity)",
                "Needs: \(needs.joined(separator: " · "))"
            ] + residentLines(house: entityID, population: pop, culture: snapshot.culture)
        }
        return InspectorViewModel(bullets: [
            "Kind: \(building.kind.rawValue)",
            "Anchor: (\(building.anchor.x), \(building.anchor.y))",
            "Footprint: \(spec.footprint.width)×\(spec.footprint.height)",
            "State: \(building.state.rawValue)",
            "Build: \(buildProgress)",
            "Road: \(snapshot.roadDisconnectedBuildings.contains(entityID) ? "none" : "connected")"
        ] + houseLines)
    }
}

/// SwiftUI inspector panel. Hidden when there is no selection.
public struct InspectorView: View {
    public let viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        if viewModel.bullets.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(viewModel.bullets, id: \.self) { line in
                    Text(line).font(.caption.monospaced())
                }
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

extension InspectorViewModel {
    /// Up to three named residents with the house's wish. Spec:
    /// `platform-shells` / Inspector introduces residents.
    static func residentLines(house: EntityID, population: HousePopulation, culture: Culture) -> [String] {
        let wish = population.wish(in: culture).map { "wants \(GoodsCatalog.spec(for: $0).displayName.lowercased())" }
            ?? "content"
        let tier = population.tier.displayName(in: culture)
        let count = min(3, Int(population.population))
        return ResidentNames.names(for: house, culture: culture, count: count).map { "\($0) · \(tier) · \(wish)" }
    }
}
