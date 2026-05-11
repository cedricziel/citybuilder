import Testing
@testable import CityCore

@Test("CityCore exposes a version constant")
func cityCoreHasVersion() {
    #expect(!CityCore.version.isEmpty)
}
