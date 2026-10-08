import CityCore
import SwiftUI

/// Pan / zoom gesture helpers split out of `CityRootView` so the main
/// file stays under SwiftLint's 500-line ceiling.
extension CityRootView {
    /// A recognised SwiftUI drag cancels the SpriteKit scene's touches
    /// (UIKit's `cancelsTouchesInView`), so while a build tool is armed
    /// the pan gesture is masked off and drag-to-paint reaches the
    /// scene's `touchesMoved`.
    static func panGestureMask(for tool: BuildTool) -> GestureMask {
        tool == .inspect ? .all : .subviews
    }

    /// One-finger drag (iOS) / left-mouse drag (Mac) pans the camera.
    /// Deltas are kept in screen pixels; the GameSession translates to
    /// tile-space via CityRender2D.InputTranslator.
    var panGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                // When a build tool is armed, drag is "paint" — handled
                // by the SKScene's mouseDragged / touchesMoved. The pan
                // gesture stays out of the way.
                guard session.selectedTool == .inspect else { return }
                session.handlePanDelta(
                    deltaX: value.translation.width - session.lastPanX,
                    deltaY: value.translation.height - session.lastPanY
                )
                session.lastPanX = value.translation.width
                session.lastPanY = value.translation.height
            }
            .onEnded { _ in
                session.lastPanX = 0
                session.lastPanY = 0
            }
    }

    /// Pinch on iOS / two-finger trackpad on Mac. SwiftUI's
    /// MagnificationGesture reports a cumulative scale factor; we apply
    /// the delta since the last reading.
    var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { magnitude in
                let factor = magnitude / session.lastMagnification
                session.handlePinch(factor: factor)
                session.lastMagnification = magnitude
            }
            .onEnded { _ in
                session.lastMagnification = 1.0
            }
    }
}
