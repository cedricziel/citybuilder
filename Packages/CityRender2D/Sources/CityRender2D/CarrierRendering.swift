import CityCore
import CoreGraphics
import SpriteKit

/// What a carrier holds, by good family. Carrier sprites are drawn per
/// family, so goods that look alike share one. Spec: `rendering-2_5d` /
/// Carriers glide and show their load.
public enum CarrierLoad: String, CaseIterable, Sendable {
    case logs, sack, barrel, crate

    public static func family(of good: Good) -> CarrierLoad {
        // Goods added in a pack need no Swift edit: they travel in crates.
        switch good {
        case .wood, .planks: .logs
        case .beer, .wine: .barrel
        case .food, .bread, .grain, .flour, .hops, .grapes, .teaLeaves, .tea, .coffeeCherries, .coffee: .sack
        default: .crate
        }
    }
}

extension Carrier {
    var good: Good {
        mission.good
    }
}

public extension SpriteAtlas {
    /// The walk cycle of a carrier holding `load`: its own frames when the
    /// atlas has every one, else the walker's. The one lookup carrier art
    /// goes through.
    static func carrierAnimation(load: CarrierLoad, facing: WalkerFacing) -> [SKTexture]? {
        frames(for: .carrier(load, facing)) ?? walkerAnimation(facing: facing)
    }
}

struct CarrierVisual {
    let node: SKSpriteNode
    var look: CarrierLook
    var target: CGPoint
    var movedAt: TimeInterval
    /// False while the game is paused and the carrier stands on its frame 0.
    var walking = true
}

/// Who walks the road: a carrier with a load, or a fire watch's watchman with his bucket.
enum RoadFigure: Equatable {
    case carrier(CarrierLoad)
    case watchman
}

struct CarrierLook: Equatable {
    let figure: RoadFigure
    let facing: SpriteAtlas.WalkerFacing
}

/// One figure on the road this tick: a carrier, or a watchman, who stands still while he douses.
private struct RoadWalker {
    let id: EntityID
    let look: CarrierLook
    let target: CGPoint
    let moving: Bool
}

extension IsoWorldScene {
    /// Despawns finished carriers, and glides live ones to their tile over
    /// the time since their last step, so they keep pace at any speed.
    func reconcileCarriers(with snapshot: WorldSnapshot, now: TimeInterval) {
        // Every frame: sort each carrier by where its glide has taken it, so one stepping out from behind
        // a building stays behind it until it is level with it.
        for visual in carrierVisuals.values {
            visual.node.zPosition = Self.figureZ(at: visual.node.position)
        }
        guard snapshot.tickCount != lastCarrierTick else {
            // Paused: carriers stop mid-road on their standing frame instead of walking in place.
            if simulationIsStill(now: now) {
                for (id, visual) in carrierVisuals where visual.walking {
                    Self.animate(visual.node, look: visual.look, moving: false)
                    carrierVisuals[id]?.walking = false
                }
            }
            return
        }
        lastCarrierTick = snapshot.tickCount
        let walkers = Self.roadWalkers(in: snapshot)
        let live = Set(walkers.map(\.id))
        for (id, visual) in carrierVisuals where !live.contains(id) {
            visual.node.removeFromParent()
            carrierVisuals.removeValue(forKey: id)
        }
        for walker in walkers {
            let (look, target) = (walker.look, walker.target)
            guard var visual = carrierVisuals[walker.id] else {
                let node = SKSpriteNode.walker()
                node.position = target
                node.zPosition = Self.figureZ(at: target)
                Self.animate(node, look: look, moving: walker.moving)
                addChild(node)
                carrierVisuals[walker.id] = CarrierVisual(node: node, look: look, target: target, movedAt: now, walking: walker.moving)
                continue
            }
            if visual.look != look || visual.walking != walker.moving {
                visual.look = look
                visual.walking = walker.moving
                Self.animate(visual.node, look: look, moving: walker.moving)
            }
            if visual.target != target {
                let step = min(0.25, max(0.03, now - visual.movedAt))
                visual.node.glide(to: target, duration: step)
                visual.target = target
                visual.movedAt = now
            }
            carrierVisuals[walker.id] = visual
        }
    }

    /// The carriers and the watchmen at work, each with its look and where it stands.
    private static func roadWalkers(in snapshot: WorldSnapshot) -> [RoadWalker] {
        snapshot.carriers.map { carrier in
            RoadWalker(
                id: carrier.id,
                look: CarrierLook(figure: .carrier(CarrierLoad.family(of: carrier.good)), facing: facing(of: carrier)),
                target: position(of: carrier.currentTile),
                moving: true
            )
        } + snapshot.watchmen.map { man in
            // Dousing, he stands on the fire's road tile still facing the way he came.
            let step = min(man.pathIndex, man.path.count - 2)
            return RoadWalker(
                id: man.watch,
                look: CarrierLook(figure: .watchman, facing: facing(path: man.path, index: step)),
                target: position(of: man.currentTile),
                moving: !man.isDousing
            )
        }
    }

    /// The figure's own frames, or the walker's while its art is missing, each with its own key.
    private static func animate(_ node: SKSpriteNode, look: CarrierLook, moving: Bool = true) {
        let own: SpriteAnimation.AnimationKey = switch look.figure {
        case let .carrier(load): .carrier(load, look.facing)
        case .watchman: .watchman(look.facing)
        }
        if let frames = SpriteAtlas.frames(for: own) {
            node.playWalkCycle(own, frames: frames, moving: moving)
        } else {
            node.playWalkCycle(.walker(look.facing), frames: SpriteAtlas.walkerAnimation(facing: look.facing), moving: moving)
        }
    }

    /// Facing from the next path segment.
    static func facing(of carrier: Carrier) -> SpriteAtlas.WalkerFacing {
        facing(path: carrier.path, index: carrier.pathIndex)
    }

    /// Facing along the step from `path[index]` to the next tile.
    static func facing(path: [TileCoordinate], index: Int) -> SpriteAtlas.WalkerFacing {
        guard index >= 0, index < path.count - 1 else { return .se }
        let from = path[index], next = path[index + 1]
        return SpriteAtlas.WalkerFacing(stepX: Double(next.x - from.x), stepY: Double(next.y - from.y))
    }

    static func position(of carrier: Carrier) -> CGPoint {
        position(of: carrier.currentTile)
    }

    /// Slightly below the tile centre, so the figure stands on the tile.
    static func position(of tile: TileCoordinate?) -> CGPoint {
        guard let current = tile else { return .zero }
        let base = IsoMath.screenPoint(forTile: current)
        return CGPoint(x: base.x, y: base.y - IsoMath.tileHeight / 2)
    }
}
