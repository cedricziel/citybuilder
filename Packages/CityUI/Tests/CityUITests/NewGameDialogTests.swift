import CityCore
import Foundation
import Testing
@testable import CityUI

@MainActor
@Test("scenario: Default values produce the MVP world")
func scenarioNewGameDefaultMatchesMVPNewGame() throws {
    let viewModel = NewGameDialogViewModel()
    let world = viewModel.commit()
    let reference = World.newGame()
    #expect(world?.seed == reference.seed)
    #expect(world?.layout == reference.layout)
    #expect(world?.mapWidth == reference.mapWidth)
    #expect(world?.mapHeight == reference.mapHeight)
    #expect(world?.terrainGrid == reference.terrainGrid)

    // Task 6.4: the MVP play experience survives the title-screen
    // detour. The dialog's default path produces the same world the
    // zero-arg `World.newGame()` does, modulo Swift dict iteration
    // order — `occupiedTiles` / `buildings` etc. are unordered maps so
    // JSON bytes aren't a stable comparison surface. The semantic
    // comparison below (seed/layout/dimensions/terrain/occupiedTiles
    // as set) is what the player actually experiences.
    let actual = try #require(world)
    #expect(Set(actual.occupiedTiles.keys) == Set(reference.occupiedTiles.keys))
    #expect(actual.buildings.keys.sorted { $0.raw < $1.raw }
        == reference.buildings.keys.sorted { $0.raw < $1.raw })
    #expect(actual.islands.count == reference.islands.count)
}

@MainActor
@Test("scenario: Layout selection")
func scenarioNewGameArchipelagoLayout() {
    let viewModel = NewGameDialogViewModel()
    viewModel.layout = .archipelago
    let world = viewModel.commit()
    #expect(world?.layout == .archipelago)
    #expect((world?.islands.count ?? 0) >= 2)
}

@MainActor
@Test("scenario: Random seed selection")
func scenarioNewGameRandomSeedCaptured() {
    let viewModel = NewGameDialogViewModel()
    viewModel.useRandomSeed()
    guard case let .random(captured) = viewModel.seedMode else {
        Issue.record("expected .random mode after useRandomSeed()")
        return
    }
    let world = viewModel.commit()
    #expect(world?.seed == captured)
}

@MainActor
@Test("scenario: random tap does not re-roll commit")
func scenarioNewGameRandomCommitDoesNotReroll() {
    let viewModel = NewGameDialogViewModel()
    viewModel.useRandomSeed()
    guard case let .random(captured) = viewModel.seedMode else {
        Issue.record("expected .random mode after useRandomSeed()")
        return
    }
    // Multiple commits with same captured value must produce same seed.
    let first = viewModel.commit()
    let second = viewModel.commit()
    #expect(first?.seed == captured)
    #expect(second?.seed == captured)
}

@MainActor
@Test("scenario: Custom seed input accepted")
func scenarioNewGameCustomSeedAccepted() {
    let viewModel = NewGameDialogViewModel()
    viewModel.seedMode = .custom(text: "12345")
    let world = viewModel.commit()
    #expect(world?.seed == 12345)
}

@MainActor
@Test("scenario: Custom seed input rejected")
func scenarioNewGameCustomSeedRejected() {
    let viewModel = NewGameDialogViewModel()
    viewModel.seedMode = .custom(text: "not-a-number")
    #expect(!viewModel.isStartEnabled)
    #expect(viewModel.commit() == nil)
}

@MainActor
@Test("scenario: Cancel discards selection")
func scenarioNewGameCancelDiscardsSelection() {
    let viewModel = NewGameDialogViewModel()
    viewModel.layout = .archipelago
    viewModel.seedMode = .custom(text: "99")
    viewModel.cancel()
    #expect(viewModel.layout == .singleIsland)
    if case .default = viewModel.seedMode {
        // ok
    } else {
        Issue.record("expected seedMode reset to .default after cancel")
    }
}
