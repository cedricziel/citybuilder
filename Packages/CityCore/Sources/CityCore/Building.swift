import Foundation

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

/// Per-kind metadata. `BuildingCatalog` is generated from the game-data packs.
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

/// State of a placed building.
public enum BuildingState: String, Codable, Sendable {
    case planned
    case constructing
    case operational
    /// On fire: stopped until it is put out or burns down. Spec:
    /// `seasonal-events` / Fire starts, spreads and burns down.
    case burning
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
    /// The player or a rival. Spec: `buildings-and-construction` /
    /// Buildings have an owner.
    public internal(set) var owner: Owner
    /// For ruins, the kind that burnt down; nil for every other building.
    public let ruinOf: BuildingKind?
    /// For ruins, the tick the building burnt down.
    public let burntAtTick: UInt64?

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
        lastCaravan: CaravanSale? = nil,
        owner: Owner = .player,
        ruinOf: BuildingKind? = nil,
        burntAtTick: UInt64? = nil
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
        self.owner = owner
        self.ruinOf = ruinOf
        self.burntAtTick = burntAtTick
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
        self.owner = try container.decodeIfPresent(Owner.self, forKey: .owner) ?? .player
        self.ruinOf = try container.decodeIfPresent(BuildingKind.self, forKey: .ruinOf)
        self.burntAtTick = try container.decodeIfPresent(UInt64.self, forKey: .burntAtTick)
    }
}

public extension BuildingKind {
    /// False for buildings tied to another culture.
    func isBuildable(in culture: Culture) -> Bool {
        self.culture.map { $0 == culture } ?? true
    }
}

public extension Building {
    /// The tiles it covers: ruins keep the footprint of the kind that burnt.
    var footprint: Footprint {
        BuildingCatalog.spec(for: ruinOf ?? kind).footprint
    }
}

extension Building {
    /// The materials delivered so far cover its kind's material cost.
    var hasAllMaterials: Bool {
        BuildingCatalog.spec(for: kind).materialCost.allSatisfy { (materialsDelivered[$0.key] ?? 0) >= $0.value }
    }
}
