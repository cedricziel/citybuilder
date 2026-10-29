import CityCore
import CoreGraphics
import SpriteKit

/// Smoke and steam over the town, from a pooled set of emitters. Spec:
/// `rendering-2_5d` / Chimneys smoke, Ambient effects stay in budget.
final class AmbientLayerNode: SKNode {
    private var plumes: [EntityID: (emitter: SKEmitterNode, style: SmokeStyle)] = [:]
    private var pool: [SKEmitterNode] = []
    private var reduceMotion = false

    override init() {
        super.init()
        // Over the buildings (10 + depth / 100), under carriers and the night shade.
        zPosition = 40
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var emitterCount: Int {
        plumes.count
    }

    func emitter(for id: EntityID) -> SKEmitterNode? {
        plumes[id]?.emitter
    }

    /// Shows one plume per source at its scene position and pools the rest.
    func show(_ placed: [(SmokeSource, CGPoint)], reduceMotion: Bool) {
        if reduceMotion != self.reduceMotion {
            self.reduceMotion = reduceMotion
            for plume in plumes.values {
                Self.configure(plume.emitter, style: plume.style, reduceMotion: reduceMotion)
            }
        }
        let wanted = Set(placed.map(\.0.id))
        for (id, plume) in plumes where !wanted.contains(id) {
            fadeOut(plume.emitter)
            plumes.removeValue(forKey: id)
        }
        for (source, point) in placed {
            if let plume = plumes[source.id] {
                if plume.style != source.style {
                    Self.configure(plume.emitter, style: source.style, reduceMotion: reduceMotion)
                    plumes[source.id] = (plume.emitter, source.style)
                }
                plume.emitter.position = point
                continue
            }
            let emitter = pool.popLast() ?? SKEmitterNode()
            emitter.removeAction(forKey: Self.fadeKey)
            Self.configure(emitter, style: source.style, reduceMotion: reduceMotion)
            emitter.position = point
            emitter.resetSimulation()
            addChild(emitter)
            // Start with a full plume, not a first puff, when it scrolls in.
            emitter.advanceSimulationTime(TimeInterval(emitter.particleLifetime))
            plumes[source.id] = (emitter, source.style)
        }
    }

    /// Stops new puffs and lets the last ones rise and fade before the
    /// emitter goes back to the pool.
    private func fadeOut(_ emitter: SKEmitterNode) {
        emitter.particleBirthRate = 0
        let linger = TimeInterval(emitter.particleLifetime + emitter.particleLifetimeRange / 2)
        emitter.run(.sequence([.wait(forDuration: linger), .run { [weak self, weak emitter] in
            if let emitter { self?.recycle(emitter) }
        }]), withKey: Self.fadeKey)
    }

    /// Takes a faded emitter off the layer and pools it.
    func recycle(_ emitter: SKEmitterNode) {
        emitter.removeFromParent()
        if pool.count < ChimneyPlanner.maxEmitters { pool.append(emitter) }
    }

    private static let fadeKey = "fade"

    private static func configure(_ emitter: SKEmitterNode, style: SmokeStyle, reduceMotion: Bool) {
        let look = PlumeLook(style)
        let motion: CGFloat = reduceMotion ? 0.5 : 1
        emitter.particleTexture = puffTexture
        emitter.particleBirthRate = look.birthRate * motion
        emitter.particleLifetime = look.lifetime
        emitter.particleLifetimeRange = look.lifetime * 0.25
        emitter.particlePositionRange = CGVector(dx: 2, dy: 1)
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = 0.35
        emitter.particleSpeed = look.speed * motion
        emitter.particleSpeedRange = look.speed * 0.3 * motion
        // A light breeze from the west.
        emitter.xAcceleration = 3 * motion
        emitter.yAcceleration = 0
        emitter.particleScale = look.scale
        emitter.particleScaleRange = look.scale * 0.3
        emitter.particleScaleSpeed = look.scale * 0.8
        emitter.particleAlpha = look.alpha
        emitter.particleAlphaRange = 0.1
        emitter.particleAlphaSpeed = -look.alpha / look.lifetime
        emitter.particleColor = SKColor(white: look.white, alpha: 1)
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .alpha
    }

    private struct PlumeLook {
        let birthRate, lifetime, speed, scale, alpha, white: CGFloat

        init(_ style: SmokeStyle) {
            switch style {
            case .smoke:
                (birthRate, lifetime, speed, scale, alpha, white) = (3, 3.2, 9, 0.28, 0.5, 0.8)
            case .heavySmoke:
                (birthRate, lifetime, speed, scale, alpha, white) = (4.5, 3.6, 10, 0.4, 0.62, 0.38)
            case .steam:
                (birthRate, lifetime, speed, scale, alpha, white) = (4, 1.8, 12, 0.3, 0.55, 0.97)
            case .fireSmoke:
                (birthRate, lifetime, speed, scale, alpha, white) = (7, 4.2, 15, 0.55, 0.7, 0.24)
            }
        }
    }

    /// A 32 px soft white disc, drawn once (design D5).
    static let puffTexture: SKTexture = {
        let size = 32, radius = CGFloat(size) / 2
        let space = CGColorSpaceCreateDeviceRGB()
        let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        guard let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
            let gradient = CGGradient(
                colorsSpace: space, colors: [white, white.copy(alpha: 0) ?? white] as CFArray, locations: [0, 1]
            )
        else { return SKTexture() }
        let centre = CGPoint(x: radius, y: radius)
        context.drawRadialGradient(gradient, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: radius, options: [])
        return context.makeImage().map { SKTexture(cgImage: $0) } ?? SKTexture()
    }()
}

extension IsoWorldScene {
    /// Re-plans smoke when the tick, the visible tiles, the budget or
    /// Reduce Motion change. Sprites sit still in the scene while the
    /// camera pans, so a pan within the same tiles needs no work.
    func reconcileAmbient(with snapshot: WorldSnapshot) {
        if ambientLayer.parent == nil { addChild(ambientLayer) }
        let range = Culling.visibleTileRange(
            camera: snapshot.camera, viewSize: size, mapWidth: snapshot.mapWidth, mapHeight: snapshot.mapHeight
        )
        let pass = AmbientPass(
            tick: snapshot.tickCount, xRange: range?.xRange, yRange: range?.yRange,
            budget: ChimneyPlanner.budget(zoom: snapshot.camera.zoom), reduceMotion: reduceMotion
        )
        guard pass != lastAmbientPass else { return }
        if lastAmbientPass?.tick != pass.tick {
            smokeSources = ChimneyPlanner.sources(in: snapshot)
        }
        lastAmbientPass = pass
        guard let (xRange, yRange) = range else {
            ambientLayer.show([], reduceMotion: reduceMotion)
            return
        }
        let chosen = ChimneyPlanner.select(smokeSources, xRange: xRange, yRange: yRange, camera: snapshot.camera)
        let placed = chosen.compactMap { source -> (SmokeSource, CGPoint)? in
            guard let node = buildingNodes[source.anchor] else { return nil }
            if source.isFire {
                // From the flames on the roof, not a chimney.
                let roof = node.size.height * StatusIcons.contentTop(of: node.texture)
                return (source, CGPoint(x: node.position.x, y: node.position.y + roof))
            }
            let stem = (node.userData?[Self.textureNameKey] as? String).map(TextureFiltering.stem(of:))
                ?? "building-\(source.kind.rawValue)"
            let offset = ChimneyAnchors.offset(stem: stem, spriteSize: node.size)
            return (source, CGPoint(x: node.position.x + offset.x, y: node.position.y + offset.y))
        }
        ambientLayer.show(placed, reduceMotion: reduceMotion)
    }
}

struct AmbientPass: Equatable {
    let tick: UInt64
    let xRange: ClosedRange<Int>?
    let yRange: ClosedRange<Int>?
    let budget: Int
    let reduceMotion: Bool
}
