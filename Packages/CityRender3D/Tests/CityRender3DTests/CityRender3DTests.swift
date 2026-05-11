import Testing
@testable import CityRender3D

@Test("CityRender3D exposes a version constant")
func cityRender3DHasVersion() {
    #expect(!CityRender3D.version.isEmpty)
}
