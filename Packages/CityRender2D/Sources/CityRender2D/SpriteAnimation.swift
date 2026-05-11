import CityCore
import Foundation
import SpriteKit

/// Catalog of animated sprites the renderer plays. Single source of truth
/// for frame count and cadence — IsoWorldScene MUST NOT hard-code these
/// values. Mirrors the BuildingCatalog pattern (design D9).
public enum SpriteAnimation {
    /// Identifier for any animatable sprite. Walker animations go through
    /// the same catalog so the atlas has one lookup path.
    public enum AnimationKey: Hashable, Sendable {
        case terrain(TerrainType)
        case buildingOperational(BuildingKind)
        case buildingConstructing(BuildingKind)
        case walker(SpriteAtlas.WalkerFacing)
    }

    /// `.forever` arms `SKAction.repeatForever(animate(...))` on the node.
    /// `.progress` selects a single frame (no SKAction) based on
    /// construction progress — see `constructionFrame(...)`.
    public enum Loop: Sendable {
        case forever
        case progress
    }

    public struct Entry: Hashable, Sendable {
        public let frameCount: Int
        public let timePerFrame: TimeInterval
        public let loop: Loop

        public init(frameCount: Int, timePerFrame: TimeInterval, loop: Loop) {
            self.frameCount = frameCount
            self.timePerFrame = timePerFrame
            self.loop = loop
        }
    }

    public static func entry(for key: AnimationKey) -> Entry? {
        switch key {
        case let .terrain(kind):
            switch kind {
            case .water: Entry(frameCount: 4, timePerFrame: 0.20, loop: .forever)
            case .beach: Entry(frameCount: 2, timePerFrame: 0.45, loop: .forever)
            case .grass, .forest, .mountain: nil
            }
        case let .buildingOperational(kind):
            switch kind {
            case .sawmill: Entry(frameCount: 4, timePerFrame: 0.18, loop: .forever)
            case .lumberjackHut: Entry(frameCount: 2, timePerFrame: 0.35, loop: .forever)
            case .townCenter: Entry(frameCount: 2, timePerFrame: 0.40, loop: .forever)
            case .house, .warehouse, .road: nil
            }
        case .buildingConstructing:
            Entry(frameCount: 3, timePerFrame: 0, loop: .progress)
        case .walker:
            Entry(frameCount: 2, timePerFrame: 0.15, loop: .forever)
        }
    }

    /// Asset-name suffix for the frame index of a given key. Combined with
    /// the existing terrain/building base names so the atlas can resolve
    /// every frame through one PNG-naming convention:
    ///   terrain-water-0.png, terrain-water-1.png, …
    ///   building-sawmill-operational-0.png, …
    ///   building-house-constructing-0.png, …
    ///   walker-se-0.png, walker-se-1.png (unchanged from M5)
    static func assetName(for key: AnimationKey, frame: Int) -> String {
        switch key {
        case let .terrain(kind):
            "terrain-\(kind.rawValue)-\(frame)"
        case let .buildingOperational(kind):
            "building-\(kind.rawValue)-operational-\(frame)"
        case let .buildingConstructing(kind):
            "building-\(kind.rawValue)-constructing-\(frame)"
        case let .walker(facing):
            "walker-\(facing.rawValue)-\(frame)"
        }
    }

    /// Cached `SKAction` per key. The scene reuses one instance across
    /// every node of the same kind so a screen full of water tiles
    /// allocates exactly one action (design D4).
    private nonisolated(unsafe) static var actionCache: [AnimationKey: SKAction] = [:]
    private static let actionCacheQueue = DispatchQueue(label: "city.spriteanimation.action.cache")

    /// Repeating-forever action for a key, or `nil` if the key has no
    /// `.forever` entry or the frames aren't bundled. Callers `node.run`
    /// the returned action; identity is preserved across calls so the
    /// shared-instance invariant holds.
    public static func loopingAction(for key: AnimationKey) -> SKAction? {
        var hit: SKAction?
        actionCacheQueue.sync { hit = actionCache[key] }
        if let hit { return hit }

        guard let entry = entry(for: key),
              entry.loop == .forever,
              let frames = SpriteAtlas.frames(for: key),
              frames.count > 1
        else { return nil }

        let animate = SKAction.animate(with: frames, timePerFrame: entry.timePerFrame)
        let looped = SKAction.repeatForever(animate)
        actionCacheQueue.sync { actionCache[key] = looped }
        return looped
    }
}

/// Pure function selecting the construction-scaffold frame index from the
/// snapshot's `ticksSincePlacement` and the kind's `buildDurationTicks`.
/// No RNG, no clock — two replays of the same save show the same frame at
/// the same tick (design D3, D7).
public func constructionFrame(
    ticksSincePlacement: UInt64,
    duration: UInt64,
    frameCount: Int
) -> Int {
    guard duration > 0, frameCount > 0 else { return 0 }
    let progress = min(1.0, Double(ticksSincePlacement) / Double(duration))
    let idx = Int(progress * Double(frameCount - 1) + 0.5)
    return min(max(idx, 0), frameCount - 1)
}
