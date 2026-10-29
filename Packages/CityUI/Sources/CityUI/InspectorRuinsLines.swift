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
        let fee = World.clearingFee(of: building.ruinOf ?? building.kind)
        let money = HUDViewModel.formatMoney(fee, locale: .current)
        return DemolishButton(title: isRuins ? "Clear ruins — \(money)" : "Pull down — \(money)", isEnabled: balance >= fee)
    }

    /// "Burnt down in Summer 1202" for ruins, "Burning" for a building on
    /// fire, none otherwise.
    static func fireLines(for building: Building, in snapshot: WorldSnapshot) -> [String] {
        if building.state == .burning { return ["Burning"] }
        guard let tick = building.burntAtTick else { return [] }
        return ["Burnt down in \(date(atTick: tick, in: snapshot).displayText)"]
    }

    /// "Ruins of a house" for ruins, the palette name otherwise.
    static func title(of building: Building) -> String {
        guard let kind = building.ruinOf else { return BuildTool.place(building.kind).displayName }
        return "Ruins of a \(BuildTool.place(kind).displayName.lowercased())"
    }

    /// The date of an earlier tick, counted back in seasons from the
    /// snapshot's own date.
    static func date(atTick tick: UInt64, in snapshot: WorldSnapshot) -> GameDate {
        let back = Int(snapshot.tickCount / CalendarState.ticksPerSeason) - Int(tick / CalendarState.ticksPerSeason)
        let seasons = snapshot.date.year * 4 + snapshot.date.season.rawValue - back
        let year = Int((Double(seasons) / 4).rounded(.down))
        return GameDate(year: year, season: Season(rawValue: seasons - year * 4) ?? .spring)
    }
}
