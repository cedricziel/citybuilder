import Testing
@testable import CityPersistence

@Test("CityPersistence exposes a version constant")
func cityPersistenceHasVersion() {
    #expect(!CityPersistence.version.isEmpty)
}
