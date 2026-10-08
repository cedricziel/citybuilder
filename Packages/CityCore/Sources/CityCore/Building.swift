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
    /// Food producer with no inputs. Spec: `goods-and-production`.
    case farm
    /// Bakes bread from food. Spec: `goods-and-production`.
    case bakery
    case grainFarm = "grain-farm"
    case windmill
    /// Antiquity hand mill, replaced by the windmill. Spec:
    /// `historical-ages` / Obsolete buildings.
    case quernHouse = "quern-house"
    /// Must stand on mountain ground. Spec: `buildings-and-construction`
    /// / Terrain requirement for placement.
    case mine
    case charcoalBurner = "charcoal-burner"
    case smelter
    case toolsmith
    /// Produces knowledge. Spec: `research`.
    case library
    case townCenter = "town-center"
    /// Shore building, accepts deposits/withdrawals from both carriers
    /// (land side) and ships (sea side). Spec: `port-and-shipyard`.
    case port
    /// Shore producer that emits Ship entities. Spec: `port-and-shipyard`.
    case shipyard
    /// Culture-only luxury chains. Spec: `culture-content`.
    case hopGarden = "hop-garden"
    case brewery
    case vineyard
    case winery
    case teaGarden = "tea-garden"
    case teaHouse = "tea-house"
    case coffeeGrove = "coffee-grove"
    case roastery
    /// Age signature buildings. Spec: `age-signatures`.
    case monument
    case guildHall = "guild-hall"
    case gallery
    case steamEngine = "steam-engine"
    case powerPlant = "power-plant"
    /// Culture signature buildings. Spec: `culture-signatures`.
    case meadHall = "mead-hall"
    case forum
    case templeGarden = "temple-garden"
    case caravanserai
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

public struct TerrainRequirement: Hashable, Sendable {
    public let terrain: TerrainType
    public let minTiles: Int

