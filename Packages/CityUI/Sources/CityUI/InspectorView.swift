import CityCore
import SwiftUI

/// Headless-testable inspector model. Given a world snapshot and a
/// selected EntityID (or tile), returns the human-readable bullets the
/// SwiftUI inspector renders.
public struct InspectorViewModel: Sendable {
    public let bullets: [String]
    /// The gallery's commission button, nil for other buildings.
    public let commission: CommissionButton?
    /// The caravanserai's export picker, nil for other buildings.
    public let exportPicker: ExportPicker?
    /// The rival owning the building, nil for the player's.
    public let rival: RivalSummary?
    /// A rival port's market, nil elsewhere.
    public let market: RivalMarketSection?
    /// A port of any owner, for Route from here; nil elsewhere.
    public let routeStartPort: EntityID?

    public init(
        bullets: [String],
        commission: CommissionButton? = nil,
        exportPicker: ExportPicker? = nil,
        rival: RivalSummary? = nil,
        market: RivalMarketSection? = nil,
        routeStartPort: EntityID? = nil
    ) {
        self.bullets = bullets
        self.commission = commission
        self.exportPicker = exportPicker
        self.rival = rival
        self.market = market
        self.routeStartPort = routeStartPort
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
        let rival = building.owner.rivalID.flatMap(snapshot.rival)
        let culture = snapshot.culture(for: building.owner)
        var houseLines: [String] = []
        if let pop = snapshot.housePopulations[entityID] {
            let needs = pop.tier.needs(in: culture).map { "\($0.rawValue) \(pop.isSatisfied($0) ? "✓" : "✗")" }
            let modifiers = snapshot.houseModifiers[entityID]
            houseLines = [
                "Tier: \(pop.tier.displayName(in: culture))",
                "Residents: \(pop.population)/\((modifiers ?? .none).capacity(of: pop.tier))",
                "Needs: \(needs.joined(separator: " · "))"
            ] + houseNotes(modifiers) + residentLines(house: entityID, population: pop, culture: culture)
        }
        return InspectorViewModel(
            bullets: [
                "Kind: \(building.kind.rawValue)",
                "Anchor: (\(building.anchor.x), \(building.anchor.y))",
                "Footprint: \(spec.footprint.width)×\(spec.footprint.height)",
                "State: \(building.state.rawValue)",
                "Build: \(buildProgress)",
                "Road: \(snapshot.roadDisconnectedBuildings.contains(entityID) ? "none" : "connected")"
            ] + signatureLines(for: building, in: snapshot) + houseLines,
            // A rival's building is read-only.
            commission: rival == nil ? commissionButton(for: building, balance: snapshot.economy.balance) : nil,
            exportPicker: rival == nil ? exportPicker(for: building) : nil,
            rival: rival,
            market: building.kind == .port ? rival.map(RivalMarketSection.init) : nil,
            routeStartPort: building.kind == .port ? entityID : nil
        )
    }
}

/// SwiftUI inspector panel. Hidden when there is no selection.
public struct InspectorView: View {
    public let viewModel: InspectorViewModel
    let onCommission: () -> Void
    let onPickExport: (Good?) -> Void

    public init(
        viewModel: InspectorViewModel,
        onCommission: @escaping () -> Void = {},
        onPickExport: @escaping (Good?) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onCommission = onCommission
        self.onPickExport = onPickExport
    }

    public var body: some View {
        if viewModel.bullets.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 4) {
                if let rival = viewModel.rival {
                    Label {
                        Text(rival.name).font(.caption.bold())
                    } icon: {
                        Circle().fill(Color(hex: rival.colour.hex)).frame(width: 10, height: 10)
                    }
                }
                ForEach(viewModel.bullets, id: \.self) { line in
                    Text(line).font(.caption.monospaced())
                }
                if let commission = viewModel.commission {
                    Button(commission.title, action: onCommission)
                        .font(.caption)
                        .disabled(!commission.isEnabled)
                }
                if let market = viewModel.market {
                    marketSection(market)
                }
                if let picker = viewModel.exportPicker {
                    Picker("Export", selection: Binding(get: { picker.selected }, set: onPickExport)) {
                        ForEach(picker.options, id: \.self) { option in
                            Text(ExportPicker.title(of: option)).tag(option)
                        }
                    }
                    .font(.caption)
                }
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func marketSection(_ market: RivalMarketSection) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Market").font(.caption.bold())
            Text("Sells").font(.caption2.bold())
            ForEach(market.sells, id: \.self) { Text($0).font(.caption.monospaced()) }
            Text("Buys").font(.caption2.bold())
            ForEach(market.buys, id: \.self) { Text($0).font(.caption.monospaced()) }
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
