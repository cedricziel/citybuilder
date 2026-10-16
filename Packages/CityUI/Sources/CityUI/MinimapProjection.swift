import CityCore
import CoreGraphics
import Foundation

/// Maps tiles to minimap points and back, in the map's own iso
/// orientation: tile (x, y) sits at `u = x − y` across and `v = x + y`
/// down, and each tile covers a diamond of ±1 in `u` and `v`. The map's
/// bounding box is `u ∈ [−H, W]`, `v ∈ [−1, W + H − 1]`, always twice as
/// wide as tall on screen. Spec: `platform-shells` / Minimap. Design D1.
public struct MinimapProjection: Equatable, Sendable {
    public let mapWidth: Int
    public let mapHeight: Int
    /// The minimap's size in points.
    public let size: CGSize

    public init(mapWidth: Int, mapHeight: Int, size: CGSize) {
        self.mapWidth = mapWidth
        self.mapHeight = mapHeight
        self.size = size
    }

    private var span: Double {
        Double(max(mapWidth + mapHeight, 1))
    }

    /// Points per unit of `u` and of `v`.
    private var scale: (across: Double, down: Double) {
        (Double(size.width) / span, Double(size.height) / span)
    }

    /// The minimap point of a fractional tile position.
    public func point(tileX: Double, tileY: Double) -> CGPoint {
        point(across: tileX - tileY, down: tileX + tileY)
    }

    func point(across: Double, down: Double) -> CGPoint {
        CGPoint(x: (across + Double(mapHeight)) * scale.across, y: (down + 1) * scale.down)
    }

    /// The fractional tile under a minimap point, unclamped.
    public func tile(at point: CGPoint) -> (x: Double, y: Double) {
        let across = Double(point.x) / scale.across - Double(mapHeight)
        let down = Double(point.y) / scale.down - 1
        return Self.tileOffset(across: across, down: down)
    }

    /// The tile offset of a move by `across` units of `u` and `down` of `v`.
    static func tileOffset(across: Double, down: Double) -> (x: Double, y: Double) {
        ((across + down) / 2, (down - across) / 2)
    }

    /// A fractional tile moved onto a map `mapWidth` by `mapHeight` tiles.
    static func clamp(x: Double, y: Double, mapWidth: Int, mapHeight: Int) -> (x: Double, y: Double) {
        (min(max(x, 0), Double(max(mapWidth - 1, 0))), min(max(y, 0), Double(max(mapHeight - 1, 0))))
    }

    /// The tile under a minimap point, moved onto the map when the point is
    /// off it.
    public func clampedTile(at point: CGPoint) -> (x: Double, y: Double) {
        let (x, y) = tile(at: point)
        return Self.clamp(x: x, y: y, mapWidth: mapWidth, mapHeight: mapHeight)
    }

    /// The camera's visible area in `u` and `v`, for a world view of
    /// `viewSize` points.
    public static func cameraSpan(camera: Camera, viewSize: CGSize) -> (across: ClosedRange<Double>, down: ClosedRange<Double>) {
        let zoom = max(camera.zoom, 0.0001)
        let halfU = Double(viewSize.width) / 2 / (Double(PlacementHUDLayout.halfTileWidth) * zoom)
        let halfV = Double(viewSize.height) / 2 / (Double(PlacementHUDLayout.halfTileHeight) * zoom)
        let centerU = camera.centerX - camera.centerY
        let centerV = camera.centerX + camera.centerY
        return (centerU - halfU ... centerU + halfU, centerV - halfV ... centerV + halfV)
    }

    /// The camera's visible area as a minimap rectangle.
    public func cameraRect(camera: Camera, viewSize: CGSize) -> CGRect {
        let span = Self.cameraSpan(camera: camera, viewSize: viewSize)
        let topLeft = point(across: span.across.lowerBound, down: span.down.lowerBound)
        let bottomRight = point(across: span.across.upperBound, down: span.down.upperBound)
        return CGRect(x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
    }
}
