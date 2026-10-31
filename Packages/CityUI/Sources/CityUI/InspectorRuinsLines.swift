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
        return DemolishButton(
            title: isRuins ? GameText.string("inspector.clearRuins", money) : GameText.string("inspector.pullDown", money),
            isEnabled: balance >= fee
        )
    }

    /// "Burnt down in Summer 1202" for ruins, "Burning" for a building on
    /// fire, none otherwise.
    static func fireLines(for building: Building, in snapshot: WorldSnapshot) -> [String] {
        if building.state == .burning { return [GameText.string("inspector.burning")] }
        guard let tick = building.burntAtTick else { return [] }
        return [GameText.string("inspector.burntDown", GameText.date(snapshot.calendar.date(atTick: tick)))]
    }

    /// What a fire watch covers and where its watchman is. Spec:
    /// `platform-shells` / Fire watch inspector.
    static func fireWatchLines(for building: Building, in snapshot: WorldSnapshot) -> [String] {
        guard building.kind == .fireWatch, building.state == .operational else { return [] }
        let covers = snapshot.fireWatchCover[building.id] ?? 0
        let walker = snapshot.watchmen.first { $0.watch == building.id }
        let hasRoad = !snapshot.roadDisconnectedBuildings.contains(building.id)
        return [
            GameText.string("inspector.fireWatch.covers", GameText.string("count.building", covers), World.fireWatchReach),
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
            GameText.string("inspector.physician.keeps", GameText.string("count.house", houses), World.physicianReach),
            GameText.string("inspector.physician.burns", fuel.amount, InspectorViewModel.goodName(fuel.good), fuel.intervalTicks)
        ]
    }

    static func watchmanLine(_ walker: WatchmanWalker?, hasRoad: Bool) -> String {
        guard hasRoad else { return GameText.string("inspector.watchman", GameText.string("inspector.watchman.noRoad")) }
        guard let walker else { return GameText.string("inspector.watchman", GameText.string("inspector.watchman.atWatch")) }
        let state = walker.isDousing ? GameText.string("inspector.watchman.dousing") : GameText.string("inspector.watchman.walking")
        return GameText.string("inspector.watchman", state)
    }

    /// "Ruins of a house" for ruins, the palette name otherwise.
    static func title(of building: Building) -> String {
        guard let kind = building.ruinOf else { return BuildTool.place(building.kind).displayName }
        return GameText.string("inspector.ruinsOf", GameText.inSentence(BuildTool.place(kind).displayName))
    }
}
