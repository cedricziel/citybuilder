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
    /// buildings of the source's owner. Every building is the player's
    /// until `add-rival-towns` lands; then this compares `owner`.
    static func haveSameOwner(_: Building, _: Building) -> Bool {
        true
    }
}

extension World {
    /// One-monument rule, checked by `canPlace` after the tech check.
    /// Every building is the player's until `add-rival-towns` lands;
    /// then this filters by the placing owner.
    func uniquenessRejection(_ kind: BuildingKind) -> PlacementRejection? {
        guard kind.isUnique, buildings.values.contains(where: { $0.kind == kind }) else { return nil }
        return .alreadyBuilt(kind)
    }
}

extension Building {
    /// Inclusive tile bounds of the footprint.
    var bounds: TileBoundingBox {
        let footprint = BuildingCatalog.spec(for: kind).footprint
        return TileBoundingBox(
            minX: anchor.x, minY: anchor.y,
            maxX: anchor.x + footprint.width - 1, maxY: anchor.y + footprint.height - 1
        )
    }
}
