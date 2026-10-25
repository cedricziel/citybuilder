import Foundation

/// In-flight carrier entity. Spawned by producers to deliver goods to a
/// warehouse, by consumers to pull goods from a warehouse, and despawned
/// on arrival. Carriers traverse the road network at a configured speed
/// and persist as part of the World state so saves capture in-flight ones.
public struct Carrier: Hashable, Codable, Sendable {
    public enum Mission: Hashable, Codable, Sendable {
        case deliver(good: Good, amount: Int, fromProducer: EntityID, toWarehouse: EntityID)
        case retrieve(good: Good, amount: Int, fromWarehouse: EntityID, toConsumer: EntityID)
        /// Spec: `add-construction-stalls` / `warehouses-and-logistics`
        /// Producer→site delivery for materials a `.waitingForMaterials`
        /// building still needs. Arrival increments
        /// `materialsDelivered[good]` and may flip the substate to
        /// `.actively` when the recipe is satisfied.
        case deliverToConstructionSite(
            good: Good,
            amount: Int,
            fromProducer: EntityID,
            toBuilding: EntityID
        )
    }

    public let id: EntityID
    public var path: [TileCoordinate]
    public var pathIndex: Int
    public var mission: Mission

    public init(id: EntityID, path: [TileCoordinate], pathIndex: Int = 0, mission: Mission) {
        self.id = id
        self.path = path
        self.pathIndex = pathIndex
        self.mission = mission
    }

    public var currentTile: TileCoordinate? {
        guard pathIndex >= 0, pathIndex < path.count else { return nil }
        return path[pathIndex]
    }

    public var hasArrived: Bool {
        pathIndex >= path.count - 1
    }
}

public enum CarrierConfig {
    /// Max in-flight carriers per producer building.
    public static let perProducerCap = 2
}
