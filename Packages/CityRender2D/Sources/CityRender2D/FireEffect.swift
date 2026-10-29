import CityCore
import CoreGraphics
import SpriteKit

/// A burning building: soot over its sprite, flames on its roof and a glow behind them. The smoke
/// column comes from the ambient layer (`SmokeStyle.fireSmoke`). The building's node carries it, and
/// a node is made per state, so the fire goes with the node on the tick it is out. Spec:
/// `rendering-2_5d` / Seasonal events are drawn on the map. Design canvas:
/// https://claude.ai/artifact/NfTHPHsBMu4gKzjgvxYfz5 (Fire, option A).
@MainActor
enum FireEffect {
    static let nodeName = "fire-effect"
    /// The flame cluster's base in its 80 x 64 pt cell (`effect-fire` brief).
    static let flameAnchor = CGPoint(x: 40.0 / 80.0, y: 8.0 / 64.0)
    /// How far the soot darkens the building.
    static let soot: CGFloat = 0.35

    /// The flames' scale for a footprint: a fire watch's tower gets a small cluster, a warehouse a big one.
    static func scale(for footprint: Footprint) -> CGFloat {
        0.45 + 0.3 * CGFloat(max(footprint.width, footprint.height))
    }

    /// Dresses `sprite` as burning. Under Reduce Motion the flames hold their first frame.
    static func dress(_ sprite: SKSpriteNode, footprint: Footprint, reduceMotion: Bool) {
        sprite.color = .black
        sprite.colorBlendFactor = soot
        let holder = SKNode()
        holder.name = nodeName
        // Self-lit: over the night shade (95), like lit windows and hearth glows.
        holder.zPosition = 96
        let scale = scale(for: footprint)
        // The cluster sits on the roof: its base a little under the sprite's opaque top.
        let roof = sprite.size.height * StatusIcons.contentTop(of: sprite.texture) - 14 * scale
        let glow = SKSpriteNode(texture: FireGlow.texture, size: CGSize(width: 90 * scale, height: 70 * scale))
        glow.blendMode = .add
        glow.alpha = 0.7
        glow.position = CGPoint(x: 0, y: roof + 12 * scale)
        holder.addChild(glow)
        let frames = SpriteAtlas.frames(for: .fire)
        let flames = SKSpriteNode(texture: frames?.first ?? SpriteAtlas.placeholderTexture)
        flames.anchorPoint = flameAnchor
        flames.setScale(scale)
        flames.position = CGPoint(x: 0, y: roof)
        flames.zPosition = 1
        if !reduceMotion, let flicker = SpriteAnimation.loopingAction(for: .fire) {
            flames.run(flicker)
        }
        holder.addChild(flames)
        sprite.addChild(holder)
    }
}
