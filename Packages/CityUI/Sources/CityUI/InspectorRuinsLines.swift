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

    /// What a fire watch covers and where its watchman is. Spec:
    /// `platform-shells` / Fire watch inspector.
    static func fireWatchLines(for building: Building, in snapshot: WorldSnapshot) -> [String] {
        guard building.kind == .fireWatch, building.state == .operational else { return [] }
        let covers = snapshot.fireWatchCover[building.id] ?? 0
        let walker = snapshot.watchmen.first { $0.watch == building.id }
        let hasRoad = !snapshot.roadDisconnectedBuildings.contains(building.id)
        return [
            "Covers \(covers) building\(covers == 1 ? "" : "s") within \(World.fireWatchReach) tiles by road",
            watchmanLine(walker, hasRoad: hasRoad)
        ]
    }

    /// The houses a physician keeps safe and when it burns herbs. Spec:
    /// `buildings-and-construction` / Physician and herb garden.
    static func physicianLines(for building: Building, in snapshot: WorldSnapshot) -> [String] {
        guard building.kind == .physician, building.state == .operational, let fuel = building.kind.fuel else { return [] }
        let houses = snapshot.buildings.values.count {
            $0.kind == .house && $0.owner == building.owner && World.footprintDistance($0, building) <= World.physicianReach
        }
        return [
            "Keeps \(houses) house\(houses == 1 ? "" : "s") within \(World.physicianReach) tiles safe from fever",
            "Burns \(fuel.amount) \(InspectorViewModel.goodName(fuel.good)) every \(fuel.intervalTicks) ticks, "
                + "only while a fever is warned or under way"
        ]
    }

    static func watchmanLine(_ walker: WatchmanWalker?, hasRoad: Bool) -> String {
        guard hasRoad else { return "Watchman: can't leave: no road" }
        guard let walker else { return "Watchman: at the watch" }
        return walker.isDousing ? "Watchman: dousing a fire" : "Watchman: walking to a fire"
    }

    /// "Ruins of a house" for ruins, the palette name otherwise.
    static func title(of building: Building) -> String {
        guard let kind = building.ruinOf else { return BuildTool.place(building.kind).displayName }
        return "Ruins of a \(BuildTool.place(kind).displayName.lowercased())"
    }
}
