import CityCore
import Foundation

/// A direction on the remote's clickpad or a controller's D-pad.
public enum RemoteDirection: Hashable, Sendable, CaseIterable {
    case up, right, down, left

    /// The iso axis a click steps along: up north-east, right south-east,
    /// down south-west and left north-west, so clicks alone reach every
    /// tile. Design D2.
    public var nudge: NudgeDirection {
        switch self {
        case .up: .ne
        case .right: .se
        case .down: .sw
        case .left: .nw
        }
    }
}

/// The reticle and camera rules for the Siri Remote. The reticle is the
/// camera's center tile; on Apple TV the camera center stays on the map
/// so every tile can be the reticle tile. Spec: `tv-remote-controls` /
/// Reticle marks the target tile, Zoom without pinch. Design D1.
public extension GameSession {
    nonisolated static let zoomStep = 1.5

    /// Switches the session to the Apple TV input rules.
    func useAppleTVInput() {
        clampsCameraToMap = true
        confirmsBuildingPlacement = true
    }

    var reticleTile: TileCoordinate {
        world.camera.centerTile()
    }

    /// The tile a click in `direction` steps the reticle to.
    func reticleHint(_ direction: RemoteDirection) -> TileCoordinate {
        let offset = direction.nudge.tileOffset
        return TileCoordinate(x: reticleTile.x + offset.dx, y: reticleTile.y + offset.dy)
    }

    func stepCamera(_ direction: RemoteDirection) {
        let offset = direction.nudge.tileOffset
        world.camera.pan(deltaX: Double(offset.dx), deltaY: Double(offset.dy))
        cameraDidMove()
    }

    func zoomIn() {
        world.camera.multiplyZoom(by: Self.zoomStep)
    }

    func zoomOut() {
        world.camera.multiplyZoom(by: 1 / Self.zoomStep)
    }

    /// Steps the zoom through 2.0, 1.0, 0.5 and the map overview, wrapping
    /// back to 2.0; any other zoom goes to 1.0. Spec: `platform-shells` /
    /// Apple TV map overview.
    func cycleZoomLevel() {
        if overview != nil {
            closeOverview()
            world.camera.setZoom(2.0)
            return
        }
        switch world.camera.zoom {
        case 2.0: world.camera.setZoom(1.0)
        case 1.0: world.camera.setZoom(0.5)
        case 0.5: openOverview()
        default: world.camera.setZoom(1.0)
        }
    }

    /// How far past the map's edge the camera center may go, in tiles.
    nonisolated static let cameraMapMargin = 8.0

    /// Runs after every camera move. The camera center stays within
    /// `cameraMapMargin` of the map, so the island can't be lost; on Apple
    /// TV it stays on the map, and a pending placement follows the reticle
    /// (design D5). Spec: `rendering-2_5d` / Camera stays near the map.
    internal func cameraDidMove() {
        guard world.mapWidth > 0, world.mapHeight > 0 else { return }
        let (width, height) = (Double(world.mapWidth), Double(world.mapHeight))
        let (low, highX, highY) = clampsCameraToMap
            ? (0, width.nextDown, height.nextDown)
            : (-Self.cameraMapMargin, width + Self.cameraMapMargin, height + Self.cameraMapMargin)
        world.camera.centerX = min(max(world.camera.centerX, low), highX)
        world.camera.centerY = min(max(world.camera.centerY, low), highY)
        if clampsCameraToMap { pendingPlacement?.anchor = reticleTile }
    }
}
