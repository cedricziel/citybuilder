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
    /// False while the game is paused and the carrier stands on its frame 0.
    var walking = true
}

struct CarrierLook: Equatable {
    let load: CarrierLoad
    let facing: SpriteAtlas.WalkerFacing
    var vehicle: Carrier.Vehicle = .onFoot
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
        let live = Set(snapshot.carriers.map(\.id))
        for (id, visual) in carrierVisuals where !live.contains(id) {
            visual.node.removeFromParent()
            carrierVisuals.removeValue(forKey: id)
        }
        for carrier in snapshot.carriers {
            let look = CarrierLook(load: CarrierLoad.family(of: carrier.good), facing: Self.facing(of: carrier), vehicle: carrier.vehicle)
            let target = Self.position(of: carrier)
            guard var visual = carrierVisuals[carrier.id] else {
                let node = SKSpriteNode.walker()
                node.position = target
                node.zPosition = Self.figureZ(at: target)
                Self.animate(node, look: look)
                addChild(node)
                carrierVisuals[carrier.id] = CarrierVisual(node: node, look: look, target: target, movedAt: now)
                continue
            }
            if visual.look != look || !visual.walking {
                visual.look = look
                visual.walking = true
                Self.animate(visual.node, look: look)
            }
            if visual.target != target {
                let step = min(0.25, max(0.03, now - visual.movedAt))
                visual.node.glide(to: target, duration: step)
                visual.target = target
                visual.movedAt = now
            }
            carrierVisuals[carrier.id] = visual
        }
    }

    /// The carrier's own frames, or the walker's while carrier art is missing, each with its own key.
    private static func animate(_ node: SKSpriteNode, look: CarrierLook, moving: Bool = true) {
        if look.vehicle == .handcart, let frames = SpriteAtlas.frames(for: .handcart(look.facing)) {
            node.anchorPoint = SpriteAtlas.handcartAnchor
            node.playWalkCycle(.handcart(look.facing), frames: frames, moving: moving)
            return
        }
        node.anchorPoint = SpriteAtlas.walkerAnchor
        let own = SpriteAnimation.AnimationKey.carrier(look.load, look.facing)
        if let frames = SpriteAtlas.frames(for: own) {
            node.playWalkCycle(own, frames: frames, moving: moving)
        } else {
            node.playWalkCycle(.walker(look.facing), frames: SpriteAtlas.walkerAnimation(facing: look.facing), moving: moving)
        }
    }

    /// Facing from the next path segment.
    static func facing(of carrier: Carrier) -> SpriteAtlas.WalkerFacing {
        let idx = carrier.pathIndex
        guard idx >= 0, idx < carrier.path.count - 1 else { return .se }
        let from = carrier.path[idx], next = carrier.path[idx + 1]
        return SpriteAtlas.WalkerFacing(stepX: Double(next.x - from.x), stepY: Double(next.y - from.y))
    }

    /// Slightly below the tile centre, so the figure stands on the tile.
    static func position(of carrier: Carrier) -> CGPoint {
        guard let current = carrier.currentTile else { return .zero }
        let base = IsoMath.screenPoint(forTile: current)
        return CGPoint(x: base.x, y: base.y - IsoMath.tileHeight / 2)
    }
}
