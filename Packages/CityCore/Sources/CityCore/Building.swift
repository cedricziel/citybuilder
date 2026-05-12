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
    /// Shore building, accepts deposits/withdrawals from both carriers
    /// (land side) and ships (sea side). Spec: `port-and-shipyard`.
    case port
    /// Shore producer that emits Ship entities. Spec: `port-and-shipyard`.
    case shipyard
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

/// Shore-placement opt-in. A building kind that allows its footprint
/// to straddle land and water tiles declares minima for each face.
/// Per `buildings-and-construction` / Shore-placement rule.
public struct ShorePlacement: Hashable, Sendable {
    public let minLandTiles: Int
    public let minWaterTiles: Int

    public init(minLandTiles: Int, minWaterTiles: Int) {
        self.minLandTiles = minLandTiles
        self.minWaterTiles = minWaterTiles
    }
}

/// Per-kind metadata. The catalog is a Swift constant table (design D9).
public struct BuildingSpec: Hashable, Sendable {
    public let kind: BuildingKind
    public let footprint: Footprint
    public let cost: Int64
    public let upkeep: Int64
    public let buildDurationTicks: UInt64
    /// Opt-in to shore-placement. Nil means the building rejects any
    /// water-tile coverage (the default for land-only buildings).
    public let shorePlacement: ShorePlacement?

    public init(
        kind: BuildingKind,
        footprint: Footprint,
        cost: Int64,
        upkeep: Int64 = 0,
        buildDurationTicks: UInt64 = 30,
        shorePlacement: ShorePlacement? = nil
    ) {
        self.kind = kind
        self.footprint = footprint
        self.cost = cost
        self.upkeep = upkeep
        self.buildDurationTicks = buildDurationTicks
        self.shorePlacement = shorePlacement
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
        ),
        .port: BuildingSpec(
            kind: .port, footprint: Footprint(width: 2, height: 3),
            cost: 250, upkeep: 1, buildDurationTicks: 35,
            shorePlacement: ShorePlacement(minLandTiles: 1, minWaterTiles: 1)
        ),
        .shipyard: BuildingSpec(
            kind: .shipyard, footprint: Footprint(width: 2, height: 3),
            cost: 350, upkeep: 2, buildDurationTicks: 45,
            shorePlacement: ShorePlacement(minLandTiles: 1, minWaterTiles: 1)
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
    /// Subset of the footprint tiles that sit on a buildable land
    /// terrain at placement time. Empty for non-shore-placement
    /// buildings (whose whole footprint is land).
    public let landFaceTiles: [TileCoordinate]
    /// Subset of the footprint tiles that sit on water at placement
    /// time. Empty for non-shore-placement buildings.
    public let seaFaceTiles: [TileCoordinate]
    /// Reserved water-side tile for ship docking. Non-nil only for
    /// `BuildingKind.port` (and any future shore building that needs
    /// it). Drawn from `seaFaceTiles` deterministically at place time.
    public let shipAnchor: TileCoordinate?

    public init(
        id: EntityID,
        kind: BuildingKind,
        anchor: TileCoordinate,
        state: BuildingState = .constructing,
        ticksSincePlacement: UInt64 = 0,
        landFaceTiles: [TileCoordinate] = [],
        seaFaceTiles: [TileCoordinate] = [],
        shipAnchor: TileCoordinate? = nil
    ) {
        self.id = id
        self.kind = kind
        self.anchor = anchor
        self.state = state
        self.ticksSincePlacement = ticksSincePlacement
        self.landFaceTiles = landFaceTiles
        self.seaFaceTiles = seaFaceTiles
        self.shipAnchor = shipAnchor
    }
}

public extension Building {
    /// Default Codable decoder that defaults the new face/anchor fields
    /// to empty/nil when missing, so v1 saves (pre-M2-archipelago)
    /// continue to load before the M7 migration framework lands.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(EntityID.self, forKey: .id)
        self.kind = try container.decode(BuildingKind.self, forKey: .kind)
        self.anchor = try container.decode(TileCoordinate.self, forKey: .anchor)
        self.state = try container.decode(BuildingState.self, forKey: .state)
        self.ticksSincePlacement = try container.decode(UInt64.self, forKey: .ticksSincePlacement)
        self.landFaceTiles = try container.decodeIfPresent(
            [TileCoordinate].self, forKey: .landFaceTiles
        ) ?? []
        self.seaFaceTiles = try container.decodeIfPresent(
            [TileCoordinate].self, forKey: .seaFaceTiles
        ) ?? []
        self.shipAnchor = try container.decodeIfPresent(
            TileCoordinate.self, forKey: .shipAnchor
        )
    }
}
