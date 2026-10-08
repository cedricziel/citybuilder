import SpriteKit

#if canImport(UIKit)
import UIKit

/// iOS-only long-press wiring. Mac has no long-press equivalent: the
/// palette, hover and click flow stays as is. Spec: `rendering-2_5d` /
/// Long-press intent translation.
final class SceneLongPressRecognizer: UILongPressGestureRecognizer {}

extension IsoWorldScene {
    /// Slightly shorter than UIKit's 0.5 s default so the menu feels
    /// immediate. Finger drift beyond `allowableMovement` cancels, which
    /// leaves pan and drag-to-paint untouched.
    static let longPressDuration: TimeInterval = 0.4

    func installLongPressRecognizer(on view: SKView) {
        guard !(view.gestureRecognizers ?? []).contains(where: { $0 is SceneLongPressRecognizer }) else { return }
        let recognizer = SceneLongPressRecognizer(target: self, action: #selector(longPressRecognized(_:)))
        recognizer.minimumPressDuration = Self.longPressDuration
        view.addGestureRecognizer(recognizer)
    }

    @objc
    private func longPressRecognized(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began, let view else { return }
        dispatchLongPress(at: convertPoint(fromView: recognizer.location(in: view)))
    }
}
#endif
