import CityCore
import Foundation

/// The caravanserai's export picker. Spec: `platform-shells` / Culture
/// signature inspector.
public struct ExportPicker: Equatable, Sendable {
    /// "None" (nil) and every good except the caravanserai's luxury, in
    /// catalog order.
    public let options: [Good?]
    public let selected: Good?

    /// "None" or the good's display name.
    public static func title(of option: Good?) -> String {
        option.map(\.displayName) ?? GameText.string("common.none")
    }
}

/// Inspector lines for culture signatures (add-culture-signatures D9).
extension InspectorViewModel {
    static func cultureSignatureLines(
        for building: Building,
        coverage: SignatureCoverage,
        in snapshot: WorldSnapshot
    ) -> [String] {
        guard let luxury = building.kind.fuel?.good else { return [] }
        let luxuryName = goodName(luxury)
        let rate = building.servedRate
        switch building.kind {
        case .meadHall:
            let count = GameText.string("count.building", coverage.relievedBuildings)
            return [building.isServed
                ? GameText.string("inspector.meadHall.served", luxuryName, count)
                : GameText.string("inspector.meadHall", count)]
        case .forum:
            let houses = GameText.string("count.house", coverage.taxedHouses)
            return [building.isServed
                ? GameText.string("inspector.forum.served", luxuryName, rate, houses)
                : GameText.string("inspector.forum", rate, houses)]
        case .templeGarden:
            let residents = World.signatureTargets(of: building, among: snapshot.buildings.values)
                .compactMap { snapshot.housePopulations[$0.target.id] }
                .filter(\.contemplates)
                .reduce(0) { $0 + Int($1.population) }
            let from = GameText.string("count.resident", residents)
            return [building.isServed
                ? GameText.string("inspector.temple.served", luxuryName, rate, from)
                : GameText.string("inspector.temple", rate, from)]
        case .caravanserai:
            return caravanLines(for: building, luxuryName: luxuryName, tick: snapshot.tickCount)
        default:
            return []
        }
    }

    private static func caravanLines(for building: Building, luxuryName: String, tick: UInt64) -> [String] {
        let interval = World.caravanIntervalTicks
        var lines = [GameText.string("inspector.nextCaravan", clock(ticks: UInt32(interval - tick % interval)))]
        if let sale = building.lastCaravan {
            let goods = Good.allCases.compactMap { good in sale.goods[good].map { "\($0) \(goodName(good))" } }
            lines.append(GameText.string("inspector.lastCaravan", goods.joined(separator: GameText.string("list.and")), sale.revenue))
        }
        lines.append(building.isServed
            ? GameText.string("inspector.serving", luxuryName)
            : GameText.string("inspector.noLuxury", luxuryName))
        return lines
    }

    static func exportPicker(for building: Building) -> ExportPicker? {
        guard building.kind == .caravanserai, building.state == .operational else { return nil }
        let luxury = building.kind.fuel?.good
        return ExportPicker(options: [nil] + Good.allCases.filter { $0 != luxury }, selected: building.exportGood)
    }

    static func goodName(_ good: Good) -> String {
        GameText.inSentence(good.displayName)
    }
}
