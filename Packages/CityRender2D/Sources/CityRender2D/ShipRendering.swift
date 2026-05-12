import CityCore
import CoreGraphics
import Foundation

// Pure-function helpers for ship + shore-building rendering. The
// SpriteKit-side wiring (ShipsLayer, sprite reconciliation) consumes
// these results; the math is testable headlessly.

// swiftlint:disable identifier_name

/// Compass directions for ship sprite facing — kept as 1- and
/// 2-character lowercase identifiers to match the sprite-asset-pipeline
/// naming grammar (`ship-<facing>-<frame>`). Identifier-name lint is
/// disabled for this declaration because the grammar is fixed.
public enum ShipFacing: String, CaseIterable, Sendable {
    case n, ne, e, se, s, sw, w, nw
}

/// Cardinal directions for shore-building orientation.
public enum ShoreOrientation: String, CaseIterable, Sendable {
    case n, s, e, w
}

// swiftlint:enable identifier_name

/// Z-position constants for the layered SKNode stack. The routes
/// overlay sits between terrain (0) and buildings (10+) per spec
/// `rendering-2_5d` / Route polyline overlay.
public enum RouteLayerZPosition {
    public static let terrain: CGFloat = 0
    public static let routes: CGFloat = 5
    public static let buildings: CGFloat = 10
    public static let ships: CGFloat = 15
}

public enum ShipRenderMath {
    /// Quantize a `Fixed` heading (radians, world convention: 0 = east,
    /// increasing toward south) to one of the 8 pre-rendered ship
    /// facings. Spec: `rendering-2_5d` / Ship facing selection.
    public static func facing(forHeading heading: Fixed) -> ShipFacing {
        // 8 facings span 2π → each covers π/4 = ~0.7854 rad.
        // Half-octant boundary is π/8 = ~0.3927 rad.
        // World convention: heading 0 = east, +π/2 = south, ±π = west,
        // -π/2 = north. The catalog orders facings going clockwise
        // from north: n, ne, e, se, s, sw, w, nw.
        let twoPi = Int64(Fixed.scale) * 25734 / 4096 // 2π in Fixed raw (~25734)
        // Normalize heading to [0, 2π).
        let rawMod = ((Int64(heading.raw) % twoPi) + twoPi) % twoPi
        // Rotate so that 0 = east aligns with the catalog's `e` slot.
        // Octant index 0..7 maps to: e(0), se(1), s(2), sw(3), w(4),
        // nw(5), n(6), ne(7).
        let octantSize = twoPi / 8
        let halfOctant = octantSize / 2
        let octantIdx = Int(((rawMod + halfOctant) / octantSize) % 8)
        let orderedFromEast: [ShipFacing] = [.e, .se, .s, .sw, .w, .nw, .n, .ne]
        return orderedFromEast[octantIdx]
    }

    /// Texture name for a ship facing + frame.
    public static func textureName(facing: ShipFacing, frame: Int) -> String {
        "ship-\(facing.rawValue)-\(frame)"
    }

    /// Iso-project a `Fixed2D` ship position to scene coordinates. The
    /// integer-tile path runs through `IsoMath.screenPoint(forTile:)`;
    /// for sub-tile positions we use the fractional projection.
    public static func screenPoint(for position: Fixed2D) -> CGPoint {
        let colX = Double(position.x.raw) / Double(Fixed.scale)
        let rowY = Double(position.y.raw) / Double(Fixed.scale)
        return IsoMath.screenPoint(forTileFractionalX: colX, fractionalY: rowY)
    }

    /// Interpolate between two ship positions for sub-tick render
    /// smoothness. `progress` is in `[0, 1]` and is typically the
    /// frame-time fraction since the last snapshot.
    public static func interpolated(
        from previous: Fixed2D, to current: Fixed2D, progress: Double
    ) -> CGPoint {
        let clamped = max(0, min(1, progress))
        let prevX = Double(previous.x.raw) / Double(Fixed.scale)
        let prevY = Double(previous.y.raw) / Double(Fixed.scale)
        let currX = Double(current.x.raw) / Double(Fixed.scale)
        let currY = Double(current.y.raw) / Double(Fixed.scale)
        let smoothed = FrameInterpolation.interpolatedTilePosition(
            from: (col: prevX, row: prevY),
            to: (col: currX, row: currY),
            at: clamped
        )
        return IsoMath.screenPoint(
            forTileFractionalX: smoothed.col, fractionalY: smoothed.row
        )
    }
}

