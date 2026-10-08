import CityCore
import CoreGraphics
import Foundation

/// User intents emitted by the renderer's input layer and consumed by a
/// controller. Raw input (taps, pans, pinches) MUST NOT reach CityCore
/// directly — the controller translates intents into Commands.
///
/// Per spec rendering-2_5d "Input mapping".
public enum Intent: Hashable, Sendable {
    case tapTile(TileCoordinate)
    case dragTile(TileCoordinate)
    case panCamera(deltaCenterX: Double, deltaCenterY: Double)
    case pinchZoom(factor: Double)
    case hoverTile(TileCoordinate?)
    /// Finger held still on a tile (iOS only). Opens the tile menu.
    case longPressTile(TileCoordinate)
    /// Commit the pending placement. Spec: `rendering-2_5d` /
    /// Placement-confirmation intents.
    case confirmPlacement
    case cancelPlacement
    case nudgePlacement(direction: IsoDirection)
}

/// The four iso-grid axes along which the placement HUD nudges a pending
/// ghost by one tile. Input-side labelling only; the simulation never sees
/// it. Spec: `rendering-2_5d` / Iso direction enumeration.
public enum IsoDirection: Hashable, Sendable, CaseIterable {
    case ne, se, sw, nw

    /// Tile-grid step for one nudge. `ne` and `nw` decrease y and x, so
    /// they move up on screen; `se` and `sw` move down.
    public var tileOffset: (dx: Int, dy: Int) {
        switch self {
        case .ne: (dx: 0, dy: -1)
        case .se: (dx: 1, dy: 0)
        case .sw: (dx: 0, dy: 1)
        case .nw: (dx: -1, dy: 0)
        }
    }
}

/// Pure translation of raw input geometry into intents. The renderer feeds
/// gesture events through here; tests can drive it directly.
public enum InputTranslator {
    /// The tile under `screenPoint` (scene coordinates), `nil` outside the map.
    public static func tile(
        atScreenPoint screenPoint: CGPoint,
        mapWidth: Int,
        mapHeight: Int
    ) -> TileCoordinate? {
        let coord = IsoMath.nearestTile(toScreenPoint: screenPoint)
        guard coord.x >= 0, coord.x < mapWidth, coord.y >= 0, coord.y < mapHeight else {
            return nil
        }
        return coord
    }

    /// Translates a tap at `screenPoint` (in the scene's coordinate space,
    /// after camera transform) into an intent.
    public static func tapIntent(
        atScreenPoint screenPoint: CGPoint,
        mapWidth: Int,
        mapHeight: Int
    ) -> Intent? {
        tile(atScreenPoint: screenPoint, mapWidth: mapWidth, mapHeight: mapHeight).map(Intent.tapTile)
    }

    /// Translates a long-press at `screenPoint` into an intent, `nil` when
    /// the press lands outside the map.
    public static func longPressIntent(
        atScreenPoint screenPoint: CGPoint,
        mapWidth: Int,
        mapHeight: Int
    ) -> Intent? {
        tile(atScreenPoint: screenPoint, mapWidth: mapWidth, mapHeight: mapHeight).map(Intent.longPressTile)
    }

    /// Drag-canvas pan: screen-space delta converted to a tile-space camera
    /// delta so the world tile under the finger / pointer stays under it.
    ///
    /// Derivation (`screenDelta` is SwiftUI/UIKit y-down-positive):
    ///   camera_dx_scene = -dxScreen
    ///   camera_dy_scene = +dyScreen   (y-down SwiftUI → y-up scene)
    ///   screen_x = (col − row)·halfW          ⇒ dCol−dRow = -dxScreen/halfW
    ///   scene_y  = -(col + row)·halfH         ⇒ dCol+dRow = -dyScreen/halfH
    ///   ⇒ dCol = -(dxScreen/tileWidth + dyScreen/tileHeight) / zoom
    ///     dRow =  (dxScreen/tileWidth − dyScreen/tileHeight) / zoom
    ///
    /// Verified: drag right → dCol<0, dRow>0; drag down → dCol<0, dRow<0.
    /// Camera moves opposite the input direction so the world appears to
    /// track the finger / pointer.
    public static func panIntent(
        screenDelta: CGSize,
        camera: Camera
    ) -> Intent {
        let zoom = max(camera.zoom, 0.0001)
        let dxOverW = Double(screenDelta.width) / Double(IsoMath.tileWidth)
        let dyOverH = Double(screenDelta.height) / Double(IsoMath.tileHeight)
        let dCol = -(dxOverW + dyOverH) / zoom
        let dRow = (dxOverW - dyOverH) / zoom
        return .panCamera(deltaCenterX: dCol, deltaCenterY: dRow)
    }

    /// Pinch gesture: the recognizer's scale factor flows through unchanged;
    /// camera clamping happens in Camera.multiplyZoom(by:).
    public static func pinchIntent(scale: Double) -> Intent {
        .pinchZoom(factor: scale)
    }
}
