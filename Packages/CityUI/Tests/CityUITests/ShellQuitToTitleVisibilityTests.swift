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

/// Simulates the shipped iOS shell's pause-menu factory output and
/// verifies that — after `TitleScreenHost.injectQuitToTitle(...)` wraps
/// it — the `PauseMenuViewModel` exposes a Quit-to-Title action.
@MainActor
@Test("scenario: Quit to Title is visible on the iOS shell")
func scenarioQuitToTitleVisibleOnIOS() {
    let viewModel = TitleScreenViewModel(
        saveStore: EmptyFacade(),
        sessionFactory: { GameSession(world: $0) }
    )
    let shellConfig = PauseMenuConfig(
        platform: .iOS,
        onSaveGame: {}
    )
    let wrapped = TitleScreenHost.injectQuitToTitle(into: shellConfig, viewModel: viewModel)
    let session = GameSession(world: World.newGame())
    let pauseVM = PauseMenuViewModel(
        session: session,
        platform: wrapped.platform,
        onSaveGame: wrapped.onSaveGame,
        onSettings: {},
        onQuitToTitle: wrapped.onQuitToTitle,
        onQuit: wrapped.onQuit
    )
    let kinds = pauseVM.actions.map(\.kind)
    #expect(kinds == [.resume, .saveGame, .settings, .quitToTitle])
}

/// Same check for the macOS shell — Quit to Title appears between
/// Settings and Quit.
@MainActor
@Test("scenario: Quit to Title is visible on the macOS shell")
func scenarioQuitToTitleVisibleOnMac() {
    let viewModel = TitleScreenViewModel(
        saveStore: EmptyFacade(),
        sessionFactory: { GameSession(world: $0) }
    )
    let shellConfig = PauseMenuConfig(
        platform: .mac,
        onSaveGame: {},
        onQuit: {}
    )
    let wrapped = TitleScreenHost.injectQuitToTitle(into: shellConfig, viewModel: viewModel)
    let session = GameSession(world: World.newGame())
    let pauseVM = PauseMenuViewModel(
        session: session,
        platform: wrapped.platform,
        onSaveGame: wrapped.onSaveGame,
        onSettings: {},
        onQuitToTitle: wrapped.onQuitToTitle,
        onQuit: wrapped.onQuit
    )
    let kinds = pauseVM.actions.map(\.kind)
    #expect(kinds == [.resume, .saveGame, .settings, .quitToTitle, .quit])
}
