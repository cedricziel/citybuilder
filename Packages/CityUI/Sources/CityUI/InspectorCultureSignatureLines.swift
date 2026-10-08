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
        option.map { GoodsCatalog.spec(for: $0).displayName } ?? "None"
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
        let served = building.isServed ? "Serving \(goodName(luxury)): " : ""
        let rate = building.servedRate
        switch building.kind {
        case .meadHall:
            let count = count(coverage.relievedBuildings, "building")
            return [building.isServed ? "\(served)no upkeep for \(count)" : "Halves upkeep of \(count)"]
        case .forum:
            return ["\(served)+\(rate) tax per resident in \(count(coverage.taxedHouses, "house"))"]
        case .templeGarden:
            let residents = World.signatureTargets(of: building, among: snapshot.buildings.values)
                .compactMap { snapshot.housePopulations[$0.target.id] }
                .filter(\.contemplates)
                .reduce(0) { $0 + Int($1.population) }
            return ["\(served)+\(rate) knowledge per resident from \(count(residents, "resident"))"]
        case .caravanserai:
            return caravanLines(for: building, luxury: luxury, tick: snapshot.tickCount)
        default:
            return []
        }
    }

    private static func caravanLines(for building: Building, luxury: Good, tick: UInt64) -> [String] {
        let interval = World.caravanIntervalTicks
        var lines = ["Next caravan in \(clock(ticks: UInt32(interval - tick % interval)))"]
        if let sale = building.lastCaravan {
            let goods = Good.allCases.compactMap { good in sale.goods[good].map { "\($0) \(goodName(good))" } }
            lines.append("Last caravan: \(goods.joined(separator: " and ")) for $\(sale.revenue)")
        }
        let luxuryName = goodName(luxury)
        lines.append(building.isServed ? "Serving \(luxuryName)" : "No \(luxuryName)")
        return lines
    }

    static func exportPicker(for building: Building) -> ExportPicker? {
        guard building.kind == .caravanserai, building.state == .operational else { return nil }
        let luxury = building.kind.fuel?.good
        return ExportPicker(options: [nil] + Good.allCases.filter { $0 != luxury }, selected: building.exportGood)
    }

    static func goodName(_ good: Good) -> String {
        GoodsCatalog.spec(for: good).displayName.lowercased()
    }
}
