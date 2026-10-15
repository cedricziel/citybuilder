import Testing
@testable import CityUI

@Test("scenario: build drawer slides from the rail")
func buildDrawerSlidesFromTheRail() {
    #expect(PanelMotion.drawerStyle(for: .leftRail) == .slide(.leading))
    #expect(PanelMotion.drawerStyle(for: .bottomDock) == .slide(.bottom))
    #expect(PanelMotion.duration(reduceMotion: false) == 0.3)
}

@Test("scenario: inspector callout rises into place")
func inspectorCalloutRises() {
    #expect(PanelMotion.style(.rise, reduceMotion: false) == .rise)
    #expect(PanelMotion.riseOffset == 12)
}

@Test("scenario: HUD panels fade under reduce motion")
func panelsFadeUnderReduceMotion() {
    #expect(PanelMotion.style(PanelMotion.drawerStyle(for: .leftRail), reduceMotion: true) == .fade)
    #expect(PanelMotion.style(PanelMotion.drawerStyle(for: .bottomDock), reduceMotion: true) == .fade)
    #expect(PanelMotion.style(.rise, reduceMotion: true) == .fade)
    #expect(PanelMotion.style(.slide(.bottom), reduceMotion: true) == .fade)
    #expect(PanelMotion.duration(reduceMotion: true) == 0.15)
}
