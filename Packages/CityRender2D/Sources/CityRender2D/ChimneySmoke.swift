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

    /// Inhabited houses, and workshops with a fire that have no issue,
    /// in no particular order.
    public static func sources(in snapshot: WorldSnapshot) -> [SmokeSource] {
        snapshot.buildings.values.compactMap { building -> SmokeSource? in
            guard building.state == .operational, let style = style(for: building.kind) else { return nil }
            let lit = building.kind == .house
                ? (snapshot.housePopulations[building.id]?.population ?? 0) > 0
                : snapshot.buildingIssues[building.id] == nil
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
        let ranked = sources.compactMap { source -> (source: SmokeSource, distance: Double)? in
            guard xRange.contains(source.anchor.x), yRange.contains(source.anchor.y) else { return nil }
            let dx = Double(source.anchor.x) - camera.centerX, dy = Double(source.anchor.y) - camera.centerY
            return (source, dx * dx + dy * dy)
        }
        return ranked.sorted {
            if $0.source.isWorkshop != $1.source.isWorkshop { return $0.source.isWorkshop }
            return $0.distance != $1.distance ? $0.distance < $1.distance : $0.source.id.raw < $1.source.id.raw
        }
        .prefix(budget(zoom: camera.zoom))
        .map(\.source)
    }
}

/// Where the chimney top sits on each building sprite, as fractions of
/// the sprite: x from the left, y from the top. Measured on the IsoKit
/// renders; a chimney often overlaps its roof in silhouette, so it
/// cannot be found from the alpha mask (design D2).
enum ChimneyAnchors {
    static let table: [String: (x: CGFloat, y: CGFloat)] = [
        "building-bakery": (0.716, 0.37),
        "building-brewery": (0.674, 0.311),
        "building-charcoal-burner": (0.486, 0.63),
        "building-smelter": (0.71, 0.384),
        "building-toolsmith": (0.5, 0.194),
        "building-house": (0.36, 0.165),
        "building-house-tier2": (0.656, 0.146),
        "building-house-tier3": (0.504, 0.148)
    ]
    /// Top centre of the roof, for sprites the table does not know.
    static let fallback: (x: CGFloat, y: CGFloat) = (0.5, 0.15)

    /// Chimney top relative to a building node anchored at (0.5, 0).
    static func offset(stem: String, spriteSize: CGSize) -> CGPoint {
        let anchor = table[stem] ?? fallback
        return CGPoint(x: (anchor.x - 0.5) * spriteSize.width, y: (1 - anchor.y) * spriteSize.height)
    }
}
