import CityCore
import CoreGraphics
import Foundation

public enum SmokeStyle: Hashable, Sendable {
    case smoke
    /// Dark and dense: the smelter and the charcoal burner.
    case heavySmoke
    case steam
}

/// A building whose chimney shows smoke or steam this tick.
public struct SmokeSource: Hashable, Sendable {
    public let id: EntityID
    public let anchor: TileCoordinate
    public let kind: BuildingKind
    public let style: SmokeStyle

    /// Workshops come before houses when the budget is tight.
    var isWorkshop: Bool {
        kind != .house
    }
}

/// Which buildings smoke, read from the snapshot alone. Spec:
/// `rendering-2_5d` / Chimneys smoke, Ambient effects stay in budget.
public enum ChimneyPlanner {
    static func style(for kind: BuildingKind) -> SmokeStyle? {
        switch kind {
        case .house, .bakery, .toolsmith: .smoke
        case .smelter, .charcoalBurner: .heavySmoke
        case .brewery: .steam
        default: nil
        }
    }

    /// Inhabited houses, and player workshops with a fire that have no
    /// issue, in no particular order. Rival workshops stay cold: building
    /// issues are worked out for the player's buildings only.
    public static func sources(in snapshot: WorldSnapshot) -> [SmokeSource] {
        snapshot.buildings.values.compactMap { building -> SmokeSource? in
            guard building.state == .operational, let style = style(for: building.kind) else { return nil }
            let lit = building.kind == .house
                ? (snapshot.housePopulations[building.id]?.population ?? 0) > 0
                : building.owner == .player && snapshot.buildingIssues[building.id] == nil
            guard lit else { return nil }
            return SmokeSource(id: building.id, anchor: building.anchor, kind: building.kind, style: style)
        }
    }

    /// Most smoke emitters on screen at any zoom.
    static let maxEmitters = 40

    /// Most smoke emitters on screen at `zoom`.
    public static func budget(zoom: Double) -> Int {
        min(maxEmitters, max(8, Int(24 * zoom)))
    }

    /// The visible sources that fit the budget: workshops first, then
    /// the nearest to the camera centre.
    public static func select(
        _ sources: [SmokeSource],
        xRange: ClosedRange<Int>,
        yRange: ClosedRange<Int>,
        camera: Camera
    ) -> [SmokeSource] {
        typealias Ranked = (source: SmokeSource, distance: Double)
        func before(_ lhs: Ranked, _ rhs: Ranked) -> Bool {
            if lhs.source.isWorkshop != rhs.source.isWorkshop { return lhs.source.isWorkshop }
            return lhs.distance != rhs.distance ? lhs.distance < rhs.distance : lhs.source.id.raw < rhs.source.id.raw
        }
        // Keep the best `limit` in order as they come: the budget is at
        // most 40, so this beats sorting every visible source.
        let limit = budget(zoom: camera.zoom)
        var best: [Ranked] = []
        best.reserveCapacity(limit + 1)
        for source in sources where xRange.contains(source.anchor.x) && yRange.contains(source.anchor.y) {
            let dx = Double(source.anchor.x) - camera.centerX, dy = Double(source.anchor.y) - camera.centerY
            let ranked = (source: source, distance: dx * dx + dy * dy)
            if best.count == limit, let last = best.last, !before(ranked, last) { continue }
            best.insert(ranked, at: best.firstIndex { before(ranked, $0) } ?? best.endIndex)
            if best.count > limit { best.removeLast() }
        }
        return best.map(\.source)
    }
}

