import Testing
@testable import CityCore
@testable import CityUI

// platform-shells / Start zoom per device.

@Test("scenario: a phone starts zoomed out")
func phoneStartsZoomedOut() {
    #expect((0.5 ... 0.6).contains(StartZoom.zoom(for: .phone)))
    #expect(StartZoom.zoom(for: .phone) >= Camera.minZoom)
}

@Test("scenario: other devices keep the default zoom")
func otherDevicesKeepDefaultZoom() {
    for idiom in [HUDIdiom.pad, .mac, .tv] {
        #expect(StartZoom.zoom(for: idiom) == 1.0)
    }
}

@MainActor
@Test("scenario: new game starts at the device zoom on the town center")
func newGameCommitAppliesStartZoom() throws {
    let viewModel = NewGameDialogViewModel(startZoom: 0.55)
    let world = try #require(viewModel.commit())
    let reference = World.newGame()
    #expect(world.camera.zoom == 0.55)
    #expect(world.camera.centerX == reference.camera.centerX)
    #expect(world.camera.centerY == reference.camera.centerY)
}
