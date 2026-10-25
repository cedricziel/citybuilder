import CityCore
import SwiftUI

extension GameSession {
    /// Iso projection constants. Kept here (rather than imported from
    /// CityRender2D) so CityUI does not depend on the renderer package.
    static let tileWidth: Double = 64
    static let tileHeight: Double = 32

    /// Translate a screen-space pan delta (pixels) into a tile-space
    /// camera delta and apply it.
    ///
    /// Derived from first principles:
    /// - SwiftUI DragGesture.translation: y is DOWN-positive
    /// - SpriteKit scene (and IsoMath): y is UP-positive
    /// - For the world to follow the finger, the camera must move OPPOSITE
    ///   the finger by the same screen amount. In scene-y-up coords:
    ///       camera_dx_scene = -dxScreen
    ///       camera_dy_scene = +dyScreen   (sign flip because of y-down → y-up)
    /// - Inverting the iso projection (screen.x = (col-row)·halfW,
    ///   scene.y = -(col+row)·halfH):
    ///       dCol - dRow =  camera_dx_scene / halfW = -dxScreen / halfW
    ///       dCol + dRow = -camera_dy_scene / halfH = -dyScreen / halfH
    ///   →   dCol = -(dxScreen/tileWidth + dyScreen/tileHeight) / zoom
    ///       dRow =  (dxScreen/tileWidth - dyScreen/tileHeight) / zoom
    ///
    /// Concrete check: drag up by 32 px (dyScreen = -32) yields dCol = +1,
    /// dRow = +1, so the camera's (col, row) both increase, scene-y
    /// decreases, camera moves DOWN in scene, content shifts UP — which is
    /// "drag up → scroll down" in scroll-bar parlance.
    public func handlePanDelta(deltaX: CGFloat, deltaY: CGFloat) {
        cameraGlide = nil
        let zoom = max(world.camera.zoom, 0.0001)
        let dxOverW = Double(deltaX) / Self.tileWidth
        let dyOverH = Double(deltaY) / Self.tileHeight
        let dCol = -(dxOverW + dyOverH) / zoom
        let dRow = (dxOverW - dyOverH) / zoom
        world.camera.pan(deltaX: dCol, deltaY: dRow)
        cameraDidMove()
    }

    /// Apply a pinch factor (relative to last reading) to the zoom.
    public func handlePinch(factor: CGFloat) {
        world.camera.multiplyZoom(by: Double(factor))
    }
}
