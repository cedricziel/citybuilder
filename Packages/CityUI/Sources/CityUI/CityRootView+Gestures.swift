import CityCore
import SwiftUI

/// Pan / zoom gesture helpers split out of `CityRootView` so the main
/// file stays under SwiftLint's 500-line ceiling.
extension CityRootView {
    /// A recognised SwiftUI drag cancels the SpriteKit scene's touches
    /// (UIKit's `cancelsTouchesInView`), so while a build tool is armed
    /// the pan gesture is masked off and drag-to-paint reaches the
    /// scene's `touchesMoved`.
    nonisolated static func panGestureMask(allowsPan: Bool) -> GestureMask {
        allowsPan ? .all : .subviews
    }

    /// Apple TV has neither drag nor pinch; its remote input arrives
    /// separately. On the Mac, pinch, scroll and keys go through
    /// `MacMapInputHost`, which zooms around the cursor.
    ///
    /// simultaneousGesture (vs .gesture) so the underlying SpriteKit scene
    /// still receives touch / mouse events for tap-tile selection. A bare
    /// .gesture(DragGesture(...)) claims the touch sequence and starves the
    /// scene's touchesEnded / mouseUp handlers.
    @ViewBuilder
    func withMapGestures(_ content: some View) -> some View {
        #if os(tvOS)
        tvMapLayer(content)
        #else
        let panned = content
            .simultaneousGesture(panGesture, including: Self.panGestureMask(allowsPan: session.allowsCameraPan))
        #if os(macOS)
        panned
            .background { MacMapInputHost(session: session, rail: $buildRail, inspectorExpanded: $inspectorExpanded) }
            .focusedSceneValue(\.gameSession, session)
        #else
        panned.simultaneousGesture(zoomGesture)
        #endif
        #endif
    }

    #if !os(tvOS)
    /// One-finger drag (iOS) / left-mouse drag (Mac) pans the camera.
    /// Deltas are kept in screen pixels; the GameSession translates to
    /// tile-space via CityRender2D.InputTranslator.
    var panGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                // When a build tool is armed, drag is "paint" — handled
                // by the SKScene's mouseDragged / touchesMoved. The pan
                // gesture stays out of the way.
                guard session.allowsCameraPan else { return }
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

    #endif

    #if os(iOS)
    /// Pinch on iOS. SwiftUI's
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
    #endif
}
