import CityCore
import CoreGraphics
import SpriteKit

/// Pale sawdust puffing at the saw of each working sawmill on screen, one
/// pooled emitter per mill. Drawn from the snapshot, never simulated. Spec:
/// `rendering-2_5d` / Sawdust puffs at the sawmills.
final class SawdustLayerNode: SKNode {
    static let emitterName = "sawdust"
    static let minZoom = 0.5
    static let maxMills = 8
    private(set) var emitters: [EntityID: SKEmitterNode] = [:]
    private var pool: [SKEmitterNode] = []
    private var lastPass: AnimalPass?
    private var still = false

    /// Working player sawmills: operational, with no building issue.
    static func mills(in snapshot: WorldSnapshot) -> [Building] {
        snapshot.buildings.values.filter {
            $0.kind == .sawmill && $0.state == .operational && $0.owner == .player && snapshot.buildingIssues[$0.id] == nil
        }
    }

    /// Where the saw stands: the middle of the mill's front (+y) edge.
    static func saw(of mill: Building) -> CGPoint {
        let footprint = BuildingCatalog.spec(for: mill.kind).footprint
        let point = IsoMath.screenPoint(
            forTileFractionalX: Double(mill.anchor.x) + Double(footprint.width - 1) / 2,
            fractionalY: Double(mill.anchor.y + footprint.height) - 0.5
        )
        return CGPoint(x: point.x, y: point.y + 4)
    }

    func reconcile(snapshot: WorldSnapshot, viewSize: CGSize, reduceMotion: Bool, still: Bool) {
        let range = Culling.visibleTileRange(
            camera: snapshot.camera, viewSize: viewSize, mapWidth: snapshot.mapWidth, mapHeight: snapshot.mapHeight,
            margin: Culling.screenMargin
        )
        let pass = AnimalPass(
            tick: snapshot.tickCount, xRange: range?.xRange, yRange: range?.yRange,
            zoom: snapshot.camera.zoom, reduceMotion: reduceMotion
        )
        if pass != lastPass {
            lastPass = pass
            let shown = range.flatMap { visible in
                reduceMotion || snapshot.camera.zoom < Self.minZoom ? nil : Self.mills(in: snapshot).filter {
                    visible.xRange.contains($0.anchor.x) && visible.yRange.contains($0.anchor.y)
                }
            } ?? []
            let chosen = shown.sorted { $0.id.raw < $1.id.raw }.prefix(Self.maxMills)
            show(Array(chosen))
        }
        if still != self.still {
            self.still = still
            for emitter in emitters.values {
                Self.hold(emitter, still: still)
            }
        }
    }

    private func show(_ mills: [Building]) {
        let wanted = Set(mills.map(\.id))
        for (id, emitter) in emitters where !wanted.contains(id) {
            emitter.removeFromParent()
            pool.append(emitter)
            emitters.removeValue(forKey: id)
        }
        for mill in mills where emitters[mill.id] == nil {
            let emitter = pool.popLast() ?? Self.makeEmitter()
            emitter.position = Self.saw(of: mill)
            emitter.zPosition = IsoWorldScene.figureZ(at: emitter.position)
            emitter.resetSimulation()
            emitter.particleBirthRate = Self.birthRate
            addChild(emitter)
            emitter.advanceSimulationTime(TimeInterval(emitter.particleLifetime))
            Self.hold(emitter, still: still)
            emitters[mill.id] = emitter
        }
    }

    static let birthRate: CGFloat = 5

    /// Freezes the puffs in the air, and lets none new out, while `still`.
    static func hold(_ emitter: SKEmitterNode, still: Bool) {
        emitter.isPaused = still
        emitter.particleBirthRate = still ? 0 : birthRate
    }

    /// Small pale puffs that drift out from the saw and settle.
    private static func makeEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.name = emitterName
        emitter.particleTexture = AmbientLayerNode.puffTexture
        emitter.particleBirthRate = birthRate
        emitter.particleLifetime = 1.1
        emitter.particleLifetimeRange = 0.3
        emitter.particlePositionRange = CGVector(dx: 6, dy: 2)
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = 1.2
        emitter.particleSpeed = 7
        emitter.particleSpeedRange = 3
        emitter.yAcceleration = -9
        emitter.particleScale = 0.1
        emitter.particleScaleRange = 0.04
        emitter.particleScaleSpeed = 0.05
        emitter.particleAlpha = 0.7
        emitter.particleAlphaSpeed = -0.6
        emitter.particleColor = SKColor(red: 0.93, green: 0.85, blue: 0.66, alpha: 1)
        emitter.particleColorBlendFactor = 1
        return emitter
    }
}
