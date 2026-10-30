import CityCore
import Testing
@testable import CityUI

// add-event-counterplay task 5.2: with "drawn last" in, the granary is offered.

@Test("scenario: the granary is in the town drawer")
func granaryIsOffered() {
    #expect(BuildPalette.kinds.contains(.granary))
    #expect(BuildCategory.of(.granary) == .town)
}