    public init(terrain: TerrainType, minTiles: Int) {
        self.terrain = terrain
        self.minTiles = minTiles
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
    /// Goods consumed at placement. Default empty = free of materials
    /// (money cost still applies). Roads and town center stay empty.
    public let materialCost: [Good: Int]
    /// Terrain the footprint must partly cover, and how many tiles of it.
    public let requiredTerrain: TerrainRequirement?

    public init(
        kind: BuildingKind,
        footprint: Footprint,
        cost: Int64,
        upkeep: Int64 = 0,
        buildDurationTicks: UInt64 = 30,
        shorePlacement: ShorePlacement? = nil,
        materialCost: [Good: Int] = [:],
        requiredTerrain: TerrainRequirement? = nil
    ) {
        self.kind = kind
        self.footprint = footprint
        self.cost = cost
        self.upkeep = upkeep
        self.buildDurationTicks = buildDurationTicks
        self.shorePlacement = shorePlacement
        self.materialCost = materialCost
        self.requiredTerrain = requiredTerrain
    }
}

public enum BuildingCatalog {
    private static let specs: [BuildingKind: BuildingSpec] = [
        .house: BuildingSpec(
            kind: .house, footprint: Footprint(width: 2, height: 2),
            cost: 50, upkeep: 0, buildDurationTicks: 20,
            materialCost: [.planks: 4]
        ),
        .warehouse: BuildingSpec(
            kind: .warehouse, footprint: Footprint(width: 3, height: 3),
            cost: 200, upkeep: 1, buildDurationTicks: 40,
            materialCost: [.wood: 2, .planks: 6]
        ),
        .road: BuildingSpec(
            kind: .road, footprint: .single,
            cost: 5, upkeep: 0, buildDurationTicks: 1
        ),
        .lumberjackHut: BuildingSpec(
            kind: .lumberjackHut, footprint: Footprint(width: 2, height: 2),
            cost: 80, upkeep: 0, buildDurationTicks: 25,
            materialCost: [.wood: 2]
        ),
        .sawmill: BuildingSpec(
            kind: .sawmill, footprint: Footprint(width: 2, height: 2),
            cost: 120, upkeep: 2, buildDurationTicks: 30,
            materialCost: [.wood: 4, .planks: 1]
        ),
        .farm: BuildingSpec(
            kind: .farm, footprint: Footprint(width: 2, height: 2),
            cost: 60, upkeep: 0, buildDurationTicks: 25,
            materialCost: [.wood: 2]
        ),
        .bakery: BuildingSpec(
            kind: .bakery, footprint: Footprint(width: 2, height: 2),
            cost: 90, upkeep: 1, buildDurationTicks: 30,
            materialCost: [.wood: 2, .planks: 2]
        ),
        .grainFarm: BuildingSpec(
            kind: .grainFarm, footprint: Footprint(width: 2, height: 2),
            cost: 60, upkeep: 0, buildDurationTicks: 25, materialCost: [.wood: 2]
        ),
        .quernHouse: BuildingSpec(
            kind: .quernHouse, footprint: Footprint(width: 2, height: 2),
            cost: 60, upkeep: 1, buildDurationTicks: 25, materialCost: [.wood: 2, .planks: 2]
        ),
        .windmill: BuildingSpec(
            kind: .windmill, footprint: Footprint(width: 2, height: 2),
            cost: 110, upkeep: 1, buildDurationTicks: 35, materialCost: [.wood: 3, .planks: 3]
        ),
        .mine: BuildingSpec(
            kind: .mine, footprint: Footprint(width: 2, height: 2),
            cost: 120, upkeep: 2, buildDurationTicks: 40, materialCost: [.wood: 4, .planks: 2],
            requiredTerrain: TerrainRequirement(terrain: .mountain, minTiles: 2)
        ),
        .charcoalBurner: BuildingSpec(
            kind: .charcoalBurner, footprint: Footprint(width: 2, height: 2),
            cost: 70, upkeep: 1, buildDurationTicks: 25, materialCost: [.wood: 3]
        ),
        .smelter: BuildingSpec(
            kind: .smelter, footprint: Footprint(width: 2, height: 2),
            cost: 150, upkeep: 2, buildDurationTicks: 40, materialCost: [.wood: 4, .planks: 4]
        ),
        .toolsmith: BuildingSpec(
            kind: .toolsmith, footprint: Footprint(width: 2, height: 2),
            cost: 140, upkeep: 2, buildDurationTicks: 35, materialCost: [.wood: 2, .planks: 4]
        ),
        .library: BuildingSpec(
            kind: .library, footprint: Footprint(width: 2, height: 2),
            cost: 100, upkeep: 2, buildDurationTicks: 35, materialCost: [.wood: 2, .planks: 4]
        ),
        .townCenter: BuildingSpec(
            kind: .townCenter, footprint: Footprint(width: 3, height: 3),
            cost: 0, upkeep: 0, buildDurationTicks: 1
        ),
        .port: BuildingSpec(
            kind: .port, footprint: Footprint(width: 2, height: 3),
            cost: 250, upkeep: 1, buildDurationTicks: 35,
            shorePlacement: ShorePlacement(minLandTiles: 1, minWaterTiles: 1),
            materialCost: [.wood: 8, .planks: 6]
        ),
        .shipyard: BuildingSpec(
            kind: .shipyard, footprint: Footprint(width: 2, height: 3),
            cost: 350, upkeep: 2, buildDurationTicks: 45,
            shorePlacement: ShorePlacement(minLandTiles: 1, minWaterTiles: 1),
            materialCost: [.wood: 12, .planks: 8]
        )
    ]
    .merging(cultureSpecs) { _, _ in preconditionFailure("Culture kind with a hand-written spec") }
    .merging(signatureSpecs) { _, _ in preconditionFailure("Signature kind with a hand-written spec") }
    .merging(cultureSignatureSpecs) { _, _ in preconditionFailure("Culture signature with a hand-written spec") }

    /// Gardens and producers of the culture luxury chains (design D3).
    private static var cultureSpecs: [BuildingKind: BuildingSpec] {
        var result: [BuildingKind: BuildingSpec] = [:]
        for culture in Culture.allCases {
            let chain = culture.luxuryChain
            result[chain.garden] = BuildingSpec(
                kind: chain.garden, footprint: Footprint(width: 2, height: 2),
                cost: 60, upkeep: 0, buildDurationTicks: 25, materialCost: [.wood: 2]
            )
            result[chain.producer] = BuildingSpec(
                kind: chain.producer, footprint: Footprint(width: 2, height: 2),
                cost: 120, upkeep: 1, buildDurationTicks: 30, materialCost: [.wood: 3, .planks: 3]
            )
        }
        return result
    }

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

/// Substate of `.constructing`: distinguishes "waiting for materials
/// to arrive" from "actively accruing construction time". A waiting
/// building does NOT advance `ticksSincePlacement`; only an actively-
/// constructing one does. Spec: `add-construction-stalls` /
/// `buildings-and-construction` Requirement: Construction substate.
public enum ConstructionState: String, Codable, Sendable {
    case actively
    case waitingForMaterials = "waiting_for_materials"
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
    /// Substate of `.constructing`. Meaningless once the building is
    /// `.operational`; the value persists for forensics. Default
    /// `.actively` matches the pre-`add-construction-stalls` behavior.
    public var constructionState: ConstructionState
    /// Per-good materials already delivered to the construction site.
    /// While `state == .constructing` and `constructionState ==
    /// .waitingForMaterials`, the building tracks accumulation here;
    /// once the map satisfies `materialCost` it flips to `.actively`.
    public var materialsDelivered: [Good: Int]
    /// Completed monument project stages. Spec: `age-signatures` / The
    /// monument is a project.
    public var projectStages: UInt8
    /// True while the last fuel burn succeeded. Spec: `age-signatures`
    /// / Fuelled buildings burn fuel on an interval.
    public var fuelled: Bool
    /// Ticks left of a running gallery commission, 0 when none runs.
    public var commissionTicksLeft: UInt32
    /// The good a caravanserai's caravans sell first. Spec:
    /// `culture-signatures` / The caravanserai exports a chosen good.
    public var exportGood: Good?
    /// What the caravanserai's last caravan sold, nil before its first.
    public var lastCaravan: CaravanSale?

