import Foundation

/// Served luxuries of the culture signature buildings. Spec:
/// `culture-signatures`.
public extension BuildingKind {
    /// The four culture signature buildings, in culture order.
    static let cultureSignatures: [BuildingKind] = Culture.allCases.map(\.signature)

    var isCultureSignature: Bool {
        signatureCulture != nil
    }
}

extension BuildingKind {
    /// The culture whose signature this kind is, nil for other kinds.
    var signatureCulture: Culture? {
        Self.signatureCultures[self]
    }

    private static let signatureCultures = Dictionary(uniqueKeysWithValues: Culture.allCases.map { ($0.signature, $0) })

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
