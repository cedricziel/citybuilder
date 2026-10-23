import CityCore
import Foundation
import Testing
@testable import CityUI

private final class MutableFacade: SaveStoreFacade, @unchecked Sendable {
    var stored: SaveSummary?
    var loadedWorlds: [UUID: World] = [:]

    init(stored: SaveSummary? = nil) {
        self.stored = stored
    }

    func mostRecentSave() throws -> SaveSummary? {
        stored
    }

    func load(gameID: UUID) throws -> World {
        guard let world = loadedWorlds[gameID] else {
            throw NSError(domain: "stub", code: 1)
        }
        return world
    }
}

@MainActor
@Test("scenario: returnToTitle clears the committed session")
func scenarioReturnToTitleClearsSession() {
    let viewModel = TitleScreenViewModel(
        saveStore: MutableFacade(),
        sessionFactory: { GameSession(world: $0) }
    )
    viewModel.commit(world: World.newGame())
    #expect(viewModel.committedSession != nil)

    viewModel.returnToTitle()
    #expect(viewModel.committedSession == nil)
}

@MainActor
@Test("scenario: returnToTitle refreshes the Continue row")
func scenarioReturnToTitleRefreshesContinue() {
    let facade = MutableFacade(stored: nil)
    let viewModel = TitleScreenViewModel(
        saveStore: facade,
        sessionFactory: { GameSession(world: $0) }
    )
    #expect(viewModel.mostRecentSave == nil)

    viewModel.commit(world: World.newGame())
    // Simulate the pause-menu auto-save writing a save while the game
    // was running; the facade now reports one.
    let written = SaveSummary(
        gameID: UUID(),
        writeDate: Date(timeIntervalSinceReferenceDate: 555),
        displayName: "just saved"
    )
    facade.stored = written

    viewModel.returnToTitle()
    #expect(viewModel.mostRecentSave == written)
}

@MainActor
@Test("scenario: returnToTitle is idempotent")
func scenarioReturnToTitleIdempotent() {
    var factoryInvocations = 0
    let viewModel = TitleScreenViewModel(
        saveStore: MutableFacade(),
        sessionFactory: { world in
            factoryInvocations += 1
            return GameSession(world: world)
        }
    )
    viewModel.returnToTitle()
    viewModel.returnToTitle()
    #expect(viewModel.committedSession == nil)
    #expect(factoryInvocations == 0)
}

@MainActor
@Test("scenario: returning to the title ends the session")
func returningToTheTitleEndsTheSession() {
    let viewModel = TitleScreenViewModel(saveStore: EndSessionStore(), sessionFactory: { GameSession(world: $0) })
    viewModel.commit(world: World.newGame())
    var ended = 0
    viewModel.committedSession?.onEnd = { ended += 1 }
    viewModel.returnToTitle()
    viewModel.returnToTitle()
    #expect(ended == 1)
}

private final class EndSessionStore: SaveStoreFacade, @unchecked Sendable {
    func mostRecentSave() throws -> SaveSummary? {
        nil
    }

    func load(gameID _: UUID) throws -> World {
        World.newGame()
    }
}

@MainActor
@Test("scenario: a new game ends the old one before it starts")
func newGameEndsTheOldOneFirst() {
    var log: [String] = []
    var count = 0
    let viewModel = TitleScreenViewModel(saveStore: EndSessionStore(), sessionFactory: { world in
        count += 1
        log.append("start \(count)")
        let session = GameSession(world: world)
        let number = count
        session.onEnd = { log.append("end \(number)") }
        return session
    })
    viewModel.commit(world: World.newGame())
    viewModel.commit(world: World.newGame())
    #expect(log == ["start 1", "end 1", "start 2"])
}
