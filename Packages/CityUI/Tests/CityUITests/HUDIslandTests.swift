import CityCore
import Foundation
import Testing
@testable import CityUI

// Tests for the HUDViewModel's currentIsland binding added by
// `add-island-hud-overlay` → M6. Scenarios from
// openspec/changes/add-island-hud-overlay/specs/rendering-2_5d/spec.md.

// MARK: - Fixtures

/// Two-island world derived from the archipelago generator. Always
/// produces ≥ 2 islands so the multi-island scenarios have distinct
/// camera targets.
private func twoIslandWorld() -> World {
    World.newGame(layout: .archipelago, seed: 7)
}

private func snapshot(_ world: World, cameraAt center: (Double, Double)) -> WorldSnapshot {
    var copy = world
    copy.camera = Camera(centerX: center.0, centerY: center.1, zoom: 1)
    return copy.snapshot()
}

/// Returns a tile-space point inside the island's bounding-box center.
/// The archipelago generator paints filled ellipses so the center is
/// guaranteed to be buildable land.
private func centerOf(_ island: Island) -> (Double, Double) {
    let centerX = Double(island.bounds.minX + island.bounds.maxX) / 2
    let centerY = Double(island.bounds.minY + island.bounds.maxY) / 2
    return (centerX, centerY)
}

/// Find a tile guaranteed to be water in the archipelago. (0, 0) is
/// outside any island silhouette by construction.
private let waterPoint = (0.5, 0.5)

// MARK: - Camera-driven island

@Test("scenario: hud reads current island from camera")
func scenarioHUDReadsCurrentIslandFromCamera() {
    let world = twoIslandWorld()
    let first = world.islands[0]
    let snap = snapshot(world, cameraAt: centerOf(first))
    let hud = HUDViewModel()
    hud.apply(snap)
    #expect(hud.currentIsland?.id == first.id)
    #expect(hud.currentIsland?.name == first.name)
}

@Test("scenario: hud is sticky over water")
func scenarioHUDIsStickyOverWater() {
    let world = twoIslandWorld()
    let first = world.islands[0]
    let hud = HUDViewModel()
    hud.apply(snapshot(world, cameraAt: centerOf(first)))
    #expect(hud.currentIsland?.id == first.id)
    // Pan over open water — HUD must keep the previous island.
    hud.apply(snapshot(world, cameraAt: waterPoint))
    #expect(hud.currentIsland?.id == first.id)
}

@Test("scenario: hud switches when camera enters another island")
func scenarioHUDSwitchesWhenCameraEntersAnotherIsland() {
    let world = twoIslandWorld()
    let first = world.islands[0]
    let second = world.islands[1]
    let hud = HUDViewModel()
    hud.apply(snapshot(world, cameraAt: centerOf(first)))
    #expect(hud.currentIsland?.id == first.id)
    hud.apply(snapshot(world, cameraAt: centerOf(second)))
    #expect(hud.currentIsland?.id == second.id)
}

@Test("scenario: hud is empty when camera has never been on an island")
func scenarioHUDIsEmptyWhenCameraHasNeverBeenOnAnIsland() {
    let world = twoIslandWorld()
    let hud = HUDViewModel()
    // Fresh HUD + camera starts over water (no previous island
    // cached). The island row stays hidden.
    hud.apply(snapshot(world, cameraAt: waterPoint))
    #expect(hud.currentIsland == nil)
}
