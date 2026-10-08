import CityCore
import Foundation
import Testing
@testable import CityUI

// MARK: - Test doubles

private final class StubSaveFacade: SaveStoreFacade, @unchecked Sendable {
    var stored: SaveSummary?
    var loadedWorlds: [UUID: World] = [:]
    var loadCalls: [UUID] = []

    init(stored: SaveSummary? = nil) {
        self.stored = stored
    }

    func mostRecentSave() throws -> SaveSummary? {
        stored
    }

    func load(gameID: UUID) throws -> World {
        loadCalls.append(gameID)
        guard let world = loadedWorlds[gameID] else {
            throw NSError(domain: "stub", code: 1)
        }
        return world
    }
}

// MARK: - Scenarios

@MainActor
@Test("scenario: Continue row hidden when no save exists")
func scenarioTitleNoSaveHidesContinue() {
    let viewModel = TitleScreenViewModel(
        saveStore: StubSaveFacade(stored: nil),
        sessionFactory: { _ in GameSession(world: World.newGame()) }
    )
    #expect(viewModel.mostRecentSave == nil)
}

@MainActor
@Test("scenario: Continue row populated from the newest save")
func scenarioTitleContinuePopulated() {
    let summary = SaveSummary(
        gameID: UUID(),
        writeDate: Date(timeIntervalSinceReferenceDate: 999),
        displayName: "Most recent"
    )
    let viewModel = TitleScreenViewModel(
        saveStore: StubSaveFacade(stored: summary),
        sessionFactory: { _ in GameSession(world: World.newGame()) }
    )
    #expect(viewModel.mostRecentSave == summary)
}

@MainActor
@Test("scenario: Tapping Continue loads the save and commits")
func scenarioTitleContinueLoadsAndCommits() {
    let id = UUID()
    let summary = SaveSummary(gameID: id, writeDate: Date(), displayName: "x")
    let stub = StubSaveFacade(stored: summary)
    let loaded = World.newGame(layout: .archipelago, seed: 42)
    stub.loadedWorlds[id] = loaded

    var committed: World?
    let viewModel = TitleScreenViewModel(
        saveStore: stub,
        sessionFactory: { world in
            committed = world
            return GameSession(world: world)
        }
    )
    viewModel.continueRequested()
    #expect(stub.loadCalls == [id])
    #expect(committed?.seed == 42)
    #expect(committed?.layout == .archipelago)
    #expect(viewModel.committedSession != nil)
}

@MainActor
@Test("scenario: Tapping New Game shows the dialog")
func scenarioTitleNewGameShowsDialog() {
    let viewModel = TitleScreenViewModel(
        saveStore: StubSaveFacade(stored: nil),
        sessionFactory: { _ in GameSession(world: World.newGame()) }
    )
    #expect(!viewModel.presentingNewGameDialog)
    viewModel.newGameRequested()
    #expect(viewModel.presentingNewGameDialog)
}

@MainActor
@Test("scenario: Settings opens from the title screen")
func scenarioTitleSettingsNoSession() {
    var factoryCalls = 0
    let viewModel = TitleScreenViewModel(
        saveStore: StubSaveFacade(stored: nil),
        sessionFactory: { _ in
            factoryCalls += 1
            return GameSession(world: World.newGame())
        }
    )
    viewModel.settingsRequested()
    #expect(viewModel.presentingSettings)
    #expect(factoryCalls == 0)
    #expect(viewModel.committedSession == nil)
}

@MainActor
@Test("scenario: commit invokes session factory with supplied world")
func scenarioTitleCommitInvokesFactory() {
    var seenSeed: UInt64?
    let viewModel = TitleScreenViewModel(
        saveStore: StubSaveFacade(stored: nil),
        sessionFactory: { world in
            seenSeed = world.seed
            return GameSession(world: world)
        }
    )
    let world = World.newGame(layout: .singleIsland, seed: 7)
    viewModel.commit(world: world)
    #expect(seenSeed == 7)
    #expect(viewModel.committedSession != nil)
}

private struct UndecodableSave: Error, CustomStringConvertible {
    var description: String {
        "integrity_failed: keyNotFound(\"terrainGrid\")"
    }
}

private final class CorruptSaveFacade: SaveStoreFacade, @unchecked Sendable {
    let summary: SaveSummary

    init(summary: SaveSummary) {
        self.summary = summary
    }

    func mostRecentSave() throws -> SaveSummary? {
        summary
    }

    func load(gameID _: UUID) throws -> World {
        throw UndecodableSave()
    }
}

@MainActor
@Test("scenario: Undecodable save shows a load-failure alert")
func scenarioTitleUndecodableSaveShowsFailure() {
    let summary = SaveSummary(gameID: UUID(), writeDate: Date(), displayName: "Old save")
    var factoryCalls = 0
    let viewModel = TitleScreenViewModel(
        saveStore: CorruptSaveFacade(summary: summary),
        sessionFactory: { world in
            factoryCalls += 1
            return GameSession(world: world)
        }
    )
    viewModel.continueRequested()
    #expect(viewModel.loadFailure == SaveLoadFailure(
        gameID: summary.gameID,
        reason: "integrity_failed: keyNotFound(\"terrainGrid\")"
    ))
    #expect(SaveLoadFailure.title == "This save could not be loaded")
    #expect(viewModel.committedSession == nil)
    #expect(factoryCalls == 0)
}

@MainActor
@Test("scenario: New Game still works after a failed load")
func scenarioTitleNewGameAfterFailedLoad() {
    let summary = SaveSummary(gameID: UUID(), writeDate: Date(), displayName: "Old save")
    let viewModel = TitleScreenViewModel(
        saveStore: CorruptSaveFacade(summary: summary),
        sessionFactory: { GameSession(world: $0) }
    )
    viewModel.continueRequested()
    viewModel.dismissLoadFailure()
    #expect(viewModel.loadFailure == nil)
    viewModel.newGameRequested()
    #expect(viewModel.presentingNewGameDialog)
}
