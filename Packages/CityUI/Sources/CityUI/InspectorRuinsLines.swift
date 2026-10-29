import CityCore
import Foundation

/// The demolish control when it costs money: clearing ruins, or pulling
/// down a burning building as a firebreak. Spec: `platform-shells` / Ruins
/// inspector.
public struct DemolishButton: Equatable, Sendable {
    public let title: String
    public let isEnabled: Bool
}

extension InspectorViewModel {
    /// "Clear ruins — $15" for ruins, "Pull down — $30" for a burning
    /// building, nil where demolishing is free.
    static func demolishButton(for building: Building, balance: Int64) -> DemolishButton? {
        let isRuins = building.kind == .ruins
        guard isRuins || building.state == .burning else { return nil }
        let fee = World.clearingFee(for: building)
        let money = HUDViewModel.formatMoney(fee, locale: .current)
        return DemolishButton(title: isRuins ? "Clear ruins — \(money)" : "Pull down — \(money)", isEnabled: balance >= fee)
    }

    /// "Burnt down in Summer 1202" for ruins, "Burning" for a building on
    /// fire, none otherwise.
    static func fireLines(for building: Building, in snapshot: WorldSnapshot) -> [String] {
        if building.state == .burning { return ["Burning"] }
        guard let tick = building.burntAtTick else { return [] }
        return ["Burnt down in \(snapshot.calendar.date(atTick: tick).displayText)"]
    }

    /// "Ruins of a house" for ruins, the palette name otherwise.
    static func title(of building: Building) -> String {
        guard let kind = building.ruinOf else { return BuildTool.place(building.kind).displayName }
        return "Ruins of a \(BuildTool.place(kind).displayName.lowercased())"
    }
}
