import CityCore
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
    /// Screen points per unit of `u` a swipe travels, about the overview's
    /// scale on a 1920-point screen.
    static let pointsPerUnit = 8.0
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
        let delta = MinimapProjection.tileOffset(
            across: dx / MapOverview.pointsPerUnit, down: dy / (MapOverview.pointsPerUnit / 2)
        )
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
    /// Opens the overview on the controller's X while the map has focus,
    /// and handles `input` while it is open. False when the input is not
    /// the overview's, such as a Play/Pause press or a tick.
    func handlesOverview(_ input: RemoteInput, session: GameSession) -> Bool {
        guard focus == .map else { return false }
        guard session.overview != nil else {
            if input == .overview { session.openOverview() }
            return input == .overview
        }
        switch input {
        case let .swipe(dx, dy):
            session.moveOverviewCursor(dx: dx, dy: dy)
        case let .click(direction):
            session.stepOverviewCursor(direction)
        case .selectUp:
            session.jumpToOverviewCursor()
        case .back:
            session.closeOverview()
        case .selectDown, .overview, .zoomAxis, .menu:
            // Select acts on release; the rest does nothing here.
            break
        case .playPauseDown, .playPauseUp, .tick, .focusChanged:
            return false
        }
        return true
    }
}
