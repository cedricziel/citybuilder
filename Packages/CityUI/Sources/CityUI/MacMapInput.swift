import CoreGraphics
import Foundation

/// A camera move from the Mac's pointer or keyboard. `pan` is in screen
/// points, y down, as a drag would move the map; `zoom` is a factor.
public enum MapCameraAction: Equatable, Sendable {
    case pan(CGSize)
    case zoom(Double)
}

/// Turns Mac trackpad, mouse and key input into camera actions. Pure, so
/// it is testable without `NSEvent`. Spec: `platform-shells` / Mac
/// trackpad and mouse camera, Mac keyboard camera.
public enum MacMapInput {
    /// One tile width, per pan key press.
    static let panStep: CGFloat = 64
    /// Zoom per mouse-wheel notch.
    static let wheelZoomStep = 1.1

    /// A trackpad scroll pans as a drag would; its deltas already follow
    /// the system scroll direction. A mouse wheel zooms, in when the wheel
    /// turns away from the player whatever that setting.
    public static func scroll(deltaX: CGFloat, deltaY: CGFloat, isPrecise: Bool, isInverted: Bool) -> MapCameraAction {
        if isPrecise {
            return .pan(CGSize(width: deltaX, height: deltaY))
        }
        let notches = Double(isInverted ? -deltaY : deltaY)
        return .zoom(pow(wheelZoomStep, notches))
    }

    /// A right- or middle-drag pans like a left-drag.
    public static func drag(deltaX: CGFloat, deltaY: CGFloat) -> MapCameraAction {
        .pan(CGSize(width: deltaX, height: deltaY))
    }

    /// The arrow keys and WASD pan toward the side they name; `+`, `=`
    /// and `-` zoom. `characters` is the key's `charactersIgnoringModifiers`;
    /// U+F700 to U+F703 are AppKit's arrow keys.
    public static func key(_ characters: String) -> MapCameraAction? {
        switch characters.lowercased() {
        case "a", "\u{F702}": .pan(CGSize(width: panStep, height: 0))
        case "d", "\u{F703}": .pan(CGSize(width: -panStep, height: 0))
        case "w", "\u{F700}": .pan(CGSize(width: 0, height: panStep))
        case "s", "\u{F701}": .pan(CGSize(width: 0, height: -panStep))
        case "+", "=": .zoom(GameSession.zoomStep)
        case "-": .zoom(1 / GameSession.zoomStep)
        default: nil
        }
    }
}

public extension GameSession {
    /// Zooms by `factor`, within the camera's limits, keeping the map point
    /// under `offset` (screen points from the view's center, y down) in
    /// place.
    func zoom(by factor: Double, aroundScreenOffset offset: CGSize) {
        let before = world.camera.zoom
        world.camera.multiplyZoom(by: factor)
        let keep = 1 - world.camera.zoom / before
        guard keep != 0 else { return }
        handlePanDelta(deltaX: offset.width * keep, deltaY: offset.height * keep)
    }

    func apply(_ action: MapCameraAction, aroundScreenOffset offset: CGSize = .zero) {
        switch action {
        case let .pan(delta): handlePanDelta(deltaX: delta.width, deltaY: delta.height)
        case let .zoom(factor): zoom(by: factor, aroundScreenOffset: offset)
        }
    }
}