/// Where the chimney top sits on each building sprite, as fractions of
/// the sprite: x from the left, y from the top. Measured on the IsoKit
/// renders; a chimney often overlaps its roof in silhouette, so it
/// cannot be found from the alpha mask (design D2).
enum ChimneyAnchors {
    /// Rows from `isokit chimneys` (each recipe's chimney top), plus the charcoal burner's mound and the
    /// smelter's stack, which IsoKit builds without a chimney part and are measured by hand.
    static let table: [String: (x: CGFloat, y: CGFloat)] = [
        "building-house": (0.556, 0.276),
        "building-house-tier2": (0.538, 0.217),
        "building-house-tier3": (0.637, 0.293),
        "building-bakery": (0.719, 0.376),
        "building-toolsmith": (0.500, 0.202),
        "building-brewery": (0.675, 0.314),
        "building-house-east-asian": (0.538, 0.367),
        "building-house-tier2-east-asian": (0.531, 0.349),
        "building-house-tier3-east-asian": (0.519, 0.329),
        "building-house-mediterranean": (0.550, 0.359),
        "building-house-tier2-mediterranean": (0.562, 0.369),
        "building-house-tier3-mediterranean": (0.550, 0.414),
        "building-house-middle-eastern": (0.525, 0.420),
        "building-house-tier2-middle-eastern": (0.525, 0.444),
        "building-house-tier3-middle-eastern": (0.525, 0.431),
        "building-house-antiquity": (0.525, 0.254),
        "building-house-tier2-antiquity": (0.569, 0.338),
        "building-house-tier3-antiquity": (0.519, 0.465),
        "building-house-antiquity-east-asian": (0.525, 0.245),
        "building-house-tier2-antiquity-east-asian": (0.569, 0.338),
        "building-house-tier3-antiquity-east-asian": (0.519, 0.456),
        "building-house-antiquity-mediterranean": (0.525, 0.278),
        "building-house-tier2-antiquity-mediterranean": (0.537, 0.381),
        "building-house-tier3-antiquity-mediterranean": (0.519, 0.399),
        "building-house-antiquity-middle-eastern": (0.525, 0.338),
        "building-house-tier2-antiquity-middle-eastern": (0.537, 0.483),
        "building-house-tier3-antiquity-middle-eastern": (0.519, 0.500),
        "building-house-renaissance": (0.512, 0.200),
        "building-house-tier2-renaissance": (0.494, 0.178),
        "building-house-tier3-renaissance": (0.469, 0.174),
        "building-house-renaissance-east-asian": (0.544, 0.302),
        "building-house-tier2-renaissance-east-asian": (0.569, 0.295),
        "building-house-tier3-renaissance-east-asian": (0.519, 0.389),
        "building-house-renaissance-mediterranean": (0.537, 0.306),
        "building-house-tier2-renaissance-mediterranean": (0.537, 0.295),
        "building-house-tier3-renaissance-mediterranean": (0.519, 0.370),
        "building-house-renaissance-middle-eastern": (0.537, 0.308),
        "building-house-tier2-renaissance-middle-eastern": (0.537, 0.295),
        "building-house-tier3-renaissance-middle-eastern": (0.519, 0.307),
        "building-house-industrial": (0.544, 0.294),
        "building-house-tier2-industrial": (0.569, 0.260),
        "building-house-tier3-industrial": (0.531, 0.256),
        "building-house-industrial-east-asian": (0.537, 0.332),
        "building-house-tier2-industrial-east-asian": (0.537, 0.312),
        "building-house-tier3-industrial-east-asian": (0.519, 0.293),
        "building-house-industrial-mediterranean": (0.537, 0.306),
        "building-house-tier2-industrial-mediterranean": (0.537, 0.295),
        "building-house-tier3-industrial-mediterranean": (0.519, 0.281),
        "building-house-industrial-middle-eastern": (0.537, 0.308),
        "building-house-tier2-industrial-middle-eastern": (0.537, 0.295),
        "building-house-tier3-industrial-middle-eastern": (0.519, 0.280),
        "building-house-modern": (0.537, 0.437),
        "building-house-tier2-modern": (0.537, 0.258),
        "building-house-tier3-modern": (0.519, 0.217),
        "building-house-modern-east-asian": (0.537, 0.330),
        "building-house-tier2-modern-east-asian": (0.537, 0.297),
        "building-house-tier3-modern-east-asian": (0.519, 0.219),
        "building-house-modern-mediterranean": (0.537, 0.437),
        "building-house-tier2-modern-mediterranean": (0.537, 0.380),
        "building-house-tier3-modern-mediterranean": (0.519, 0.217),
        "building-house-modern-middle-eastern": (0.537, 0.437),
        "building-house-tier2-modern-middle-eastern": (0.537, 0.380),
        "building-house-tier3-modern-middle-eastern": (0.519, 0.217),
        "building-charcoal-burner": (0.486, 0.63),
        "building-smelter": (0.71, 0.384)
    ]
    /// Top centre of the roof, for sprites neither the table nor a base
    /// stem knows.
    static let fallback: (x: CGFloat, y: CGFloat) = (0.5, 0.15)
    /// Culture and age suffixes of the house and workshop variants.
    static let variantSuffixes = [
        "-east-asian", "-mediterranean", "-middle-eastern", "-antiquity", "-renaissance", "-industrial", "-modern"
    ]

    /// The table row for `stem`, or for its base stem without culture and
    /// age suffixes (`building-house-tier2-modern-east-asian` →
    /// `building-house-tier2`).
    static func row(for stem: String) -> (x: CGFloat, y: CGFloat)? {
        var base = stem
        while table[base] == nil, let suffix = variantSuffixes.first(where: base.hasSuffix) {
            base.removeLast(suffix.count)
        }
        return table[base]
    }

    /// Chimney top relative to a building node anchored at (0.5, 0).
    static func offset(stem: String, spriteSize: CGSize) -> CGPoint {
        let anchor = row(for: stem) ?? fallback
        return CGPoint(x: (anchor.x - 0.5) * spriteSize.width, y: (1 - anchor.y) * spriteSize.height)
    }
}
