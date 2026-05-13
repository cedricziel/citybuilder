import CityCore
import Foundation
import Testing
@testable import CityUI

// Tests for the HUD pause button added by `add-game-pause-menu` →
// M3. Scenarios from
// openspec/changes/add-game-pause-menu/specs/rendering-2_5d/spec.md
// under `Requirement: HUD pause button`. SwiftUI rendering is hard
// to drive headlessly; the symbol-name rule is lifted to a free
// function for a unit-testable surface, and the toggle behavior is
// asserted via `GameSession.isPaused` directly.

@Test("scenario: hud shows the pause glyph when running")
func scenarioHUDShowsThePauseGlyphWhenRunning() {
    #expect(pauseButtonSymbolName(isPaused: false) == "pause.fill")
}

@Test("scenario: hud shows the play glyph when paused")
func scenarioHUDShowsThePlayGlyphWhenPaused() {
    #expect(pauseButtonSymbolName(isPaused: true) == "play.fill")
}

@MainActor
@Test("scenario: tapping the hud pause button toggles ispaused")
func scenarioTappingTheHUDPauseButtonTogglesIsPaused() {
    let session = GameSession()
    #expect(session.isPaused == false)
    // The HUD button's tap action is `session.isPaused.toggle()` —
    // verify the toggle round-trips.
    session.isPaused.toggle()
    #expect(session.isPaused == true)
    session.isPaused.toggle()
    #expect(session.isPaused == false)
}
