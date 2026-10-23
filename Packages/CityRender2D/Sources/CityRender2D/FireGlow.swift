import CityCore
import CoreGraphics
import SpriteKit

/// A warm glow at the hearth of a working fire trade. Spec:
/// `rendering-2_5d` / Fire trades glow at night.
@MainActor
enum FireGlow {
    static let nodeName = "fire-glow"
    static let flickerKey = "flicker"

    /// Where the fire sits on each sprite, as fractions of it (x from the
    /// left, y from the top), measured on the IsoKit renders, and how wide
    /// the glow is in points.
    struct Hearth {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
    }

    static let hearths: [BuildingKind: Hearth] = [
        .bakery: Hearth(x: 0.66, y: 0.68, size: 34),
        .smelter: Hearth(x: 0.60, y: 0.80, size: 30),
        .toolsmith: Hearth(x: 0.375, y: 0.70, size: 26),
        .charcoalBurner: Hearth(x: 0.49, y: 0.72, size: 40)
    ]

    /// A 64 px warm radial gradient, drawn once.
    static let texture: SKTexture = {
        let size = 64, radius = CGFloat(size) / 2
        let space = CGColorSpaceCreateDeviceRGB()
        let warm = CGColor(red: 1, green: 0.55, blue: 0.18, alpha: 1)
        guard let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
            let gradient = CGGradient(colorsSpace: space, colors: [warm, warm.copy(alpha: 0) ?? warm] as CFArray, locations: [0, 1])
        else { return SKTexture() }
        let centre = CGPoint(x: radius, y: radius)
        context.drawRadialGradient(gradient, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: radius, options: [])
        return context.makeImage().map { SKTexture(cgImage: $0) } ?? SKTexture()
    }()

    static func make(kind: BuildingKind, on sprite: SKSpriteNode, id: EntityID, reduceMotion: Bool) -> SKNode? {
        guard let hearth = hearths[kind] else { return nil }
        let holder = SKNode()
        holder.name = nodeName
        holder.zPosition = 96 // over the night shade, like lit windows
        let glow = SKSpriteNode(texture: texture, size: CGSize(width: hearth.size, height: hearth.size * 0.7))
        glow.blendMode = .add
        glow.position = CGPoint(x: (hearth.x - 0.5) * sprite.size.width, y: (1 - hearth.y) * sprite.size.height)
        holder.addChild(glow)
        if !reduceMotion {
            // A slow, uneven flicker, its pace seeded by the building.
            var rng = DeterministicRNG(seed: UInt64(id.raw) &* 0x2545_F491_4F6C_DD1D)
            let beat = 0.35 + Double(rng.next() % 30) / 100
            glow.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.7, duration: beat),
                .fadeAlpha(to: 1, duration: beat * 0.6),
                .fadeAlpha(to: 0.85, duration: beat * 0.8),
                .fadeAlpha(to: 1, duration: beat * 0.5)
            ])), withKey: flickerKey)
        }
        return holder
    }
}

extension IsoWorldScene {
    /// Adds, updates and removes hearth glows for the working fire trades
    /// on screen. Reads the smoke sources, so it follows the smoke rule.
    func reconcileFireGlow(with snapshot: WorldSnapshot) {
        let glow = CGFloat(TimeOfDay(tick: snapshot.tickCount).darkness / TimeOfDay.nightDarkness)
        var lit: [EntityID: SKSpriteNode] = [:]
        if glow > 0 {
            for source in smokeSources where FireGlow.hearths[source.kind] != nil {
                if let node = buildingNodes[source.anchor] { lit[source.id] = node }
            }
        }
        for (id, holder) in fireGlows where lit[id] == nil || holder.parent !== lit[id] {
            holder.removeFromParent()
            fireGlows.removeValue(forKey: id)
        }
        for (id, node) in lit {
            if let holder = fireGlows[id] {
                holder.alpha = glow
                continue
            }
            guard let kind = smokeSources.first(where: { $0.id == id })?.kind,
                  let holder = FireGlow.make(kind: kind, on: node, id: id, reduceMotion: reduceMotion)
            else { continue }
            holder.alpha = glow
            node.addChild(holder)
            fireGlows[id] = holder
        }
    }
}
