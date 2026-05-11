import Testing
@testable import CityRender2D

@Test("CityRender2D exposes a version constant")
func cityRender2DHasVersion() {
    #expect(!CityRender2D.version.isEmpty)
}
