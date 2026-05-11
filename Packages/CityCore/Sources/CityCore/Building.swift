import Foundation

/// Building identifier used by spec scenarios. The catalog metadata (size,
/// cost, build duration, behavior) lives on `BuildingSpec` so this enum stays
/// stable across milestones — the catalog grows; the IDs do not move.
///
/// Raw values are hyphen-separated (sprite-asset-pipeline naming grammar).
/// The custom `Codable` conformance accepts the legacy underscore form
/// (`lumberjack_hut`, `town_center`) when decoding so saves written before
/// the rename continue to load.
public enum BuildingKind: String, CaseIterable, Sendable {
    case house
    case warehouse
    case road
    case lumberjackHut = "lumberjack-hut"
    case sawmill
    case townCenter = "town-center"
}

extension BuildingKind: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        let canonical = switch raw {
        case "lumberjack_hut": "lumberjack-hut"
        case "town_center": "town-center"
        default: raw
        }
        guard let kind = BuildingKind(rawValue: canonical) else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown BuildingKind raw value: \(raw)"
                )
            )
        }
        self = kind
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Footprint of a building in tiles. The anchor tile is at offset (0, 0);
/// the footprint occupies an `width × height` rectangle that extends in the
/// positive x and y directions from the anchor.
public struct Footprint: Hashable, Codable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = max(1, width)
        self.height = max(1, height)
    }

    public static let single = Footprint(width: 1, height: 1)

    public func tiles(anchor: TileCoordinate) -> [TileCoordinate] {
        var result: [TileCoordinate] = []
        result.reserveCapacity(width * height)
        for dy in 0 ..< height {
            for dx in 0 ..< width {
                result.append(TileCoordinate(x: anchor.x + dx, y: anchor.y + dy))
            }
        }
        return result
    }
}

/// Per-kind metadata. The catalog is a Swift constant table (design D9).
public struct BuildingSpec: Hashable, Sendable {
    public let kind: BuildingKind
    public let footprint: Footprint
    public let cost: Int64
    public let upkeep: Int64
    public let buildDurationTicks: UInt64

    public init(
        kind: BuildingKind,
        footprint: Footprint,
        cost: Int64,
        upkeep: Int64 = 0,
        buildDurationTicks: UInt64 = 30
    ) {
        self.kind = kind
        self.footprint = footprint
        self.cost = cost
        self.upkeep = upkeep
        self.buildDurationTicks = buildDurationTicks
    }
}

public enum BuildingCatalog {
    private static let specs: [BuildingKind: BuildingSpec] = [
        .house: BuildingSpec(
            kind: .house, footprint: Footprint(width: 2, height: 2),
            cost: 50, upkeep: 0, buildDurationTicks: 20
        ),
        .warehouse: BuildingSpec(
            kind: .warehouse, footprint: Footprint(width: 3, height: 3),
            cost: 200, upkeep: 1, buildDurationTicks: 40
        ),
        .road: BuildingSpec(
            kind: .road, footprint: .single,
            cost: 5, upkeep: 0, buildDurationTicks: 1
        ),
        .lumberjackHut: BuildingSpec(
            kind: .lumberjackHut, footprint: Footprint(width: 2, height: 2),
            cost: 80, upkeep: 0, buildDurationTicks: 25
        ),
        .sawmill: BuildingSpec(
            kind: .sawmill, footprint: Footprint(width: 2, height: 2),
            cost: 120, upkeep: 2, buildDurationTicks: 30
        ),
        .townCenter: BuildingSpec(
            kind: .townCenter, footprint: Footprint(width: 3, height: 3),
            cost: 0, upkeep: 0, buildDurationTicks: 1
        )
    ]

    public static var all: [BuildingSpec] {
        Array(specs.values)
    }

    public static func spec(for kind: BuildingKind) -> BuildingSpec {
        guard let result = specs[kind] else {
            preconditionFailure("BuildingKind \(kind) missing from catalog")
        }
        return result
    }
}

/// State of a placed building.
public enum BuildingState: String, Codable, Sendable {
    case planned
    case constructing
    case operational
}

/// Runtime instance of a placed building.
public struct Building: Hashable, Codable, Sendable {
    public let id: EntityID
    public let kind: BuildingKind
    public let anchor: TileCoordinate
    public var state: BuildingState
    public var ticksSincePlacement: UInt64

    public init(
        id: EntityID,
        kind: BuildingKind,
        anchor: TileCoordinate,
        state: BuildingState = .constructing,
        ticksSincePlacement: UInt64 = 0
    ) {
        self.id = id
        self.kind = kind
        self.anchor = anchor
        self.state = state
        self.ticksSincePlacement = ticksSincePlacement
    }
}
