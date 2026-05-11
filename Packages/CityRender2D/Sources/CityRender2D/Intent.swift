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

    /// Two-finger pan gesture: screen-space delta is converted to a
    /// tile-space camera delta accounting for the current zoom.
    public static func panIntent(
        screenDelta: CGSize,
        camera: Camera
    ) -> Intent {
        let zoomFactor = max(camera.zoom, 0.0001)
        let dxTiles = Double(screenDelta.width) / (Double(IsoMath.tileWidth) * zoomFactor)
        let dyTiles = Double(screenDelta.height) / (Double(IsoMath.tileHeight) * zoomFactor)
        // Iso inverse: a screen-space (dx, dy) splits into both col and row.
        return .panCamera(
            deltaCenterX: dxTiles - dyTiles,
            deltaCenterY: -dxTiles - dyTiles
        )
    }

    /// Pinch gesture: the recognizer's scale factor flows through unchanged;
    /// camera clamping happens in Camera.multiplyZoom(by:).
    public static func pinchIntent(scale: Double) -> Intent {
        .pinchZoom(factor: scale)
    }
}
