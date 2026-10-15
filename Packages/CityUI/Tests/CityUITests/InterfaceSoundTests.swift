import CityCore
import Foundation
import Testing
@testable import CityUI

// Spec `platform-shells`: "Interface actions make a sound". The sink is
// global, so these tests run one at a time.

private final class NoSaves: SaveStoreFacade, @unchecked Sendable {
    func mostRecentSave() throws -> SaveSummary? {
        nil
    }

    func load(gameID _: UUID) throws -> World {
        World.newGame()
    }
}

@MainActor
@Suite(.serialized)
struct InterfaceSoundTests {
    private func recording(_ body: () -> Void) -> [UISound] {
        var heard: [UISound] = []
        UISounds.sink = { heard.append($0) }
        defer { UISounds.sink = nil }
        body()
        return heard
    }

    @Test("scenario: title menu choices tap")
    func titleMenuChoicesTap() {
        let viewModel = TitleScreenViewModel(saveStore: NoSaves(), sessionFactory: { GameSession(world: $0) })
        let heard = recording {
            viewModel.newGameRequested()
            viewModel.settingsRequested()
        }
        #expect(heard == [.tap, .tap])
    }

    @Test("scenario: build drawer opens and closes with a sound")
    func buildDrawerOpensAndCloses() {
        var rail = BuildRailModel()
        let heard = recording {
            rail.toggle(.gather)
            rail.toggle(.gather)
        }
        #expect(heard == [.open, .close])
    }

    @Test("scenario: tools and pause make a sound")
    func toolsAndPauseMakeASound() {
        let session = GameSession(world: World.newGame())
        let heard = recording {
            session.selectTool(.place(.road))
            session.isPaused = true
        }
        #expect(heard == [.select, .toggle])
    }

    @Test("scenario: a rejected placement knocks")
    func rejectedPlacementKnocks() {
        let session = GameSession(world: World.newGame())
        session.selectTool(.place(.house))
        let water = TileCoordinate(x: 0, y: 0)
        let heard = recording { session.handleTap(at: water) }
        #expect(heard == [.reject])
    }

    @Test func noSinkIsSilent() {
        UISounds.sink = nil
        UISounds.play(.tap)
    }
}
