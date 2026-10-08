import CityCore
import CoreGraphics
import SwiftUI

/// Logic behind the placement HUD: four iso arrows, a checkmark and a
/// cancel button around the pending tile. Spec: `rendering-2_5d` /
/// Placement HUD.
@MainActor
public struct PlacementHUDViewModel {
    let session: GameSession
    public let anchor: TileCoordinate
    /// Whether the checkmark would place the building right now. An
    /// invalid placement can still be confirmed: the HUD then says why.
    public let isValid: Bool

    /// Stable order: NE, SE, SW, NW.
    public var arrows: [NudgeDirection] {
        NudgeDirection.allCases
    }

    /// False when the nudge would leave the map.
    public func isEnabled(_ direction: NudgeDirection) -> Bool {
        let offset = direction.tileOffset
        return session.world.contains(TileCoordinate(x: anchor.x + offset.dx, y: anchor.y + offset.dy))
    }

    public func nudge(_ direction: NudgeDirection) {
        session.nudgePendingPlacement(direction)
    }

    public func confirm() {
        session.confirmPendingPlacement()
    }

    public func cancel() {
        session.cancelPendingPlacement()
    }
}

public extension GameSession {
    /// The HUD's model; nil unless a placement is pending.
    var placementHUD: PlacementHUDViewModel? {
        guard let pending = pendingPlacement else { return nil }
        return PlacementHUDViewModel(
            session: self,
            anchor: pending.anchor,
            isValid: ghostState()?.valid ?? false
        )
    }
}

/// Where the HUD's buttons sit. CityUI keeps its own iso constants (see
/// `GameSession`), so the projection is repeated here, camera and all.
public enum PlacementHUDLayout {
    /// Apple's minimum touch target.
    public static let buttonSize: CGFloat = 44
    /// Distance from the tile center to the middle of an arrow button.
    public static let arrowRadius: CGFloat = 64

    private static let halfTileWidth: CGFloat = 32
    private static let halfTileHeight: CGFloat = 16

    /// Center of `tile` in the world view's coordinate space (y down),
    /// for a view of `viewSize` showing `camera`.
    public static func viewPoint(forTile tile: TileCoordinate, camera: Camera, viewSize: CGSize) -> CGPoint {
        let zoom = CGFloat(camera.zoom)
        let deltaCol = CGFloat(Double(tile.x) - camera.centerX)
        let deltaRow = CGFloat(Double(tile.y) - camera.centerY)
        return CGPoint(
            x: viewSize.width / 2 + (deltaCol - deltaRow) * halfTileWidth * zoom,
            y: viewSize.height / 2 + (deltaCol + deltaRow) * halfTileHeight * zoom
        )
    }

    /// Offset of an arrow button from the tile center: along the rendered
    /// diamond's diagonal for that direction, at a fixed distance so the
    /// buttons stay large enough at any zoom.
    public static func arrowOffset(for direction: NudgeDirection) -> CGSize {
        let step = direction.tileOffset
        let dx = CGFloat(step.dx - step.dy) * halfTileWidth
        let dy = CGFloat(step.dx + step.dy) * halfTileHeight
        let length = max((dx * dx + dy * dy).squareRoot(), 1)
        return CGSize(width: dx / length * arrowRadius, height: dy / length * arrowRadius)
    }
}
