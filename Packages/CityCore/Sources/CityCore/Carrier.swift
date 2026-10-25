import Foundation

/// In-flight carrier entity. Spawned by producers to deliver goods to a
/// warehouse, by consumers to pull goods from a warehouse, and despawned
/// on arrival. Carriers traverse the road network at a configured speed
/// and persist as part of the World state so saves capture in-flight ones.
public struct Carrier: Hashable, Codable, Sendable {
    public enum Mission: Hashable, Codable, Sendable {
        case deliver(good: Good, amount: Int, fromProducer: EntityID, toWarehouse: EntityID)
        case retrieve(good: Good, amount: Int, fromWarehouse: EntityID, toConsumer: EntityID)
        /// Producer→consumer hop for a consumer short of the good, so a
        /// chain skips storage. Spec: `warehouses-and-logistics` /
        /// Producers deliver to short consumers.
        case deliverToConsumer(good: Good, amount: Int, fromProducer: EntityID, toConsumer: EntityID)
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
    /// The vehicle on a long or bulk haul, nil on foot. Which one depends on
    /// the owner's age (#236). Spec: `warehouses-and-logistics` / Handcarts
    /// carry long and bulk hauls.
    public var vehicle: Vehicle?

    public init(id: EntityID, path: [TileCoordinate], pathIndex: Int = 0, mission: Mission, vehicle: Vehicle? = nil) {
        self.id = id
        self.path = path
        self.pathIndex = pathIndex
        self.mission = mission
        self.vehicle = vehicle
    }

    private enum CodingKeys: String, CodingKey {
        case id, path, pathIndex, mission, vehicle
    }

    /// Saves written before vehicles have none: those carriers walk.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(EntityID.self, forKey: .id)
        path = try container.decode([TileCoordinate].self, forKey: .path)
        pathIndex = try container.decode(Int.self, forKey: .pathIndex)
        mission = try container.decode(Mission.self, forKey: .mission)
        vehicle = try container.decodeIfPresent(Vehicle.self, forKey: .vehicle)
    }

    public var currentTile: TileCoordinate? {
        guard pathIndex >= 0, pathIndex < path.count else { return nil }
        return path[pathIndex]
    }

    public var hasArrived: Bool {
        pathIndex >= path.count - 1
    }
}

public extension Carrier.Mission {
    /// The good carried.
    var good: Good {
        switch self {
        case let .deliver(good, _, _, _), let .retrieve(good, _, _, _),
             let .deliverToConsumer(good, _, _, _), let .deliverToConstructionSite(good, _, _, _): good
        }
    }

    /// The units carried.
    var amount: Int {
        switch self {
        case let .deliver(_, amount, _, _), let .retrieve(_, amount, _, _),
             let .deliverToConsumer(_, amount, _, _), let .deliverToConstructionSite(_, amount, _, _): amount
        }
    }

    /// Where the goods came from.
    var source: EntityID {
        switch self {
        case let .deliver(_, _, from, _), let .retrieve(_, _, from, _),
             let .deliverToConsumer(_, _, from, _), let .deliverToConstructionSite(_, _, from, _): from
        }
    }

    /// Where the goods are bound.
    var destination: EntityID {
        switch self {
        case let .deliver(_, _, _, to), let .retrieve(_, _, _, to),
             let .deliverToConsumer(_, _, _, to), let .deliverToConstructionSite(_, _, _, to): to
        }
    }

    /// The same trip with `amount` units.
    func carrying(_ amount: Int) -> Carrier.Mission {
        switch self {
        case let .deliver(good, _, from, to): .deliver(good: good, amount: amount, fromProducer: from, toWarehouse: to)
        case let .retrieve(good, _, from, to): .retrieve(good: good, amount: amount, fromWarehouse: from, toConsumer: to)
        case let .deliverToConsumer(good, _, from, to):
            .deliverToConsumer(good: good, amount: amount, fromProducer: from, toConsumer: to)
        case let .deliverToConstructionSite(good, _, from, to):
            .deliverToConstructionSite(good: good, amount: amount, fromProducer: from, toBuilding: to)
        }
    }

    /// The same trip carrying `amount` units to `target`'s stockpile. A
    /// producer's goods continue as a delivery to storage, so the
    /// producer's carrier slot frees on arrival; a retrieval stays one.
    func redirected(to target: EntityID, amount: Int) -> Carrier.Mission {
        switch self {
        case .deliver, .deliverToConsumer, .deliverToConstructionSite:
            .deliver(good: good, amount: amount, fromProducer: source, toWarehouse: target)
        case .retrieve:
            .retrieve(good: good, amount: amount, fromWarehouse: source, toConsumer: target)
        }
    }
}

public enum CarrierConfig {
    /// Max in-flight carriers per producer building.
    public static let perProducerCap = 2
    /// Road tiles a haul must cover before it takes a vehicle (game data).
    public static let haulDistance = LogisticsCatalog.haulDistance
    /// Units that must be ready for one destination before a vehicle goes (game data).
    public static let haulMinLoad = LogisticsCatalog.haulMinLoad
    /// Ticks a producer's output waits for a vehicle load before it goes anyway (game data).
    public static let haulMaxWait = LogisticsCatalog.haulMaxWait

    /// The vehicle carriers use in `age`: the latest one whose age has
    /// begun, nil while carriers still walk everything (#236).
    static func vehicle(in age: Age) -> Vehicle? {
        Vehicle.allCases.filter { $0.age <= age }.max { $0.age < $1.age }
    }

    /// What one haul along `path` takes when `ready` units could go and
    /// `vehicle` is the owner's: the vehicle with up to its capacity on a
    /// long haul with enough ready, else one unit on foot.
    static func haul(ready: Int, along path: [TileCoordinate], vehicle: Vehicle?) -> (amount: Int, vehicle: Vehicle?) {
        guard let vehicle, isLong(path), ready >= haulMinLoad else { return (1, nil) }
        return (min(ready, vehicle.capacity), vehicle)
    }

    /// True for a haul long enough to take a vehicle.
    static func isLong(_ path: [TileCoordinate]) -> Bool {
        path.count - 1 >= haulDistance
    }
}
