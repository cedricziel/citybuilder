import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// rendering-2_5d / Port and shipyard animate while operational (#120).

/// The frames an operational shore building of `kind` loops, facing `orientation`, as the scene
/// names them: its facing's stem plus `-operational-N`.
@MainActor
private func loopedFrames(_ kind: BuildingKind, facing orientation: ShoreOrientation) throws -> [String] {
    let entry = try #require(SpriteAnimation.entry(for: .buildingOperational(kind)))
    let stem = ShoreOrientationMath.textureName(kind: kind, orientation: orientation, state: nil, frame: nil)
    return (0 ..< entry.frameCount).map { "\(stem)-operational-\($0)" }
}

/// The frames the shore sprite catalog names for the same facing.
private func catalogFrames(_ kind: BuildingKind, facing orientation: ShoreOrientation, count: Int) -> [String] {
    (0 ..< count).map { ShoreOrientationMath.textureName(kind: kind, orientation: orientation, state: .operational, frame: $0) }
}

/// One pass of `kind`'s loop over stand-in textures, in seconds.
@MainActor
private func cycleSeconds(_ kind: BuildingKind) throws -> TimeInterval {
    let entry = try #require(SpriteAnimation.entry(for: .buildingOperational(kind)))
    let frames = (0 ..< entry.frameCount).map { _ in SKTexture() }
    return SpriteAnimation.cycle(frames, entry: entry).duration
}

@MainActor
@Test("scenario: Cargo comes ashore at an operational port")
func cargoComesAshoreAtAnOperationalPort() throws {
    let entry = try #require(SpriteAnimation.entry(for: .buildingOperational(.port)))
    #expect(entry.loop == .forever)
    #expect(try loopedFrames(.port, facing: .e) == catalogFrames(.port, facing: .e, count: 6))
    #expect(try abs(cycleSeconds(.port) - 2.7) < 0.001)
}

@MainActor
@Test("scenario: The shipyard planks a hull and launches it")
func shipyardPlanksAHullAndLaunchesIt() throws {
    let entry = try #require(SpriteAnimation.entry(for: .buildingOperational(.shipyard)))
    let durations = try #require(entry.frameDurations)
    #expect(entry.loop == .forever)
    // The finished hull holds longest; the empty slipway after its launch shows briefly.
    #expect(durations[3] == durations.max())
    #expect(durations[4] == durations.min())
    #expect(try loopedFrames(.shipyard, facing: .n) == catalogFrames(.shipyard, facing: .n, count: 5))
    #expect(try abs(cycleSeconds(.shipyard) - 12.75) < 0.001)
}

@Test("every operational entry with its own frame durations lists one per frame")
func frameDurationsMatchFrameCounts() {
    for kind in BuildingKind.allCases {
        guard let entry = SpriteAnimation.entry(for: .buildingOperational(kind)), let durations = entry.frameDurations else { continue }
        #expect(durations.count == entry.frameCount, "\(kind)")
        #expect(durations.allSatisfy { $0 > 0 }, "\(kind)")
    }
}
