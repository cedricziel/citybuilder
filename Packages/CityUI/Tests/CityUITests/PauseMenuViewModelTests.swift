import CityCore
import Foundation
import Testing
@testable import CityUI

// Tests for the PauseMenuViewModel added by `add-game-pause-menu` →
// M2. Scenarios under `Requirement: Modal pause menu over the running
// game` in
// openspec/changes/add-game-pause-menu/specs/pause-menu/spec.md.

@MainActor
@Test("scenario: pause menu surfaces five actions on mac")
func scenarioPauseMenuSurfacesFiveActionsOnMac() {
    let session = GameSession()
    let viewModel = PauseMenuViewModel(
        session: session,
        platform: .mac,
        onSaveGame: {},
        onSettings: {},
        onQuitToTitle: {},
        onQuit: {}
    )
    let kinds = viewModel.actions.map(\.kind)
    #expect(kinds == [.resume, .saveGame, .settings, .quitToTitle, .quit])
}

@MainActor
@Test("scenario: pause menu hides quit on ios")
func scenarioPauseMenuHidesQuitOnIOS() {
    let session = GameSession()
    let viewModel = PauseMenuViewModel(
        session: session,
        platform: .iOS,
        onSaveGame: {},
        onSettings: {},
        onQuitToTitle: {},
        onQuit: nil
    )
    let kinds = viewModel.actions.map(\.kind)
    #expect(kinds == [.resume, .saveGame, .settings, .quitToTitle])
}

@MainActor
@Test("scenario: resume toggles ispaused off")
func scenarioResumeTogglesIsPausedOff() {
    let session = GameSession()
    session.isPaused = true
    let viewModel = PauseMenuViewModel(
        session: session, platform: .mac,
        onSaveGame: {}, onSettings: {}, onQuitToTitle: {}, onQuit: {}
    )
    viewModel.invoke(.resume)
    #expect(session.isPaused == false)
}

@MainActor
@Test("scenario: save game invokes savestore")
func scenarioSaveGameInvokesSaveStore() {
    var saveCount = 0
    let viewModel = PauseMenuViewModel(
        session: GameSession(),
        platform: .mac,
        onSaveGame: { saveCount += 1 },
        onSettings: {},
        onQuitToTitle: {},
        onQuit: {}
    )
    viewModel.invoke(.saveGame)
    #expect(saveCount == 1)
}

@MainActor
@Test("scenario: pause menu hides quit-to-title when callback nil")
func scenarioPauseMenuHidesQuitToTitleWhenCallbackNil() {
    // Pre-title-screen: shells pass nil for onQuitToTitle. The row
    // hides until the title-screen change lands.
    let viewModel = PauseMenuViewModel(
        session: GameSession(),
        platform: .mac,
        onSaveGame: {},
        onSettings: {},
        onQuitToTitle: nil,
        onQuit: {}
    )
    #expect(!viewModel.actions.map(\.kind).contains(.quitToTitle))
}

@MainActor
@Test("scenario: save game surfaces success or failure inline")
func scenarioSaveGameSurfacesSuccessOrFailureInline() {
    enum FakeSaveError: Error { case disk }
    var fail = false
    let viewModel = PauseMenuViewModel(
        session: GameSession(),
        platform: .mac,
        onSaveGame: { if fail { throw FakeSaveError.disk } },
        onSettings: {},
        onQuitToTitle: {},
        onQuit: {}
    )
    viewModel.invoke(.saveGame)
    #expect(viewModel.statusMessage == "Saved")
    fail = true
    viewModel.invoke(.saveGame)
    let message = viewModel.statusMessage ?? ""
    #expect(message.hasPrefix("Couldn't save"))
}

@MainActor
private func quitViewModel(
    events: @escaping (String) -> Void,
    save: @escaping () throws -> Void = {}
) -> PauseMenuViewModel {
    PauseMenuViewModel(
        session: GameSession(), platform: .mac,
        onSaveGame: { try save(); events("save") },
        onSettings: {},
        onQuitToTitle: {},
        onQuit: { events("quit") }
    )
}

@MainActor
@Test("scenario: quit asks before terminating")
func scenarioQuitAsksBeforeTerminating() {
    var events: [String] = []
    let viewModel = quitViewModel { events.append($0) }
    viewModel.invoke(.quit)
    #expect(viewModel.isConfirmingQuit)
    #expect(events.isEmpty)
}

@MainActor
@Test("scenario: save and quit saves then terminates")
func scenarioSaveAndQuitSavesThenTerminates() {
    var events: [String] = []
    let viewModel = quitViewModel { events.append($0) }
    viewModel.invoke(.quit)
    viewModel.confirmQuit(saving: true)
    #expect(events == ["save", "quit"])
}

@MainActor
@Test("scenario: quit without saving skips the save")
func scenarioQuitWithoutSavingSkipsTheSave() {
    var events: [String] = []
    let viewModel = quitViewModel { events.append($0) }
    viewModel.invoke(.quit)
    viewModel.confirmQuit(saving: false)
    #expect(events == ["quit"])
}

@MainActor
@Test("scenario: a failed save keeps the game open")
func scenarioAFailedSaveKeepsTheGameOpen() {
    struct SaveFailed: Error {}
    var events: [String] = []
    let viewModel = quitViewModel(events: { events.append($0) }, save: { throw SaveFailed() })
    viewModel.invoke(.quit)
    viewModel.confirmQuit(saving: true)
    #expect(events.isEmpty)
    #expect(viewModel.statusMessage?.hasPrefix("Couldn't save") == true)
}
