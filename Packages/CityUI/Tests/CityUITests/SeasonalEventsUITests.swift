import CityCore
import Foundation
import Testing
@testable import CityUI

// Scenarios from openspec/changes/add-event-counterplay (platform-shells /
// New Game offers seasonal events; Seasonal events show banners and a chip;
// Ruins inspector).

@MainActor
@Test("scenario: the events toggle reaches the world, default On")
func eventsToggleReachesTheWorld() throws {
    let dialog = NewGameDialogViewModel()
    #expect(dialog.seasonalEvents)
    #expect(try #require(dialog.commit()).seasonalEvents.enabled)
    dialog.seasonalEvents = false
    #expect(try #require(dialog.commit()).seasonalEvents.enabled == false)
    dialog.mode = .scenario
    dialog.seasonalEvents = true
    #expect(try #require(dialog.commit()).seasonalEvents.enabled)
    dialog.seasonalEvents = false
    dialog.cancel()
    #expect(dialog.seasonalEvents)
}
