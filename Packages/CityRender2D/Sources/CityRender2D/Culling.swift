import CityCore
import CoreGraphics
import Foundation

/// Visible-tile culling. Given a camera and a view size, returns the set of
/// tile coordinates that fall inside the view (plus a small margin). Per
/// spec rendering-2_5d "Off-screen tile not in scene".
public enum Culling {
    /// Margin in tiles outside the visible region that the renderer still
    /// keeps in the scene tree, to avoid pop-in at the edges during pan.
    public static let bufferTiles = 2

    /// Computes the inclusive range of tile coordinates visible in `view`
    /// given `camera` and the iso projection. Bounds-checks against the map
    /// dimensions, so the returned range is always in-bounds.
    public static func visibleTileRange(
        camera: Camera,
        viewSize: CGSize,
        mapWidth: Int,
        mapHeight: Int
    ) -> (xRange: ClosedRange<Int>, yRange: ClosedRange<Int>)? {
        guard mapWidth > 0, mapHeight > 0, camera.zoom > 0 else { return nil }

        // Half-extent of the view in iso-tile units, accounting for zoom.
        let halfWidthInTiles = (Double(viewSize.width) / 2) / (Double(IsoMath.tileWidth) * camera.zoom)
        let halfHeightInTiles = (Double(viewSize.height) / 2) / (Double(IsoMath.tileHeight) * camera.zoom)
        // Iso projection: a screen-space horizontal half-extent of `h` columns
        // corresponds to ± h in (col - row) space. The bounding rectangle in
        // tile coordinates is therefore the sum of both half-extents.
        let columnSpan = halfWidthInTiles + halfHeightInTiles
        let rowSpan = halfWidthInTiles + halfHeightInTiles

        let xMin = Int((camera.centerX - columnSpan).rounded(.down)) - bufferTiles
        let xMax = Int((camera.centerX + columnSpan).rounded(.up)) + bufferTiles
        let yMin = Int((camera.centerY - rowSpan).rounded(.down)) - bufferTiles
        let yMax = Int((camera.centerY + rowSpan).rounded(.up)) + bufferTiles

        let clampedX = max(0, xMin) ... min(mapWidth - 1, xMax)
        let clampedY = max(0, yMin) ... min(mapHeight - 1, yMax)

        guard clampedX.lowerBound <= clampedX.upperBound,
              clampedY.lowerBound <= clampedY.upperBound
        else { return nil }
        return (clampedX, clampedY)
    }

    /// True if a tile is visible (or in the buffer margin) given the camera
    /// and view size.
    public static func isVisible(
        _ coord: TileCoordinate,
        camera: Camera,
        viewSize: CGSize,
        mapWidth: Int,
        mapHeight: Int
    ) -> Bool {
        guard let (xRange, yRange) = visibleTileRange(
            camera: camera,
            viewSize: viewSize,
            mapWidth: mapWidth,
            mapHeight: mapHeight
        )
        else { return false }
        return xRange.contains(coord.x) && yRange.contains(coord.y)
    }
}
