import CityCore
import CoreGraphics
import Foundation
import QuartzCore

/// A camera move toward a target, eased out over `duration`. View state
/// only: the simulation never reads the camera. Design D4.
public struct CameraGlide: Equatable, Sendable {
    public static let duration: TimeInterval = 0.25

    let fromX, fromY, toX, toY: Double
    let start: TimeInterval

    /// The camera center at `now`.
    func position(at now: TimeInterval) -> (x: Double, y: Double) {
        let eased = 1 - pow(1 - progress(at: now), 3)
        return (fromX + (toX - fromX) * eased, fromY + (toY - fromY) * eased)
    }

    func progress(at now: TimeInterval) -> Double {
        min(max((now - start) / Self.duration, 0), 1)
    }
}

/// The minimap moves the camera. Spec: `platform-shells` / Minimap moves
/// the camera.
public extension GameSession {
    /// Centers the camera on the map point under `point`, clamped onto the
    /// map. A glide is stepped by the renderer's per-frame snapshot pull;
    /// Reduce Motion passes `animated: false`.
    func centerCamera(onMinimapPoint point: CGPoint, projection: MinimapProjection, animated: Bool) {
        let (x, y) = projection.clampedTile(at: point)
        centerCamera(onX: x, y: y, animated: animated)
    }

    func centerCamera(onX x: Double, y: Double, animated: Bool) {
        guard animated else {
            cameraGlide = nil
            moveCamera(toX: x, y: y)
            return
        }
        beginCameraGlide(toX: x, y: y, now: CACurrentMediaTime())
    }

    /// Starts a glide from the current camera center; `stepCameraGlide`
    /// moves the camera.
    internal func beginCameraGlide(toX x: Double, y: Double, now: TimeInterval) {
        let camera = world.camera
        cameraGlide = CameraGlide(fromX: camera.centerX, fromY: camera.centerY, toX: x, toY: y, start: now)
    }

    /// Runs once per rendered frame: steps a glide and hands the camera to
    /// the minimap, whose camera layer then redraws only when the camera
    /// moves rather than on every tick.
    internal func frameWillRender(now: TimeInterval) {
        stepCameraGlide(now: now)
        if minimap.camera != world.camera {
            minimap.camera = world.camera
        }
    }

    internal func stepCameraGlide(now: TimeInterval) {
        guard let glide = cameraGlide else { return }
        let (x, y) = glide.position(at: now)
        moveCamera(toX: x, y: y)
        if glide.progress(at: now) >= 1 {
            cameraGlide = nil
        }
    }

    private func moveCamera(toX x: Double, y: Double) {
        world.camera = Camera(centerX: x, centerY: y, zoom: world.camera.zoom)
        cameraDidMove()
    }
}
