import Foundation
import Testing
@testable import CityUI

// Scenarios from openspec/changes/add-touch-first-placement/specs/rendering-2_5d
// (First-run coach mark for touch placement). The store is driven directly
// with an in-memory flag store; the overlay itself is iOS-only.

private final class MemoryFlags: FlagStoring {
    var values: [String: Bool] = [:]

    func flag(forKey key: String) -> Bool {
        values[key] ?? false
    }

    func setFlag(_ value: Bool, forKey key: String) {
        values[key] = value
    }
}

@Test("scenario: first-run coach mark shows once and is dismissable")
func scenarioFirstRunCoachMarkShowsOnceAndIsDismissable() {
    let flags = MemoryFlags()
    let store = CoachmarkStore(flags: flags)
    #expect(store.shouldShowTouchPlacementHint)
    store.dismissTouchPlacementHint()
    #expect(flags.values[CoachmarkStore.touchPlacementKey] == true)
    #expect(!store.shouldShowTouchPlacementHint)
}

@Test("scenario: coach mark does not show after dismissal flag is set")
func scenarioCoachMarkDoesNotShowAfterDismissalFlagIsSet() {
    let flags = MemoryFlags()
    flags.values[CoachmarkStore.touchPlacementKey] = true
    #expect(!CoachmarkStore(flags: flags).shouldShowTouchPlacementHint)
}

@Test("the coach mark flag lives under its documented UserDefaults key")
func theCoachMarkFlagLivesUnderItsDocumentedUserDefaultsKey() throws {
    #expect(CoachmarkStore.touchPlacementKey == "com.cedricziel.citybuilder.coachmark.touchPlacement")
    let suite = "CoachmarkStoreTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = CoachmarkStore(flags: defaults)
    #expect(store.shouldShowTouchPlacementHint)
    store.dismissTouchPlacementHint()
    #expect(defaults.bool(forKey: CoachmarkStore.touchPlacementKey))
}
