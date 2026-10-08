import CityCore
import SwiftUI
import Testing
@testable import CityUI

// A recognised SwiftUI drag cancels the SpriteKit scene's touches, so
// while a build tool is armed the pan gesture must be masked off or
// drag-to-paint never reaches the scene.

@Test("pan gesture is active while inspecting")
func panGestureActiveWhileInspecting() {
    #expect(CityRootView.panGestureMask(for: .inspect) == .all)
}

@Test("pan gesture is masked off while a build tool is armed")
func panGestureMaskedWhileBuilding() {
    #expect(CityRootView.panGestureMask(for: .place(.road)) == .subviews)
    #expect(CityRootView.panGestureMask(for: .demolish) == .subviews)
}
