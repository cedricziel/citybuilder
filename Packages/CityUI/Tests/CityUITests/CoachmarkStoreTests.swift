import Foundation
import Testing
@testable import CityCore
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

// platform-shells / Pinch-to-zoom hint.

private final class StubSaves: SaveStoreFacade, @unchecked Sendable {
    func mostRecentSave() throws -> SaveSummary? {
        nil
    }

    func load(gameID _: UUID) throws -> World {
        World.newGame()
    }
}

@MainActor
@Test("scenario: pinch hint is offered once")
func pinchHintIsOfferedOnce() {
    let flags = MemoryFlags()
    let store = CoachmarkStore(flags: flags)
    let session = GameSession(world: World.newGame())
    session.hideFirstSteps()
    session.offersPinchHint = true
    session.showPinchZoomHintIfNew(using: store)
    #expect(session.banner?.title == "Pinch to zoom")
    #expect(flags.values[CoachmarkStore.pinchZoomKey] == true)
    // A later game on the same device reads the same flag.
    let later = GameSession(world: World.newGame())
    later.hideFirstSteps()
    later.offersPinchHint = true
    later.showPinchZoomHintIfNew(using: CoachmarkStore(flags: flags))
    #expect(later.banner == nil)
}

@MainActor
@Test("scenario: a loaded save skips the pinch hint")
func loadedSaveSkipsPinchHint() {
    let flags = MemoryFlags()
    // A save loaded at tick zero is still a save: only a new game asks for the hint.
    let session = GameSession(world: World.newGame())
    session.hideFirstSteps()
    session.showPinchZoomHintIfNew(using: CoachmarkStore(flags: flags))
    #expect(session.banner == nil)
    // The flag stays free for the next new game.
    #expect(flags.values[CoachmarkStore.pinchZoomKey] != true)
}

@MainActor
@Test("scenario: a new game's session offers the pinch hint, a continued one does not")
func titleCommitMarksNewGames() {
    let viewModel = TitleScreenViewModel(
        saveStore: StubSaves(), sessionFactory: { GameSession(world: $0) }
    )
    viewModel.commit(world: World.newGame())
    #expect(viewModel.committedSession?.offersPinchHint == false)
    viewModel.commit(world: World.newGame(), isNewGame: true)
    #expect(viewModel.committedSession?.offersPinchHint == true)
}

@Test("the pinch hint and the placement coach mark are independent")
func pinchHintIsIndependentOfThePlacementCoachMark() {
    let flags = MemoryFlags()
    let store = CoachmarkStore(flags: flags)
    store.markPinchZoomHintShown()
    #expect(!store.shouldShowPinchZoomHint)
    #expect(store.shouldShowTouchPlacementHint)
}

@MainActor
@Test("scenario: pinch hint shows as a banner that expires")
func pinchHintShowsAsABanner() {
    let session = GameSession(world: World.newGame())
    session.hideFirstSteps()
    session.showPinchZoomHint()
    #expect(session.banner?.title == "Pinch to zoom")
    for _ in 0 ..< Int(GameSession.bannerTicks) {
        session.step()
    }
    #expect(session.banner == nil)
}
