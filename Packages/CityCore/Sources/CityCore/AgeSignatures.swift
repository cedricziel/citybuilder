import Foundation

/// Catalog entries, ranges and placement rules of the age signature
/// buildings. Spec: `age-signatures`.
extension BuildingCatalog {
    /// Design D2.
    static let signatureSpecs: [BuildingKind: BuildingSpec] = [
        .monument: BuildingSpec(
            kind: .monument, footprint: Footprint(width: 3, height: 3),
            cost: 300, upkeep: 0, buildDurationTicks: 60, materialCost: [.wood: 6, .planks: 6]
        ),
        .guildHall: BuildingSpec(
            kind: .guildHall, footprint: Footprint(width: 3, height: 3),
            cost: 250, upkeep: 3, buildDurationTicks: 40, materialCost: [.wood: 4, .planks: 6]
        ),
        .gallery: BuildingSpec(
            kind: .gallery, footprint: Footprint(width: 2, height: 2),
            cost: 180, upkeep: 2, buildDurationTicks: 35, materialCost: [.wood: 2, .planks: 4]
        ),
        .steamEngine: BuildingSpec(
            kind: .steamEngine, footprint: Footprint(width: 2, height: 2),
            cost: 220, upkeep: 3, buildDurationTicks: 40, materialCost: [.wood: 2, .planks: 4, .iron: 2]
        ),
        .powerPlant: BuildingSpec(
            kind: .powerPlant, footprint: Footprint(width: 3, height: 3),
            cost: 400, upkeep: 6, buildDurationTicks: 60, materialCost: [.planks: 6, .iron: 4]
        )
    ]
}

/// Fuel a building burns on a fixed interval. Supply carriers keep twice
/// `amount` on hand; the building only works while its last burn
/// succeeded. Spec: `age-signatures` / Fuelled buildings burn fuel on an
/// interval. Reused by `add-culture-signatures` for served luxuries.
public struct FuelSpec: Hashable, Sendable {
    public let good: Good
    public let amount: Int
    public let intervalTicks: UInt64

    public init(good: Good, amount: Int, intervalTicks: UInt64) {
        self.good = good
        self.amount = amount
        self.intervalTicks = intervalTicks
    }
}

/// What a signature source does to the buildings it reaches.
public enum SignatureEffect: Hashable, Sendable {
    /// Workshops gain 1 extra tick of progress on ticks whose count is a
    /// multiple of `everyTicks`.
    case workshopSpeed(everyTicks: UInt64)
    /// Houses lose 2 capacity.
    case smoke
    /// Houses gain 2 capacity.
    case energy
    /// Houses grow and advance a tier twice as fast.
    case inspiration
}

/// When a signature source's effects are on.
public enum SignatureActivation: Hashable, Sendable {
    case always
    /// While its last fuel burn succeeded.
    case fuelled
    /// While a gallery commission runs.
    case commissioned
}

/// One effect of a signature source and how far it reaches, in tiles
/// between footprints (see `World.footprintDistance`).
public struct SignatureReach: Hashable, Sendable {
    public let effect: SignatureEffect
    public let tiles: Int

    public init(_ effect: SignatureEffect, tiles: Int) {
        self.effect = effect
        self.tiles = tiles
    }
}

public extension BuildingKind {
    /// The five age signature buildings, in age order.
    static let signatures: [BuildingKind] = [.monument, .guildHall, .gallery, .steamEngine, .powerPlant]

    /// A building whose recipe turns inputs into outputs. Only workshops
    /// gain signature speed bonuses. Spec: `age-signatures` / Workshops.
    var isWorkshop: Bool {
        Self.workshops.contains(self)
    }

    private static let workshops: Set<BuildingKind> = Set(allCases.filter { kind in
        ProductionCatalog.recipe(for: kind).map { !$0.inputs.isEmpty && !$0.outputs.isEmpty } ?? false
    })

    /// Design D5.
    var fuel: FuelSpec? {
        switch self {
        case .steamEngine: FuelSpec(good: .charcoal, amount: 1, intervalTicks: 50)
        case .powerPlant: FuelSpec(good: .charcoal, amount: 2, intervalTicks: 50)
        default: nil
        }
    }

    /// Effects of an active source of this kind (design D3, D4, D7, D8).
    var signatureReaches: [SignatureReach] {
        switch self {
        case .guildHall: [SignatureReach(.workshopSpeed(everyTicks: 4), tiles: 8)]
        case .gallery: [SignatureReach(.inspiration, tiles: 8)]
        case .steamEngine: [SignatureReach(.workshopSpeed(everyTicks: 1), tiles: 6), SignatureReach(.smoke, tiles: 4)]
        case .powerPlant: [SignatureReach(.workshopSpeed(everyTicks: 2), tiles: 10), SignatureReach(.energy, tiles: 10)]
        default: []
        }
    }

    var signatureActivation: SignatureActivation {
        if fuel != nil { return .fuelled }
        return self == .gallery ? .commissioned : .always
    }

    /// At most one of these per owner. Spec: `buildings-and-construction`
    /// / One monument per city.
    var isUnique: Bool {
        self == .monument
    }
}

public extension World {
    /// Chebyshev gap between two footprints: touching footprints are 1
    /// apart, overlapping ones 0. Spec: `age-signatures` / Ranges are
    /// measured between footprints.
    static func footprintDistance(_ lhs: Building, _ rhs: Building) -> Int {
        let left = lhs.bounds
        let right = rhs.bounds
        return max(
            0,
            right.minX - left.maxX, left.minX - right.maxX,
            right.minY - left.maxY, left.minY - right.maxY
        )
    }

    /// Owner seam for signature effects (design D3): effects reach only
    /// buildings of the source's owner.
    static func haveSameOwner(_ lhs: Building, _ rhs: Building) -> Bool {
        lhs.owner == rhs.owner
    }
}

extension World {
    /// One-monument rule per owner, checked by `canPlace` after the tech
    /// check.
    func uniquenessRejection(_ kind: BuildingKind, for owner: Owner) -> PlacementRejection? {
        guard kind.isUnique, buildings.values.contains(where: { $0.kind == kind && $0.owner == owner })
        else { return nil }
        return .alreadyBuilt(kind)
    }
}

public extension Building {
    /// True when this building is a signature source whose effects are on,
    /// leaving its construction state aside.
    var isSignatureActive: Bool {
        guard !kind.signatureReaches.isEmpty else { return false }
        switch kind.signatureActivation {
        case .always: return true
        case .fuelled: return fuelled
        case .commissioned: return commissionTicksLeft > 0
        }
    }
}

public extension TileBoundingBox {
    /// This box grown by `tiles` on every side.
    func expanded(by tiles: Int) -> TileBoundingBox {
        TileBoundingBox(minX: minX - tiles, minY: minY - tiles, maxX: maxX + tiles, maxY: maxY + tiles)
    }
}

public extension Building {
    /// Inclusive tile bounds of the footprint.
    var bounds: TileBoundingBox {
        let footprint = BuildingCatalog.spec(for: kind).footprint
        return TileBoundingBox(
            minX: anchor.x, minY: anchor.y,
            maxX: anchor.x + footprint.width - 1, maxY: anchor.y + footprint.height - 1
        )
    }
}
