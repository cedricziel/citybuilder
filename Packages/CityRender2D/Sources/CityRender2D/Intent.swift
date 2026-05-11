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
    case panCamera(deltaCenterX: Double, deltaCenterY: Double)
    case pinchZoom(factor: Double)
    case hoverTile(TileCoordinate?)
}

/// Pure translation of raw input geometry into intents. The renderer feeds
/// gesture events through here; tests can drive it directly.
public enum InputTranslator {
    /// Translates a tap at `screenPoint` (in the scene's coordinate space,
    /// after camera transform) into an intent.
    public static func tapIntent(
        atScreenPoint screenPoint: CGPoint,
        mapWidth: Int,
        mapHeight: Int
    ) -> Intent? {
        let coord = IsoMath.nearestTile(toScreenPoint: screenPoint)
        guard coord.x >= 0, coord.x < mapWidth, coord.y >= 0, coord.y < mapHeight else {
            return nil
        }
        return .tapTile(coord)
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
