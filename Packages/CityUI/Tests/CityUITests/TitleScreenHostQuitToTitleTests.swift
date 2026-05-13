import CityCore
import Foundation
import Testing
@testable import CityUI

private final class EmptyFacade: SaveStoreFacade, @unchecked Sendable {
    func mostRecentSave() throws -> SaveSummary? {
        nil
    }

    func load(gameID _: UUID) throws -> World {
        throw NSError(domain: "empty", code: 0)
    }
}

@MainActor
@Test("scenario: Host injects onQuitToTitle into the pause-menu config")
func scenarioHostInjectsOnQuitToTitle() {
    let viewModel = TitleScreenViewModel(
        saveStore: EmptyFacade(),
        sessionFactory: { GameSession(world: $0) }
    )
    let appConfig = PauseMenuConfig(
        platform: .iOS,
        onSaveGame: {},
        onQuitToTitle: nil,
        onQuit: nil
    )
    let wrapped = TitleScreenHost.injectQuitToTitle(
        into: appConfig,
        viewModel: viewModel
    )
    #expect(wrapped.onQuitToTitle != nil)
}

@MainActor
@Test("scenario: Pause-menu Quit to Title returns to title")
func scenarioPauseMenuQuitToTitleReturnsToTitle() {
    let viewModel = TitleScreenViewModel(
        saveStore: EmptyFacade(),
        sessionFactory: { GameSession(world: $0) }
    )
    viewModel.commit(world: World.newGame())
    #expect(viewModel.committedSession != nil)

    let appConfig = PauseMenuConfig(
        platform: .iOS,
        onSaveGame: {},
        onQuitToTitle: nil,
        onQuit: nil
    )
    let wrapped = TitleScreenHost.injectQuitToTitle(
        into: appConfig,
        viewModel: viewModel
    )
    wrapped.onQuitToTitle?()
    #expect(viewModel.committedSession == nil)
}

@MainActor
@Test("scenario: Returning to title and starting a new game uses a fresh session")
func scenarioReturningAndStartingFreshSession() {
    var factoryInvocations = 0
    let viewModel = TitleScreenViewModel(
        saveStore: EmptyFacade(),
        sessionFactory: { world in
            factoryInvocations += 1
            return GameSession(world: world)
        }
    )
    viewModel.commit(world: World.newGame())
    let firstSession = viewModel.committedSession
    #expect(factoryInvocations == 1)

    let wrapped = TitleScreenHost.injectQuitToTitle(
        into: PauseMenuConfig(platform: .iOS, onSaveGame: {}, onQuitToTitle: nil, onQuit: nil),
        viewModel: viewModel
    )
    wrapped.onQuitToTitle?()
    #expect(viewModel.committedSession == nil)

    viewModel.commit(world: World.newGame())
    #expect(factoryInvocations == 2)
    #expect(viewModel.committedSession !== firstSession)
}

@MainActor
@Test("scenario: Host preserves other PauseMenuConfig fields")
func scenarioHostPreservesOtherFields() {
    let viewModel = TitleScreenViewModel(
        saveStore: EmptyFacade(),
        sessionFactory: { GameSession(world: $0) }
    )
    var saveCalls = 0
    var quitCalls = 0
    let appConfig = PauseMenuConfig(
        platform: .mac,
        onSaveGame: { saveCalls += 1 },
        onQuitToTitle: nil,
        onQuit: { quitCalls += 1 }
    )
    let wrapped = TitleScreenHost.injectQuitToTitle(
        into: appConfig,
        viewModel: viewModel
    )
    #expect(wrapped.platform == .mac)
    try? wrapped.onSaveGame()
    wrapped.onQuit?()
    #expect(saveCalls == 1)
    #expect(quitCalls == 1)
}
