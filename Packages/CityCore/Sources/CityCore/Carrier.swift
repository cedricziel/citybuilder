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

    /// How a carrier moves its load. Spec: `warehouses-and-logistics` /
    /// Handcarts carry long and bulk hauls.
    public enum Vehicle: String, Hashable, Codable, Sendable {
        case onFoot
        case handcart
    }

    public let id: EntityID
    public var path: [TileCoordinate]
    public var pathIndex: Int
    public var mission: Mission
    public var vehicle: Vehicle

    public init(id: EntityID, path: [TileCoordinate], pathIndex: Int = 0, mission: Mission, vehicle: Vehicle = .onFoot) {
        self.id = id
        self.path = path
        self.pathIndex = pathIndex
        self.mission = mission
        self.vehicle = vehicle
    }

    private enum CodingKeys: String, CodingKey {
        case id, path, pathIndex, mission, vehicle
    }

    /// Saves written before handcarts have no vehicle: those carriers walk.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(EntityID.self, forKey: .id)
        path = try container.decode([TileCoordinate].self, forKey: .path)
        pathIndex = try container.decode(Int.self, forKey: .pathIndex)
        mission = try container.decode(Mission.self, forKey: .mission)
        vehicle = try container.decodeIfPresent(Vehicle.self, forKey: .vehicle) ?? .onFoot
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
    /// Road tiles a haul must cover before it goes by handcart (game data).
    public static let cartDistance = LogisticsCatalog.cartDistance
    /// Units that must be ready for one destination before a handcart goes (game data).
    public static let cartMinLoad = LogisticsCatalog.cartMinLoad
    /// Units a handcart carries at most (game data).
    public static let cartCapacity = LogisticsCatalog.cartCapacity

    /// What one haul along `path` takes when `ready` units could go: a
    /// handcart with up to `cartCapacity` on a long haul with enough
    /// ready, else one unit on foot. With `waitForLoad`, a long haul with
    /// too little ready takes nothing yet (nil), so the goods wait for a
    /// cart load instead of trickling out on foot.
    static func haul(
        ready: Int, along path: [TileCoordinate], waitForLoad: Bool = false
    ) -> (amount: Int, vehicle: Carrier.Vehicle)? {
        guard path.count - 1 >= cartDistance else { return (1, .onFoot) }
        guard ready >= cartMinLoad else { return waitForLoad ? nil : (1, .onFoot) }
        return (min(ready, cartCapacity), .handcart)
    }
}

public extension Carrier.Mission {
    /// The units carried.
    var amount: Int {
        switch self {
        case let .deliver(_, amount, _, _), let .retrieve(_, amount, _, _),
             let .deliverToConstructionSite(_, amount, _, _): amount
        }
    }
}
