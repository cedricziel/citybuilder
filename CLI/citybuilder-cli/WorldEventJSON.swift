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
        case let .productionStalled(producer):
            return ["case": "productionStalled", "producer": producer.raw]
        case let .productionResumed(producer):
            return ["case": "productionResumed", "producer": producer.raw]
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
        }
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
