import CoreGraphics
import SpriteKit
import Testing
@testable import CityRender2D

// realistic-walkers: the shared walk-cycle player behind carriers, strollers and plaza figures.

private func frames(_ count: Int) throws -> [SKTexture] {
    try (0 ..< count).map { _ in
        let context = try #require(CGContext(
            data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        return try SKTexture(cgImage: #require(context.makeImage()))
    }
}

@MainActor
@Test("standing shows frame 0 and runs no cycle")
func standingShowsFrameZero() throws {
    let cycle = try frames(8)
    let node = SKSpriteNode.walker()
    node.playWalkCycle(.walker(.se), frames: cycle, moving: false)
    #expect(node.texture === cycle[0])
    #expect(!node.isWalking)
}

@MainActor
@Test("walking runs the cycle, and asking again leaves it running")
func walkingRunsTheCycleOnce() throws {
    let cycle = try frames(8)
    let node = SKSpriteNode.walker()
    node.playWalkCycle(.walker(.se), frames: cycle)
    let running = try #require(node.action(forKey: SKSpriteNode.walkKey))
    node.playWalkCycle(.walker(.se), frames: cycle)
    #expect(node.action(forKey: SKSpriteNode.walkKey) === running)
    // A turn starts the other facing's cycle; standing stops it.
    node.playWalkCycle(.walker(.sw), frames: cycle)
    #expect(node.action(forKey: SKSpriteNode.walkKey) !== running)
    node.playWalkCycle(.walker(.sw), frames: cycle, moving: false)
    #expect(!node.isWalking && node.texture === cycle[0])
}

@MainActor
@Test("the simulation counts as still once ticks stop for 0.3 s")
func stillnessFollowsTheTicks() {
    let scene = IsoWorldScene()
    scene.noteTick(5, now: 10)
    #expect(!scene.simulationIsStill(now: 10.2))
    #expect(scene.simulationIsStill(now: 10.5))
    scene.noteTick(6, now: 10.6)
    #expect(!scene.simulationIsStill(now: 10.7))
}