    public init(
        id: EntityID,
        kind: BuildingKind,
        anchor: TileCoordinate,
        state: BuildingState = .constructing,
        ticksSincePlacement: UInt64 = 0,
        landFaceTiles: [TileCoordinate] = [],
        seaFaceTiles: [TileCoordinate] = [],
        shipAnchor: TileCoordinate? = nil,
        constructionState: ConstructionState = .actively,
        materialsDelivered: [Good: Int] = [:],
        projectStages: UInt8 = 0,
        fuelled: Bool = false,
        commissionTicksLeft: UInt32 = 0,
        exportGood: Good? = nil,
        lastCaravan: CaravanSale? = nil
    ) {
        self.id = id
        self.kind = kind
        self.anchor = anchor
        self.state = state
        self.ticksSincePlacement = ticksSincePlacement
        self.landFaceTiles = landFaceTiles
        self.seaFaceTiles = seaFaceTiles
        self.shipAnchor = shipAnchor
        self.constructionState = constructionState
        self.materialsDelivered = materialsDelivered
        self.projectStages = projectStages
        self.fuelled = fuelled
        self.commissionTicksLeft = commissionTicksLeft
        self.exportGood = exportGood
        self.lastCaravan = lastCaravan
    }
}

public extension Building {
    /// Default Codable decoder that defaults the new face/anchor fields
    /// to empty/nil when missing, so v1 saves (pre-M2-archipelago)
    /// continue to load before the M7 migration framework lands. v2
    /// saves missing the construction-stalls fields default to the
    /// post-migration values (`.actively`, empty delivered); saves
    /// without the age-signature fields load as stage 0, unfuelled and
    /// without a commission, and buildings without an export good or a
    /// last caravan have none.
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
        self.constructionState = try container.decodeIfPresent(
            ConstructionState.self, forKey: .constructionState
        ) ?? .actively
        self.materialsDelivered = try container.decodeIfPresent(
            [Good: Int].self, forKey: .materialsDelivered
        ) ?? [:]
        self.projectStages = try container.decodeIfPresent(UInt8.self, forKey: .projectStages) ?? 0
        self.fuelled = try container.decodeIfPresent(Bool.self, forKey: .fuelled) ?? false
        self.commissionTicksLeft = try container.decodeIfPresent(UInt32.self, forKey: .commissionTicksLeft) ?? 0
        self.exportGood = try container.decodeIfPresent(Good.self, forKey: .exportGood)
        self.lastCaravan = try container.decodeIfPresent(CaravanSale.self, forKey: .lastCaravan)
    }
}

public extension BuildingKind {
    /// The tech that makes this building obsolete, if any.
    var obsoletedBy: Tech? {
        self == .quernHouse ? .milling : nil
    }

    /// The culture that may build this kind, nil for buildings every
    /// culture shares. Spec: `culture-content` / Culture-only buildings.
    var culture: Culture? {
        switch self {
        case .hopGarden, .brewery: .northernEuropean
        case .vineyard, .winery: .mediterranean
        case .teaGarden, .teaHouse: .eastAsian
        case .coffeeGrove, .roastery: .middleEastern
        case .meadHall, .forum, .templeGarden, .caravanserai: signatureCulture
        default: nil
        }
    }

    /// False for buildings tied to another culture.
    func isBuildable(in culture: Culture) -> Bool {
        self.culture.map { $0 == culture } ?? true
    }
}
