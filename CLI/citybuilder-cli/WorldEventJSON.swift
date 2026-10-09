import CityCore
import Foundation

/// Presentation-only serializer that turns `[WorldEvent]` into a stable JSON
/// array shape for the `--events-out FILE` CLI flag. Lives in the CLI target
/// (not `CityCore`) so the simulation core does not have to declare a public
/// wire format for events — events stay transient inside `CityCore` per
/// `world-events` spec and design D3.
enum WorldEventJSON {
    /// Encode `events` as a JSON array. Each entry is an object with a `case`
    /// field naming the `WorldEvent` case plus payload fields appropriate to
    /// that case. Output uses pretty printing and sorted keys so two runs
    /// over the same input sequence produce byte-identical files.
    static func encode(_ events: [WorldEvent]) throws -> Data {
        let payload = events.map(dictionary(for:))
        return try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    // swiftlint:disable:next cyclomatic_complexity
    private static func dictionary(for event: WorldEvent) -> [String: Any] {
        switch event {
        case let .buildingPlaced(building, kind, anchor):
            return base("buildingPlaced", entity: building, kind: kind, anchor: anchor)
        case let .buildingDemolished(building, kind, anchor):
            return base("buildingDemolished", entity: building, kind: kind, anchor: anchor)
        case let .constructionCompleted(building, kind, anchor):
            return base("constructionCompleted", entity: building, kind: kind, anchor: anchor)
        case let .forestHarvested(at):
            return ["case": "forestHarvested", "x": at.x, "y": at.y]
        case let .placementRejected(kind, anchor):
            return ["case": "placementRejected", "kind": kind.rawValue, "x": anchor.x, "y": anchor.y]
        case let .carrierDeparted(carrier, from, good):
            return ["case": "carrierDeparted", "carrier": carrier.raw, "x": from.x, "y": from.y, "good": good.rawValue]
        case let .carrierArrived(carrier, at, good, amount):
            return ["case": "carrierArrived", "carrier": carrier.raw, "x": at.x, "y": at.y, "good": good.rawValue, "amount": amount]
        case let .productionCycleCompleted(producer, kind):
            return ["case": "productionCycleCompleted", "producer": producer.raw, "kind": kind.rawValue]
        case let .productionStalled(producer, kind):
            return ["case": "productionStalled", "producer": producer.raw, "kind": kind.rawValue]
        case let .productionResumed(producer, kind):
            return ["case": "productionResumed", "producer": producer.raw, "kind": kind.rawValue]
        case let .taxesCollected(amount):
            return ["case": "taxesCollected", "amount": amount]
        case let .upkeepPaid(amount):
            return ["case": "upkeepPaid", "amount": amount]
        case let .bankruptcyWarning(deficitTicks):
            return ["case": "bankruptcyWarning", "deficitTicks": deficitTicks]
        case .bankruptcyResolved:
            return ["case": "bankruptcyResolved"]
        case .gameOver:
            return ["case": "gameOver"]
        default:
            return laterDictionary(for: event)
        }
    }

    /// Events added after the original wire format: construction materials,
    /// the calendar and ages, culture signatures and rival trade.
    private static func laterDictionary(for event: WorldEvent) -> [String: Any] { // swiftlint:disable:this cyclomatic_complexity
        switch event {
        case let .materialsDeducted(building, cost):
            return ["case": "materialsDeducted", "entity": building.raw, "goods": goods(cost)]
        case let .constructionWaitingForMaterials(building, missing):
            return ["case": "constructionWaitingForMaterials", "entity": building.raw, "goods": goods(missing)]
        case let .constructionStarted(building):
            return ["case": "constructionStarted", "entity": building.raw]
        case let .seasonChanged(season):
            return ["case": "seasonChanged", "season": String(describing: season)]
        case let .historyEvent(history):
            return ["case": "historyEvent", "event": String(describing: history)]
        case let .ageAdvanced(age):
            return ["case": "ageAdvanced", "age": age.rawValue]
        case .scenarioWon:
            return ["case": "scenarioWon"]
        case let .fuelRanOut(building, kind):
            return ["case": "fuelRanOut", "entity": building.raw, "kind": kind.rawValue]
        case let .monumentCompleted(building):
            return ["case": "monumentCompleted", "entity": building.raw]
        case let .commissionStarted(building):
            return ["case": "commissionStarted", "entity": building.raw]
        case let .commissionEnded(building):
            return ["case": "commissionEnded", "entity": building.raw]
        case let .caravanSold(building, sold, revenue):
            return ["case": "caravanSold", "entity": building.raw, "goods": goods(sold), "revenue": revenue]
        case let .rivalAgeAdvanced(rival, age):
            return ["case": "rivalAgeAdvanced", "rival": rival, "age": age.rawValue]
        case let .tradeCompleted(rival, good, quantity, total, direction):
            return [
                "case": "tradeCompleted", "rival": rival, "good": good.rawValue, "quantity": quantity,
                "total": total, "direction": String(describing: direction)
            ]
        default:
            return ["case": String(describing: event)]
        }
    }

    private static func goods(_ amounts: [Good: Int]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: amounts.map { ($0.key.rawValue, $0.value) })
    }

    private static func base(
        _ caseName: String,
        entity: EntityID,
        kind: BuildingKind,
        anchor: TileCoordinate
    ) -> [String: Any] {
        ["case": caseName, "entity": entity.raw, "kind": kind.rawValue, "x": anchor.x, "y": anchor.y]
    }
}
