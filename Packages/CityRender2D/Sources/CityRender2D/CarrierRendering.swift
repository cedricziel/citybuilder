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
        switch mission {
        case let .deliver(good, _, _, _), let .retrieve(good, _, _, _), let .deliverToConstructionSite(good, _, _, _): good
        }
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
}

struct CarrierLook: Equatable {
    let load: CarrierLoad
    let facing: SpriteAtlas.WalkerFacing
}

extension IsoWorldScene {
    /// Despawns finished carriers, and glides live ones to their tile over
    /// the time since their last step, so they keep pace at any speed.
    func reconcileCarriers(with snapshot: WorldSnapshot, now: TimeInterval) {
        guard snapshot.tickCount != lastCarrierTick else { return }
        lastCarrierTick = snapshot.tickCount
        let live = Set(snapshot.carriers.map(\.id))
        for (id, visual) in carrierVisuals where !live.contains(id) {
            visual.node.removeFromParent()
            carrierVisuals.removeValue(forKey: id)
        }
        for carrier in snapshot.carriers {
            let look = CarrierLook(load: CarrierLoad.family(of: carrier.good), facing: Self.facing(of: carrier))
            let target = Self.position(of: carrier)
            guard var visual = carrierVisuals[carrier.id] else {
                let node = SKSpriteNode.walker()
                node.position = target
                node.zPosition = Self.zPosition(of: carrier)
                Self.animate(node, look: look)
                addChild(node)
                carrierVisuals[carrier.id] = CarrierVisual(node: node, look: look, target: target, movedAt: now)
                continue
            }
            if visual.look != look {
                visual.look = look
                Self.animate(visual.node, look: look)
            }
            visual.node.zPosition = Self.zPosition(of: carrier)
            if visual.target != target {
                let step = min(0.25, max(0.03, now - visual.movedAt))
                visual.node.glide(to: target, duration: step)
                visual.target = target
                visual.movedAt = now
            }
            carrierVisuals[carrier.id] = visual
        }
    }

    private static func animate(_ node: SKSpriteNode, look: CarrierLook) {
        node.playWalkCycle(.carrier(look.load, look.facing), frames: SpriteAtlas.carrierAnimation(load: look.load, facing: look.facing))
    }

    /// Facing from the next path segment.
    static func facing(of carrier: Carrier) -> SpriteAtlas.WalkerFacing {
        let idx = carrier.pathIndex
        guard idx >= 0, idx < carrier.path.count - 1 else { return .se }
        let from = carrier.path[idx], next = carrier.path[idx + 1]
        return SpriteAtlas.WalkerFacing(stepX: Double(next.x - from.x), stepY: Double(next.y - from.y))
    }

    /// Just above the road it walks on, so buildings nearer the camera
    /// cover it; the nearer of its two tiles while it steps.
    static func zPosition(of carrier: Carrier) -> CGFloat {
        let first = min(max(0, carrier.pathIndex), carrier.path.count)
        let tiles = carrier.path[first ..< min(carrier.path.count, first + 2)]
        let depth = tiles.map { $0.x + $0.y }.max() ?? 0
        return depthZ(Double(depth + 1)) + figureLift
    }

    /// Slightly below the tile centre, so the figure stands on the tile.
    static func position(of carrier: Carrier) -> CGPoint {
        guard let current = carrier.currentTile else { return .zero }
        let base = IsoMath.screenPoint(forTile: current)
        return CGPoint(x: base.x, y: base.y - IsoMath.tileHeight / 2)
    }
}
