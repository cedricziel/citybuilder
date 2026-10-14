import CityCore
import Foundation
import Testing
@testable import CityUI

// Tests for spec `icloud-sync` — "iCloud account not signed in", the
// Apple TV title-screen notice, and the launch restore before the title
// screen lists saves.

private final class RestoringSaveFacade: SaveStoreFacade, @unchecked Sendable {
    var stored: SaveSummary?

    func mostRecentSave() throws -> SaveSummary? {
        stored
    }

    func load(gameID _: UUID) throws -> World {
        World.newGame()
    }
}

@MainActor
private func viewModel(
    saveStore: SaveStoreFacade = RestoringSaveFacade(),
    cloudSync: TitleScreenCloudSync
) -> TitleScreenViewModel {
    TitleScreenViewModel(
        saveStore: saveStore,
        sessionFactory: { GameSession(world: $0) },
        cloudSync: cloudSync
    )
}

@MainActor
@Test("scenario: no iCloud account on Apple TV shows the notice")
func scenarioNoICloudAccountOnAppleTVShowsTheNotice() async {
    let model = viewModel(cloudSync: TitleScreenCloudSync(restoreSaves: { [] }, isAccountAvailable: { false }))

    await model.prepareCloudSaves()

    #expect(model.iCloudNotice == "Sign in to iCloud to keep your cities. Without it, Apple TV may delete your progress.")
    model.newGameRequested()
    #expect(model.presentingNewGameDialog)
}

@MainActor
@Test("Signed-in Apple TV shows no iCloud notice")
func signedInAppleTVShowsNoNotice() async {
    let model = viewModel(cloudSync: TitleScreenCloudSync(restoreSaves: { [] }, isAccountAvailable: { true }))

    await model.prepareCloudSaves()

    #expect(model.iCloudNotice == nil)
}

@MainActor
@Test("Title screen without cloud sync shows no notice")
func titleScreenWithoutCloudSyncShowsNoNotice() async {
    let model = TitleScreenViewModel(
        saveStore: RestoringSaveFacade(),
        sessionFactory: { GameSession(world: $0) }
    )

    await model.prepareCloudSaves()

    #expect(model.iCloudNotice == nil)
}

@MainActor
@Test("Saves restored at launch show in the Continue row")
func savesRestoredAtLaunchShowInTheContinueRow() async {
    let facade = RestoringSaveFacade()
    let restored = SaveSummary(gameID: UUID(), writeDate: Date(), displayName: "Restored")
    let model = viewModel(
        saveStore: facade,
        cloudSync: TitleScreenCloudSync(
            restoreSaves: {
                facade.stored = restored
                return []
            },
            isAccountAvailable: { true }
        )
    )
    #expect(model.mostRecentSave == nil)

    await model.prepareCloudSaves()

    #expect(model.mostRecentSave == restored)
}

private actor ResolutionLog {
    var calls: [(gameID: UUID, keepICloud: Bool)] = []

    func record(_ gameID: UUID, _ keepICloud: Bool) -> Bool {
        calls.append((gameID, keepICloud))
        return true
    }
}

@MainActor
@Test("A newer iCloud save prompts before anything is overwritten")
func newerICloudSavePromptsBeforeOverwriting() async {
    let conflicted = UUID()
    let log = ResolutionLog()
    let model = viewModel(cloudSync: TitleScreenCloudSync(
        restoreSaves: { [conflicted] },
        isAccountAvailable: { true },
        resolveConflict: { await log.record($0, $1) }
    ))

    await model.prepareCloudSaves()
    #expect(model.saveConflicts == [conflicted])
    #expect(await log.calls.isEmpty)

    await model.resolveSaveConflict(keepICloud: true)

    #expect(model.saveConflicts.isEmpty)
    #expect(model.saveConflictFailure == nil)
    let calls = await log.calls
    #expect(calls.map(\.gameID) == [conflicted])
    #expect(calls.map(\.keepICloud) == [true])
}

@MainActor
@Test("A conflict whose resolution fails stays and shows an error")
func aConflictWhoseResolutionFailsStaysAndShowsAnError() async {
    let conflicted = UUID()
    let model = viewModel(cloudSync: TitleScreenCloudSync(
        restoreSaves: { [conflicted] },
        isAccountAvailable: { true },
        resolveConflict: { _, _ in false }
    ))
    await model.prepareCloudSaves()

    await model.resolveSaveConflict(keepICloud: true)

    #expect(model.saveConflicts == [conflicted])
    #expect(model.saveConflictFailure != nil)
}
