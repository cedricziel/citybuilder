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

private final class StoredFacade: SaveStoreFacade, @unchecked Sendable {
    let summary: SaveSummary
    let world: World
    init(summary: SaveSummary, world: World) {
        self.summary = summary
        self.world = world
    }

    func mostRecentSave() throws -> SaveSummary? {
        summary
    }

    func load(gameID _: UUID) throws -> World {
        world
    }
}

@MainActor
@Test("scenario: fresh-install launch shows the title screen")
func scenarioFreshInstallNoSession() {
    var factoryInvocations = 0
    let viewModel = TitleScreenViewModel(
        saveStore: EmptyFacade(),
        sessionFactory: { world in
            factoryInvocations += 1
            return GameSession(world: world)
        }
    )
    #expect(viewModel.committedSession == nil)
    #expect(factoryInvocations == 0)
}

@MainActor
@Test("scenario: subsequent-launch shows the title screen")
func scenarioSubsequentLaunchNoSession() {
    let stored = SaveSummary(
        gameID: UUID(),
        writeDate: Date(timeIntervalSinceReferenceDate: 10),
        displayName: "yesterday"
    )
    var factoryInvocations = 0
    let viewModel = TitleScreenViewModel(
        saveStore: StoredFacade(summary: stored, world: World.newGame()),
        sessionFactory: { world in
            factoryInvocations += 1
            return GameSession(world: world)
        }
    )
    #expect(viewModel.mostRecentSave == stored)
    #expect(viewModel.committedSession == nil)
    #expect(factoryInvocations == 0)
}

@MainActor
@Test("scenario: game view replaces title screen on commit")
func scenarioCommitReplacesTitle() {
    var factoryInvocations = 0
    let viewModel = TitleScreenViewModel(
        saveStore: EmptyFacade(),
        sessionFactory: { world in
            factoryInvocations += 1
            return GameSession(world: world)
        }
    )
    viewModel.commit(world: World.newGame())
    #expect(factoryInvocations == 1)
    #expect(viewModel.committedSession != nil)
}
