import CityCore
import CoreGraphics
import Foundation

/// Pure iso-projection math. No SpriteKit, no SwiftUI — fully unit-testable.
///
/// Convention: tile (col=0, row=0) projects to the screen origin (0, 0).
/// Increasing col moves the screen point right and down; increasing row
/// moves left and down. The "y-up" SpriteKit convention is handled by the
/// scene itself when consuming these points.
public enum IsoMath {
    public static let tileWidth: CGFloat = 64
    public static let tileHeight: CGFloat = 32

    public static func screenPoint(forTile coord: TileCoordinate) -> CGPoint {
        let col = CGFloat(coord.x)
        let row = CGFloat(coord.y)
        return CGPoint(
            x: (col - row) * (tileWidth / 2),
            y: -(col + row) * (tileHeight / 2)
        )
    }

    public static func screenPoint(forTileFractionalX colX: Double, fractionalY rowY: Double) -> CGPoint {
        CGPoint(
            x: CGFloat(colX - rowY) * (tileWidth / 2),
            y: -CGFloat(colX + rowY) * (tileHeight / 2)
        )
    }

    /// Inverse projection: convert a screen point back to a fractional tile
    /// coordinate. Useful for hit-testing taps against tiles.
    public static func tileCoordinate(forScreenPoint point: CGPoint) -> (col: Double, row: Double) {
        let halfWidth = Double(tileWidth) / 2
        let halfHeight = Double(tileHeight) / 2
        let pointX = Double(point.x)
        let pointY = Double(-point.y)
        let col = (pointX / halfWidth + pointY / halfHeight) / 2
        let row = (pointY / halfHeight - pointX / halfWidth) / 2
        return (col, row)
    }

    /// Snap fractional tile coordinates to the nearest integer tile.
    public static func nearestTile(toScreenPoint point: CGPoint) -> TileCoordinate {
        let (col, row) = tileCoordinate(forScreenPoint: point)
        return TileCoordinate(x: Int(col.rounded()), y: Int(row.rounded()))
    }
}
