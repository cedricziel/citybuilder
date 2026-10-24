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
        /// A building's operational loop and construction frames. `stem` names a look with frames
        /// of its own (a culture variant, a shore facing); nil means the kind's shared
        /// `building-<kind>` frames.
        case buildingOperational(BuildingKind, stem: String? = nil)
        case buildingConstructing(BuildingKind, stem: String? = nil)
        case walker(SpriteAtlas.WalkerFacing, SpriteAtlas.WalkerLook = .worker)
        /// A carrier holding a load; shares the walker's cycle.
        case carrier(CarrierLoad, SpriteAtlas.WalkerFacing)
        /// A carrier with a vehicle (a handcart, later the age's wagon); shares the walker's cycle.
        case vehicle(Vehicle, SpriteAtlas.WalkerFacing)

        /// An animal walking, grazing or pecking (realistic-walkers).
        case animal(SpriteAtlas.AnimalAction, SpriteAtlas.WalkerFacing)

        /// Every resident look and carrier load in every facing (realistic-walkers).
        public static let people: [AnimationKey] = SpriteAtlas.WalkerFacing.allCases.flatMap { facing in
            SpriteAtlas.WalkerLook.allCases.map { AnimationKey.walker(facing, $0) } + CarrierLoad.allCases.map { .carrier($0, facing) }
                + Vehicle.allCases.map { .vehicle($0, facing) }
        }

        /// Every animal action in every facing.
        public static let animals: [AnimationKey] = SpriteAtlas.WalkerFacing.allCases.flatMap { facing in
            SpriteAtlas.AnimalAction.allCases.map { AnimationKey.animal($0, facing) }
        }

        /// People and animals: every figure sprite family the kit renders.
        public static let figures = people + animals
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
        /// How long each frame shows, when the frames don't all show for `timePerFrame`.
        public let frameDurations: [TimeInterval]?

        public init(frameCount: Int, timePerFrame: TimeInterval, loop: Loop, frameDurations: [TimeInterval]? = nil) {
            self.frameCount = frameCount
            self.timePerFrame = timePerFrame
            self.loop = loop
            self.frameDurations = frameDurations
        }
    }

    public static func entry(for key: AnimationKey) -> Entry? {
        switch key {
        case let .terrain(kind):
            switch kind {
            case .water: Entry(frameCount: 4, timePerFrame: 0.20, loop: .forever)
            case .beach: Entry(frameCount: 2, timePerFrame: 0.45, loop: .forever)
            case .grass: Entry(frameCount: 2, timePerFrame: 0.60, loop: .forever)
            case .forest, .mountain: nil
            }
        case let .buildingOperational(kind, _):
            operationalEntry(for: kind)
        case .buildingConstructing:
            Entry(frameCount: 3, timePerFrame: 0, loop: .progress)
        case .walker, .carrier, .vehicle:
            // realistic-walkers D3: an 8-frame gait; frame 0 is the standing pose.
            Entry(frameCount: 8, timePerFrame: 0.1, loop: .forever)
        case let .animal(action, _):
            switch action {
            case .sheepWalk, .cowWalk: Entry(frameCount: 8, timePerFrame: 0.12, loop: .forever)
            case .sheepGraze, .cowGraze: Entry(frameCount: 4, timePerFrame: 0.3, loop: .forever)
            case .hen: Entry(frameCount: 4, timePerFrame: 0.15, loop: .forever)
            }
        }
    }

    private static func operationalEntry(for kind: BuildingKind) -> Entry? {
        switch kind {
        case .sawmill: Entry(frameCount: 4, timePerFrame: 0.18, loop: .forever)
        case .lumberjackHut: Entry(frameCount: 2, timePerFrame: 0.35, loop: .forever)
        case .farm: Entry(frameCount: 2, timePerFrame: 0.50, loop: .forever)
        case .bakery: Entry(frameCount: 2, timePerFrame: 0.40, loop: .forever)
        case .windmill: Entry(frameCount: 4, timePerFrame: 0.20, loop: .forever)
        // Cargo comes ashore: lifted, swung onto the quay, set down, swung back (#120).
        case .port: Entry(frameCount: 6, timePerFrame: 0.45, loop: .forever)
        // The hull is planked in four stages, held once finished, then launched off an empty
        // slipway for a beat before the next keel (#120).
        case .shipyard: Entry(frameCount: 5, timePerFrame: 2.5, loop: .forever, frameDurations: [2.5, 2.5, 2.5, 4.0, 1.25])
        case .house, .warehouse, .road: nil
        default: Entry(frameCount: 2, timePerFrame: 0.40, loop: .forever)
        }
    }

    /// Asset-name suffix for the frame index of a given key. Combined with
    /// the existing terrain/building base names so the atlas can resolve
    /// every frame through one PNG-naming convention:
    ///   terrain-water-0.png, terrain-water-1.png, …
    ///   building-sawmill-operational-0.png, …
    ///   building-house-constructing-0.png, …
    ///   walker-se-0.png, walker-woman-se-7.png, carrier-logs-nw-3.png
    static func assetName(for key: AnimationKey, frame: Int) -> String {
        switch key {
        case let .terrain(kind):
            "terrain-\(kind.rawValue)-\(frame)"
        case let .buildingOperational(kind, stem):
            "\(stem ?? "building-\(kind.rawValue)")-operational-\(frame)"
        case let .buildingConstructing(kind, stem):
            "\(stem ?? "building-\(kind.rawValue)")-constructing-\(frame)"
        case let .walker(facing, look):
            "\(look.stem)-\(facing.rawValue)-\(frame)"
        case let .carrier(load, facing):
            "carrier-\(load.rawValue)-\(facing.rawValue)-\(frame)"
        case let .vehicle(vehicle, facing):
            "\(vehicle.rawValue)-\(facing.rawValue)-\(frame)"
        case let .animal(action, facing):
            "\(action.stem)-\(facing.rawValue)-\(frame)"
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
        if let hit {
            return hit
        }

        guard let entry = entry(for: key),
              entry.loop == .forever,
              let frames = SpriteAtlas.frames(for: key),
              frames.count > 1
        else { return nil }

        let looped = SKAction.repeatForever(cycle(frames, entry: entry))
        actionCacheQueue.sync { actionCache[key] = looped }
        return looped
    }

    /// One pass through `frames` at the entry's cadence.
    static func cycle(_ frames: [SKTexture], entry: Entry) -> SKAction {
        guard let durations = entry.frameDurations, durations.count == frames.count else {
            return .animate(with: frames, timePerFrame: entry.timePerFrame)
        }
        return .sequence(zip(frames, durations).flatMap { frame, duration in
            [SKAction.setTexture(frame), .wait(forDuration: duration)]
        })
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
