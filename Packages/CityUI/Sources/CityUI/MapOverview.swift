import CityCore
import CoreGraphics
import Foundation

/// The Apple TV map overview's cursor, in fractional tiles. Session state,
/// never saved. Spec: `platform-shells` / Apple TV map overview. Design D7.
public struct MapOverview: Equatable, Sendable {
    public var cursorX: Double
    public var cursorY: Double

    public var cursorTile: TileCoordinate {
        TileCoordinate(x: Int(cursorX.rounded()), y: Int(cursorY.rounded()))
    }

    /// Tiles a directional click steps the cursor.
    static let clickStep = 4.0
    /// The overview's padding above and below its content.
    static let verticalPadding: CGFloat = 60

    /// The overview map's width in an area of `size` points: room for the
    /// side margins, the header and the hints, and 2:1 like the map.
    static func mapWidth(in size: CGSize) -> CGFloat {
        min(size.width - 160, (size.height - 300) * 2)
    }

    /// The map's width on Apple TV's 1920 by 1080 point screen.
    static let mapWidthPoints = Double(mapWidth(in: CGSize(width: 1920, height: 1080 - verticalPadding * 2)))

    /// Screen points per unit of `u` on the overview of a map whose sides
    /// add up to `span` tiles, so a swipe moves the cursor as far as the
    /// finger travels.
    static func pointsPerUnit(span: Int) -> Double {
        mapWidthPoints / Double(max(span, 1))
    }
}

public extension GameSession {
    /// Opens the overview with its cursor on the camera's center.
    func openOverview() {
        overview = MapOverview(cursorX: world.camera.centerX, cursorY: world.camera.centerY)
        clampOverviewCursor()
    }

    func closeOverview() {
        overview = nil
    }

    /// Moves the cursor by a swipe of `dx`, `dy` screen points, y down,
    /// in the map's iso orientation.
    func moveOverviewCursor(dx: Double, dy: Double) {
        let scale = MapOverview.pointsPerUnit(span: world.mapWidth + world.mapHeight)
        let delta = MinimapProjection.tileOffset(across: dx / scale, down: dy / (scale / 2))
        overview?.cursorX += delta.x
        overview?.cursorY += delta.y
        clampOverviewCursor()
    }

    /// Steps the cursor along the iso axis a click steps the reticle.
    func stepOverviewCursor(_ direction: RemoteDirection) {
        let offset = direction.nudge.tileOffset
        overview?.cursorX += Double(offset.dx) * MapOverview.clickStep
        overview?.cursorY += Double(offset.dy) * MapOverview.clickStep
        clampOverviewCursor()
    }

    /// Centers the camera on the cursor's tile at once and closes the
    /// overview.
    func jumpToOverviewCursor() {
        guard let tile = overview?.cursorTile else { return }
        centerCamera(onX: Double(tile.x), y: Double(tile.y), animated: false)
        closeOverview()
    }

    private func clampOverviewCursor() {
        guard let cursor = overview else { return }
        let (x, y) = MinimapProjection.clamp(
            x: cursor.cursorX, y: cursor.cursorY, mapWidth: world.mapWidth, mapHeight: world.mapHeight
        )
        overview = MapOverview(cursorX: x, cursorY: y)
    }
}

/// The remote's rules while the overview is open. Design D7.
extension RemoteInputMapper {
    /// Toggles the overview on the controller's X while the map has focus,
    /// and handles `input` while it is open. Nil when the input is not the
    /// overview's, such as a Play/Pause press or a tick.
    mutating func handleOverview(_ input: RemoteInput, session: GameSession) -> [RemoteEffect]? {
        guard focus == .map else { return nil }
        guard session.overview != nil else {
            overviewSelectArmed = false
            guard input == .overview else { return nil }
            session.openOverview()
            return [.focusMap]
        }
        switch input {
        case let .swipe(dx, dy):
            session.moveOverviewCursor(dx: dx, dy: dy)
        case let .click(direction):
            session.stepOverviewCursor(direction)
        case .selectDown:
            overviewSelectArmed = true
        case .selectUp:
            // Only a press that began in the overview jumps: the release of
            // the press that opened it, which UIKit and GameController can
            // both report, must not.
            if overviewSelectArmed { session.jumpToOverviewCursor() }
            overviewSelectArmed = false
        case .back, .overview:
            session.closeOverview()
        case .zoomAxis, .menu:
            break
        case .playPauseDown, .playPauseUp, .tick, .focusChanged:
            return nil
        }
        return []
    }
}
