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
    /// Why the checkmark would not place the building right now, shown
    /// under it; nil when it would.
    public let reason: String?

    /// Whether the checkmark would place the building right now. An
    /// invalid placement can still be confirmed: the HUD then says why.
    public var isValid: Bool {
        reason == nil
    }

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
            reason: placementRefusal(pending.kind, at: pending.anchor)?.message(in: world)
        )
    }
}

/// Where the HUD's buttons sit. CityUI keeps its own iso constants (see
/// `GameSession`), so the projection is repeated here, camera and all.
public enum PlacementHUDLayout {
    /// Apple's minimum touch target.
    public static let buttonSize: CGFloat = 44
    /// Distance from the tile center to the middle of an arrow button.
    public static let arrowRadius: CGFloat = 84
    /// Horizontal half-distance between confirm and cancel, and their drop
    /// below the lowest arrow.
    public static let actionGap: CGFloat = 32
    /// Drop from the confirm row's center to the reason capsule's center.
    public static let reasonDrop: CGFloat = 44
    /// The reason capsule wraps to a second line past this width.
    public static let reasonMaxWidth: CGFloat = 220

    static let halfTileWidth: CGFloat = 32
    static let halfTileHeight: CGFloat = 16

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

    /// Smallest gap between a HUD control and the safe area's edge.
    public static let edgeMargin: CGFloat = 8

    /// Centers of cancel, confirm and the reason capsule.
    public struct ActionRow: Equatable {
        public let cancel: CGPoint
        public let confirm: CGPoint
        public let reason: CGPoint
    }

    /// Where cancel, confirm and the reason capsule sit for a ghost
    /// centered at `center`: under the lowest arrows, but moved inside the
    /// safe area when a low or edge ghost would push them off screen, so
    /// the player can always confirm without panning first.
    /// `reasonSize` is the capsule's measured size, nil without one.
    public static func actionRow(center: CGPoint, viewSize: CGSize, insets: EdgeInsets, reasonSize: CGSize?) -> ActionRow {
        let halfButton = buttonSize / 2
        let lowestExtent = reasonSize.map { reasonDrop + $0.height / 2 } ?? halfButton
        let maxY = viewSize.height - insets.bottom - edgeMargin - lowestExtent
        let minY = insets.top + edgeMargin + halfButton
        let y = max(min(center.y + arrowRadius + actionGap, maxY), minY)
        func inside(_ x: CGFloat, halfWidth: CGFloat) -> CGFloat {
            let lowest = insets.leading + edgeMargin + halfWidth
            let highest = viewSize.width - insets.trailing - edgeMargin - halfWidth
            return max(min(x, highest), lowest)
        }
        let x = inside(center.x, halfWidth: actionGap + halfButton)
        return ActionRow(
            cancel: CGPoint(x: x - actionGap, y: y),
            confirm: CGPoint(x: x + actionGap, y: y),
            reason: CGPoint(x: inside(x, halfWidth: (reasonSize?.width ?? 0) / 2), y: y + reasonDrop)
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