public enum ShoreOrientationMath {
    /// Derive the cardinal orientation of a shore building from its
    /// recorded `landFaceTiles` and `seaFaceTiles`. The renderer uses
    /// this to pick the matching `building-<kind>-<orientation>-*`
    /// sprite variant. Spec: `rendering-2_5d` / Shore-building
    /// orientation derivation.
    ///
    /// Returns nil only when both face lists are empty (the building
    /// has no shore-placement metadata recorded).
    public static func orientation(
        landFaceTiles: [TileCoordinate], seaFaceTiles: [TileCoordinate]
    ) -> ShoreOrientation? {
        guard let landCentroid = centroid(of: landFaceTiles),
              let seaCentroid = centroid(of: seaFaceTiles)
        else { return nil }
        // Vector from land centroid toward sea centroid.
        let dx = seaCentroid.x - landCentroid.x
        let dy = seaCentroid.y - landCentroid.y
        // Tie-break by axis with larger absolute delta; on exact tie
        // prefer the y-axis (north/south) for deterministic output.
        if abs(dx) > abs(dy) {
            return dx > 0 ? .e : .w
        }
        return dy > 0 ? .s : .n
    }

    /// Sprite-name suffix for a shore building variant.
    public static func textureName(
        kind: BuildingKind, orientation: ShoreOrientation,
        state: BuildingState?, frame: Int?
    ) -> String {
        let stem = "building-\(kind.rawValue)-\(orientation.rawValue)"
        switch state {
        case .constructing:
            let safeFrame = frame ?? 0
            return "\(stem)-constructing-\(safeFrame)"
        case .operational:
            let safeFrame = frame ?? 0
            return "\(stem)-operational-\(safeFrame)"
        case .planned, .none:
            return stem
        }
    }

    private static func centroid(of tiles: [TileCoordinate]) -> (x: Double, y: Double)? {
        guard !tiles.isEmpty else { return nil }
        let sumX = tiles.reduce(0) { $0 + $1.x }
        let sumY = tiles.reduce(0) { $0 + $1.y }
        return (Double(sumX) / Double(tiles.count), Double(sumY) / Double(tiles.count))
    }
}

public enum ShipCulling {
    /// Default off-screen culling margin in scene units (a few tile
    /// widths so a ship sliding in from outside the viewport gets
    /// re-added before its sprite would be visible).
    public static let defaultMargin: CGFloat = IsoMath.tileWidth * 2

    /// True when the ship's projected screen position is inside the
    /// viewport rect inflated by `margin`.
    public static func isVisible(
        position: Fixed2D, camera: Camera, viewSize: CGSize,
        margin: CGFloat = defaultMargin
    ) -> Bool {
        let scenePoint = ShipRenderMath.screenPoint(for: position)
        let cameraScenePoint = IsoMath.screenPoint(
            forTileFractionalX: camera.centerX, fractionalY: camera.centerY
        )
        let dx = scenePoint.x - cameraScenePoint.x
        let dy = scenePoint.y - cameraScenePoint.y
        let halfW = viewSize.width / (2 * CGFloat(camera.zoom)) + margin
        let halfH = viewSize.height / (2 * CGFloat(camera.zoom)) + margin
        return abs(dx) <= halfW && abs(dy) <= halfH
    }
}

public enum RoutePolylineProjector {
    /// Projects a route's waypoint sequence to scene coordinates so
    /// the renderer can stroke an `SKShapeNode` polyline. `.sea`
    /// waypoints use their literal Fixed2D; `.port` waypoints resolve
    /// to the building's recorded `shipAnchor` tile (or anchor tile
    /// as a fallback) via the snapshot's `buildings` dict.
    public static func projectedPoints(
        for route: Route, snapshot: WorldSnapshot
    ) -> [CGPoint] {
        route.waypoints.map { waypoint in
            let position = position(for: waypoint, snapshot: snapshot)
            return ShipRenderMath.screenPoint(for: position)
        }
    }

    public static func position(
        for waypoint: Waypoint, snapshot: WorldSnapshot
    ) -> Fixed2D {
        switch waypoint {
        case let .sea(pos):
            return pos
        case let .port(id):
            guard let building = snapshot.buildings[id] else { return .zero }
            let anchor = building.shipAnchor ?? building.anchor
            return Fixed2D(x: Fixed(Int32(anchor.x)), y: Fixed(Int32(anchor.y)))
        }
    }
}
