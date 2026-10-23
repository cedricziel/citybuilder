import CityCore
import CoreGraphics
import SpriteKit

/// A gentle sway for the tree clumps. Spec: `rendering-2_5d` / Trees sway
/// in the wind.
@MainActor
enum TreeSway {
    /// Swaying; paused, holding the current lean; or far out or with Reduce Motion, upright and still.
    typealias State = MotionState

    static let key = "sway"
    /// 0.7°, either way.
    static let amplitude: CGFloat = 0.7 * .pi / 180
    static let period: TimeInterval = 3.5

    /// One action every clump runs: lean one way, then the other, easing.
    static let action: SKAction = {
        let there = SKAction.rotate(toAngle: amplitude, duration: period / 2)
        let back = SKAction.rotate(toAngle: -amplitude, duration: period / 2)
        there.timingMode = .easeInEaseOut
        back.timingMode = .easeInEaseOut
        return .repeatForever(.sequence([there, back]))
    }()

    /// Where in the period a clump starts, from a hash of its tile, so
    /// neighbouring clumps never sway in step.
    static func phase(for coord: TileCoordinate) -> TimeInterval {
        var rng = DeterministicRNG(seed: UInt64(UInt32(bitPattern: Int32(coord.x))) << 32 | UInt64(UInt32(bitPattern: Int32(coord.y))))
        return period * Double(rng.next() % 1000) / 1000
    }

    /// Starts a clump's sway in `state`. Its anchor is the trunk base on
    /// the tile, so it rocks there and never slides.
    static func arm(_ node: SKNode, coord: TileCoordinate, state: State) {
        node.run(.sequence([.wait(forDuration: phase(for: coord)), action]), withKey: key)
        apply(state, to: node)
    }

    static func apply(_ state: State, to node: SKNode) {
        node.speed = state == .running ? 1 : 0
        if state == .stopped { node.zRotation = 0 }
    }
}

extension IsoWorldScene {
    /// Starts, holds or stops every clump on screen when the sway state
    /// changes; on other frames it does nothing.
    func updateTreeSway(zoom: Double, now: TimeInterval) {
        let state: TreeSway.State = zoom < 0.5 ? .stopped : motionState(now: now)
        guard state != treeSwayState else { return }
        treeSwayState = state
        for node in presentSprites.values {
            for clump in node.children where clump.action(forKey: TreeSway.key) != nil {
                TreeSway.apply(state, to: clump)
            }
        }
    }
}
