import CityCore
import SpriteKit

public extension SpriteAtlas.WalkerFacing {
    /// The facing for a step in tile space: +x is screen down-right (se),
    /// +y is down-left (sw); the larger component wins.
    init(stepX dx: Double, stepY dy: Double) {
        if abs(dx) >= abs(dy) {
            self = dx >= 0 ? .se : .nw
        } else {
            self = dy >= 0 ? .sw : .ne
        }
    }
}

extension SKSpriteNode {
    static let walkKey = "walk"

    /// A person node, anchored at the feet; the caller sorts it by depth (`IsoWorldScene.depthZ`).
    static func walker() -> SKSpriteNode {
        let node = SKSpriteNode()
        node.anchorPoint = SpriteAtlas.walkerAnchor
        return node
    }

    /// Shows the first of `frames` and, while `moving`, loops them at `key`'s pace. The loop comes from
    /// the shared action cache when the frames are `key`'s own.
    func playWalkCycle(_ key: SpriteAnimation.AnimationKey, frames: [SKTexture]?, moving: Bool = true) {
        removeAction(forKey: Self.walkKey)
        guard let frames, let first = frames.first else { return }
        texture = first
        size = first.size()
        guard moving, frames.count > 1, let entry = SpriteAnimation.entry(for: key) else { return }
        let loop = SpriteAnimation.loopingAction(for: key) ?? .repeatForever(.animate(with: frames, timePerFrame: entry.timePerFrame))
        run(loop, withKey: Self.walkKey)
    }
}

extension SKNode {
    static let glideKey = "glide"

    /// Moves to the next 10 Hz position over `duration` instead of jumping,
    /// replacing any glide still running.
    func glide(to target: CGPoint, duration: TimeInterval = 0.1) {
        run(.move(to: target, duration: duration), withKey: Self.glideKey)
    }
}

extension StrollerPlanner {
    /// Residents are out walking by day and at dusk.
    static func residentsOut(atTick tick: UInt64) -> Bool {
        let phase = TimeOfDay(tick: tick).phase
        return phase == .day || phase == .dusk
    }
}
