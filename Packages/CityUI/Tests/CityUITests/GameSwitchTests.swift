import CityCore
import Foundation
import Testing
@testable import CityUI

// Each game gets its own map view, keyed on `GameSession.instanceID`
// (openspec/changes/anchor-animal-tours).

private struct NoSaves: SaveStoreFacade {
    func mostRecentSave() throws -> SaveSummary? {
        nil
    }

    func load(gameID _: UUID) throws -> World {
        throw NSError(domain: "none", code: 1)
    }
}

@MainActor
@Test("two sessions get different ids even when the first is freed before the second is made")
func sessionIDsNeverRepeat() {
    var first: GameSession? = GameSession(world: World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1))
    let firstID = first?.instanceID
    weak let freed = first
    first = nil
    #expect(freed == nil)
    let second = GameSession(world: World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1))
    #expect(second.instanceID != firstID)
}

@MainActor
@Test("switching games keeps the audio running and the minimap choice")
func switchingGamesKeepsAudioAndSettings() throws {
    let defaults = try #require(UserDefaults(suiteName: "GameSwitchTests"))
    defaults.removePersistentDomain(forName: "GameSwitchTests")
    MinimapPreference.storage(idiom: .mac, store: defaults).wrappedValue = false
    // The audio lives with the app, outside the game view: a session only
    // tells it when a game begins and ends, as the app shells wire it.
    var audio: [String] = []
    let viewModel = TitleScreenViewModel(saveStore: NoSaves()) { world in
        let session = GameSession(world: world)
        session.onEnd = { audio.append("end") }
        audio.append("begin")
        return session
    }
    viewModel.commit(world: World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1))
    let firstID = viewModel.committedSession?.instanceID
    viewModel.commit(world: World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 2))
    #expect(viewModel.committedSession?.instanceID != firstID, "the second game gets a view of its own")
    #expect(audio == ["begin", "end", "begin"], "the old game's sounds end and the new one's begin, once each")
    #expect(!MinimapPreference.storage(idiom: .mac, store: defaults).wrappedValue, "the minimap choice survives the switch")
}
