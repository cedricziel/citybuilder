import Testing
@testable import CityUI

@Test("CityUI exposes a version constant")
func cityUIHasVersion() {
    #expect(!CityUI.version.isEmpty)
}
