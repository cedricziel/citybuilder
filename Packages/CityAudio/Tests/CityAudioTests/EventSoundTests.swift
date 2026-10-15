import Foundation
import Testing
@testable import CityAudio

// Spec `audio-playback`: "Game events have sounds".

private let audioDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Resources/Audio")

private func shipped() throws -> (Manifest, Bindings) {
    let manifest = try Manifest.load(from: Data(contentsOf: audioDir.appendingPathComponent("manifest.json")))
    let bindings = try Bindings.load(from: Data(contentsOf: audioDir.appendingPathComponent("bindings.json")), manifest: manifest)
    return (manifest, bindings)
}

private let soundedEvents = [
    "buildingDemolished", "placementRejected", "bankruptcyWarning", "bankruptcyResolved", "seasonChanged",
    "historyEvent", "ageAdvanced", "rivalAgeAdvanced", "scenarioWon", "monumentCompleted", "fuelRanOut",
    "commissionStarted", "marketTraded", "tradeCompleted", "caravanSold"
]

@Test("scenario: every listed event has a sound")
func everyListedEventHasASound() throws {
    let (manifest, bindings) = try shipped()
    let generated = Set(manifest.entries.filter { $0.author == "Citybuilder sound generator" }.map(\.path))
    for event in soundedEvents {
        let cues = (bindings.bindings[event] ?? []).filter { $0.action == .start && $0.bus == .sfx && $0.loop != true }
        #expect(!cues.isEmpty, "\(event) has no sound")
        for cue in cues {
            #expect(generated.contains(cue.file), "\(cue.file) is not generated")
        }
    }
}

@Test("scenario: trades pick among coin sounds")
func tradesPickAmongCoinSounds() throws {
    let (_, bindings) = try shipped()
    let market = Set((bindings.bindings["marketTraded"] ?? []).map(\.file))
    #expect(market.count >= 3)
    #expect(Set((bindings.bindings["tradeCompleted"] ?? []).map(\.file)) == market)
    #expect(Set((bindings.bindings["caravanSold"] ?? []).map(\.file)) == market)
}

@Test("scenario: a rival's new age sounds farther away")
func rivalAgeSoundsFartherAway() throws {
    let (_, bindings) = try shipped()
    let own = try #require(bindings.bindings["ageAdvanced"]?.first)
    let rival = try #require(bindings.bindings["rivalAgeAdvanced"]?.first)
    #expect(rival.file == own.file)
    #expect((rival.volume ?? 1) < (own.volume ?? 1))
}
