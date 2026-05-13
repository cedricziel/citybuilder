import CityCore
import Foundation
import Testing
@testable import CityUI

// Tests for the Quit-to-Title auto-save flow added by
// `add-game-pause-menu` → M6. Scenarios under `Requirement: Quit to
// Title auto-saves` in
// openspec/changes/add-game-pause-menu/specs/pause-menu/spec.md.

@MainActor
@Test("scenario: quit to title auto-saves silently")
func scenarioQuitToTitleAutoSavesSilently() {
    var saveCount = 0
    var titleTransitions = 0
    let viewModel = PauseMenuViewModel(
        session: GameSession(),
        platform: .mac,
        onSaveGame: { saveCount += 1 },
        onSettings: {},
        onQuitToTitle: { titleTransitions += 1 },
        onQuit: {}
    )
    viewModel.invoke(.quitToTitle)
    #expect(saveCount == 1, "Quit to Title must auto-save first")
    #expect(titleTransitions == 1, "Quit to Title must then transition")
    // Silent — no status row is shown for the auto-save.
    #expect(viewModel.statusMessage == nil)
}

@MainActor
@Test("scenario: auto-save failure does not block the title transition")
func scenarioAutoSaveFailureDoesNotBlockTheTitleTransition() {
    enum SaveError: Error { case disk }
    var titleTransitions = 0
    let viewModel = PauseMenuViewModel(
        session: GameSession(),
        platform: .mac,
        onSaveGame: { throw SaveError.disk },
        onSettings: {},
        onQuitToTitle: { titleTransitions += 1 },
        onQuit: {}
    )
    viewModel.invoke(.quitToTitle)
    #expect(titleTransitions == 1, "title transition must still fire on save failure")
}

@MainActor
@Test("scenario: most-recent save reflects the post-quit world state")
func scenarioMostRecentSaveReflectsThePostQuitWorldState() {
    // Documentary: the auto-save runs against the session's current
    // World immediately before the title transition, so whatever the
    // player did up to that frame is captured. The check is observable
    // here as "onSaveGame is called once with the current world" —
    // assert the call ordering matches.
    var snapshotsBeforeTransition = 0
    var transitionsAfterSave = 0
    var sawSaveFirst = false
    let viewModel = PauseMenuViewModel(
        session: GameSession(),
        platform: .mac,
        onSaveGame: {
            snapshotsBeforeTransition += 1
            if transitionsAfterSave == 0 { sawSaveFirst = true }
        },
        onSettings: {},
        onQuitToTitle: { transitionsAfterSave += 1 },
        onQuit: {}
    )
    viewModel.invoke(.quitToTitle)
    #expect(snapshotsBeforeTransition == 1)
    #expect(transitionsAfterSave == 1)
    #expect(sawSaveFirst, "save must precede the title transition")
}
