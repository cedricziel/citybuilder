import CityCore
import CoreGraphics
import SpriteKit

/// A burning building: soot over its sprite, a row of flames along its roof, a small flame out of a
/// window, and a glow. The smoke column comes from the ambient layer (`SmokeStyle.fireSmoke`). The
/// building's node carries it, and a node is made per state, so the fire goes with the node on the
/// tick it is out. Spec: `rendering-2_5d` / Seasonal events are drawn on the map. Design canvas:
/// https://claude.ai/artifact/NfTHPHsBMu4gKzjgvxYfz5 (Fire, option A).
@MainActor
enum FireEffect {
    static let nodeName = "fire-effect"
    static let glowName = "fire-glow"
    static let flamesName = "fire-flames"
    static let flickerKey = "flicker"
    /// The middle of the flame row in its 80 x 80 pt cell (`effect-fire` brief).
    static let flameAnchor = CGPoint(x: 40.0 / 80.0, y: 14.0 / 80.0)
    /// How far the soot darkens the building.
    static let soot: CGFloat = 0.35
    /// The window flame's size beside the roof's.
    static let windowFlameScale: CGFloat = 0.32
    /// Where the window flame licks out of the front wall, as fractions of the sprite's width and of
    /// its opaque height.
    static let windowFlameSpot = CGPoint(x: -0.16, y: 0.36)

    /// The flames' scale for a footprint: a fire watch's tower gets a small row, a warehouse a big one.
    static func scale(for footprint: Footprint) -> CGFloat {
        0.35 + 0.25 * CGFloat(max(footprint.width, footprint.height))
    }

    /// Dresses `sprite` as burning. Under Reduce Motion the flames hold their first frame.
    static func dress(_ sprite: SKSpriteNode, footprint: Footprint, reduceMotion: Bool) {
        sprite.color = .black
        sprite.colorBlendFactor = soot
        let scale = scale(for: footprint)
        let height = sprite.size.height * StatusIcons.contentTop(of: sprite.texture)
        // The row's middle sits on the ridge, a little under the sprite's opaque top.
        let ridge = CGPoint(x: 0, y: height - 22 * scale)
        let window = CGPoint(x: windowFlameSpot.x * sprite.size.width, y: windowFlameSpot.y * height)
        // The glow is light: additive and over the night shade (95), like the hearth glows.
        let glow = SKSpriteNode(texture: FireGlow.texture, size: CGSize(width: 100 * scale, height: 80 * scale))
        glow.name = glowName
        glow.blendMode = .add
        glow.alpha = 0.7
        glow.position = CGPoint(x: ridge.x, y: ridge.y + 10 * scale)
        glow.zPosition = 96
        // The flames are drawn things: they sort with their building, so a tower in front hides them.
        let holder = SKNode()
        holder.name = nodeName
        holder.zPosition = 0.001
        holder.addChild(flames(at: ridge, scale: scale))
        holder.addChild(flames(at: window, scale: scale * windowFlameScale))
        sprite.addChild(holder)
        sprite.addChild(glow)
        setMotion(of: sprite, reduceMotion: reduceMotion)
    }

    private static func flames(at point: CGPoint, scale: CGFloat) -> SKSpriteNode {
        let node = SKSpriteNode(texture: SpriteAtlas.frames(for: .fire)?.first ?? SpriteAtlas.placeholderTexture)
        node.name = flamesName
        node.anchorPoint = flameAnchor
        node.setScale(scale)
        node.position = point
        return node
    }

    /// Starts or stops the flicker of a burning sprite's flames, for a Reduce Motion change.
    static func setMotion(of sprite: SKSpriteNode, reduceMotion: Bool) {
        let first = SpriteAtlas.frames(for: .fire)?.first
        for case let flames as SKSpriteNode in sprite.childNode(withName: nodeName)?.children ?? [] {
            flames.removeAction(forKey: flickerKey)
            if let first { flames.texture = first }
            if !reduceMotion, let flicker = SpriteAnimation.loopingAction(for: .fire) {
                flames.run(flicker, withKey: flickerKey)
            }
        }
    }
}

extension IsoWorldScene {
    /// Restyles every burning building on screen after a Reduce Motion change.
    func restyleFires() {
        for sprite in buildingNodes.values where sprite.childNode(withName: FireEffect.nodeName) != nil {
            FireEffect.setMotion(of: sprite, reduceMotion: reduceMotion)
        }
    }
}
