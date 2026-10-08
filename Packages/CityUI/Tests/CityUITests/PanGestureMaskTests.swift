import CityCore
import SwiftUI
import Testing
@testable import CityUI

// A recognised SwiftUI drag cancels the SpriteKit scene's touches, so
// while a build tool is armed the pan gesture must be masked off or
// drag-to-paint never reaches the scene.

@MainActor
private func mask(whileArmed tool: BuildTool) -> GestureMask {
    let session = GameSession(world: World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1))
    session.selectedTool = tool
    return CityRootView.panGestureMask(allowsPan: session.allowsCameraPan)
}

@Test("pan gesture is active while inspecting")
@MainActor
func panGestureActiveWhileInspecting() {
    #expect(mask(whileArmed: .inspect) == .all)
}

@Test("pan gesture is masked off while a build tool is armed")
@MainActor
func panGestureMaskedWhileBuilding() {
    #expect(mask(whileArmed: .place(.road)) == .subviews)
    #expect(mask(whileArmed: .demolish) == .subviews)
}
