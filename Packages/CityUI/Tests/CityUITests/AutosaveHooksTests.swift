import CityCore
import Foundation
import Testing
@testable import CityUI

@MainActor
@Suite("Autosave hooks")
struct AutosaveHooksTests {
    @Test("each step that ran calls the play-step hook, a paused one does not")
    func playStepHook() {
        let session = GameSession()
        var steps = 0
        session.onPlayStep = { steps += 1 }
        session.step()
        session.step()
        session.isPaused = true
        session.step()
        #expect(steps == 2)
    }

    @Test("crossing into a new season calls the season hook once")
    func seasonHook() {
        let session = GameSession()
        var seasons = 0
        session.onSeasonChange = { seasons += 1 }
        while session.world.tickCount < CalendarState.ticksPerSeason + 5 {
            session.step()
        }
        #expect(seasons == 1)
    }

    @Test("a failed autosave shows a banner")
    func failureBanner() {
        let session = GameSession()
        session.noteAutosaveFailed()
        session.noteAutosaveFailed()
        session.step()
        #expect(session.banner?.title == GameText.string("banner.autosaveFailed.title"))
    }

    @Test("the pause menu says how long ago the last autosave was")
    func autosaveLine() {
        let session = GameSession()
        let now = Date(timeIntervalSince1970: 2_000_000)
        #expect(session.autosaveLine(now: now) == nil)
        session.lastAutosave = now.addingTimeInterval(-20)
        #expect(session.autosaveLine(now: now) == GameText.string("pause.autosaved", "now"))
        session.lastAutosave = now.addingTimeInterval(-300)
        #expect(session.autosaveLine(now: now)?.contains("5") == true)
    }
}
