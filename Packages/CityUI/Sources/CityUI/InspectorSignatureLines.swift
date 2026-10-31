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
                ? GameText.string("inspector.monument.complete")
                : GameText.string("inspector.monument.stage", building.projectStages, World.monumentStages)]
        case .guildHall:
            return [GameText.string("inspector.speedsUp", GameText.string("count.workshop", coverage.workshops))]
        case .gallery:
            guard building.commissionTicksLeft > 0 else { return [] }
            return [GameText.string("inspector.commissionEnds", clock(ticks: building.commissionTicksLeft))]
        case .steamEngine:
            return fuelLines(building) {
                GameText.string(
                    "inspector.steam",
                    GameText.string("count.workshop", coverage.workshops),
                    GameText.string("count.house", coverage.smokyHouses)
                )
            }
        case .powerPlant:
            return fuelLines(building) {
                GameText.string(
                    "inspector.power",
                    GameText.string("count.house", coverage.energisedHouses),
                    GameText.string("count.workshop", coverage.workshops)
                )
            }
        default:
            return cultureSignatureLines(for: building, coverage: coverage, in: snapshot)
        }
    }

    static func houseNotes(_ modifiers: HouseModifiers?) -> [String] {
        guard let modifiers else { return [] }
        return (modifiers.smoky ? [GameText.string("inspector.smoky")] : [])
            + (modifiers.energised ? [GameText.string("inspector.energised")] : [])
            + (modifiers.inspired ? [GameText.string("inspector.inspired")] : [])
    }

    static func commissionButton(for building: Building, balance: Int64) -> CommissionButton? {
        guard building.kind == .gallery, building.state == .operational else { return nil }
        return CommissionButton(
            title: GameText.string("inspector.commissionArt", World.commissionCost),
            isEnabled: building.commissionTicksLeft == 0 && balance >= World.commissionCost
        )
    }

    private static func fuelLines(_ building: Building, effects: () -> String) -> [String] {
        guard let fuel = building.kind.fuel else { return [] }
        guard building.fuelled else { return [GameText.string("inspector.outOfFuel", fuelName(fuel))] }
        return [GameText.string("inspector.fuelled"), effects()]
    }

    static func fuelName(_ fuel: FuelSpec) -> String {
        goodName(fuel.good)
    }

    /// Ticks as minutes and seconds of simulated time, rounded up.
    static func clock(ticks: UInt32) -> String {
        let seconds = (Int(ticks) + 9) / 10
        return "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }
}
