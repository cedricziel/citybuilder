import Foundation

/// Catalog entries and served luxuries of the culture signature
/// buildings. Spec: `culture-signatures`.
extension BuildingCatalog {
    /// Design D2.
    static let cultureSignatureSpecs: [BuildingKind: BuildingSpec] = [
        .meadHall: BuildingSpec(
            kind: .meadHall, footprint: Footprint(width: 3, height: 3),
            cost: 180, upkeep: 1, buildDurationTicks: 35, materialCost: [.wood: 6, .planks: 2]
        ),
        .forum: BuildingSpec(
            kind: .forum, footprint: Footprint(width: 3, height: 3),
            cost: 220, upkeep: 2, buildDurationTicks: 40, materialCost: [.wood: 2, .planks: 6]
        ),
        .templeGarden: BuildingSpec(
            kind: .templeGarden, footprint: Footprint(width: 3, height: 3),
            cost: 160, upkeep: 1, buildDurationTicks: 35, materialCost: [.wood: 2, .planks: 4]
        ),
        .caravanserai: BuildingSpec(
            kind: .caravanserai, footprint: Footprint(width: 3, height: 3),
            cost: 200, upkeep: 2, buildDurationTicks: 40, materialCost: [.wood: 4, .planks: 4]
        )
    ]
}

public extension BuildingKind {
    /// The four culture signature buildings, in culture order.
    static let cultureSignatures: [BuildingKind] = Culture.allCases.map(\.signature)

    var isCultureSignature: Bool {
        signatureCulture != nil
    }
}

public extension Culture {
    /// The building only this culture has (design D2).
    var signature: BuildingKind {
        switch self {
        case .northernEuropean: .meadHall
        case .mediterranean: .forum
        case .eastAsian: .templeGarden
        case .middleEastern: .caravanserai
        }
    }
}

extension BuildingKind {
    /// The culture whose signature this kind is, nil for other kinds.
    var signatureCulture: Culture? {
        switch self {
        case .meadHall: .northernEuropean
        case .forum: .mediterranean
        case .templeGarden: .eastAsian
        case .caravanserai: .middleEastern
        default: nil
        }
    }

    /// 1 of the culture's luxury every 100 ticks (design D3).
    var servedLuxury: FuelSpec? {
        signatureCulture.map { FuelSpec(good: $0.luxury, amount: 1, intervalTicks: 100) }
    }
}

public extension Building {
    /// A culture signature whose last luxury burn succeeded: its effect
    /// doubles (design D3).
    var isServed: Bool {
        kind.isCultureSignature && fuelled
    }

    /// A culture signature's effect per resident or its upkeep share:
    /// 2 served, 1 unserved.
    var servedRate: Int64 {
        isServed ? 2 : 1
    }
}

public extension HousePopulation {
    /// Temple gardens only reach houses at citizens or above (design D6).
    var contemplates: Bool {
        tier >= .citizens
    }
}
