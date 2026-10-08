import CityCore
import Foundation

/// The gallery's "Commission art" button. Spec: `platform-shells` /
/// Signature inspector.
public struct CommissionButton: Equatable, Sendable {
    public let title: String
    public let isEnabled: Bool
}

/// Inspector lines for age signatures and the houses they touch.
extension InspectorViewModel {
    static func signatureLines(for building: Building, in snapshot: WorldSnapshot) -> [String] {
        guard building.state == .operational else { return [] }
        let coverage = World.signatureCoverage(of: building, among: snapshot.buildings.values)
        switch building.kind {
        case .monument:
            return [building.isCompletedMonument
                ? "Complete: taxes +10%"
                : "Stage \(building.projectStages) of \(World.monumentStages)"]
        case .guildHall:
            return ["Speeds up \(count(coverage.workshops, "workshop"))"]
        case .gallery:
            guard building.commissionTicksLeft > 0 else { return [] }
            return ["Commission ends in \(clock(ticks: building.commissionTicksLeft))"]
        case .steamEngine:
            return fuelLines(building) {
                "Speeds up \(count(coverage.workshops, "workshop")) · smokes \(count(coverage.smokyHouses, "house"))"
            }
        case .powerPlant:
            return fuelLines(building) { "Energises \(count(coverage.energisedHouses, "house")), \(count(coverage.workshops, "workshop"))" }
        default:
            return []
        }
    }

    static func houseNotes(_ modifiers: HouseModifiers?) -> [String] {
        guard let modifiers else { return [] }
        return (modifiers.smoky ? ["Smoky: −2 residents"] : [])
            + (modifiers.energised ? ["Energised: +2 residents"] : [])
            + (modifiers.inspired ? ["Inspired by patronage"] : [])
    }

    static func commissionButton(for building: Building, balance: Int64) -> CommissionButton? {
        guard building.kind == .gallery, building.state == .operational else { return nil }
        return CommissionButton(
            title: "Commission art ($\(World.commissionCost))",
            isEnabled: building.commissionTicksLeft == 0 && balance >= World.commissionCost
        )
    }

    private static func fuelLines(_ building: Building, effects: () -> String) -> [String] {
        guard let fuel = building.kind.fuel else { return [] }
        guard building.fuelled else { return ["Out of \(fuelName(fuel))"] }
        return ["Fuelled", effects()]
    }

    static func fuelName(_ fuel: FuelSpec) -> String {
        GoodsCatalog.spec(for: fuel.good).displayName.lowercased()
    }

    private static func count(_ value: Int, _ noun: String) -> String {
        "\(value) \(noun)\(value == 1 ? "" : "s")"
    }

    /// Ticks as minutes and seconds of simulated time, rounded up.
    static func clock(ticks: UInt32) -> String {
        let seconds = (Int(ticks) + 9) / 10
        return "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }
}
