import CityCore
import CoreGraphics
import Foundation
import SpriteKit

/// Residents milling about the town center plaza. Drawn from the
/// snapshot, never simulated. Spec: `rendering-2_5d` / Residents gather
/// on the plaza.
public enum PlazaCrowdPlanner {
    public struct Figure: Hashable, Sendable {
        public let townCenter: EntityID
        public let slot: Int
        /// Position in fractional tile coordinates.
        public let col: Double
        public let row: Double
        public let walking: Bool
        public let facing: SpriteAtlas.WalkerFacing
    }

    static let maxPerPlaza = 8
    static let residentsPerFigure: UInt32 = 3
    static let reach = 12
    static let minZoom = 0.5
    static let ticksPerVisit: UInt64 = 60
    static let walkTicks: UInt64 = 20
    /// The plaza, in footprint-local coordinates from the back corner:
    /// the front of the 3×3 footprint, clear of the hall and tower.
    static let plazaU = 0.3 ... 2.8
    static let plazaV = 1.5 ... 2.85

    public static func figures(
        in snapshot: WorldSnapshot,
        xRange: ClosedRange<Int>,
        yRange: ClosedRange<Int>,
        reduceMotion: Bool
    ) -> [Figure] {
        guard StrollerPlanner.residentsOut(atTick: snapshot.tickCount), snapshot.camera.zoom >= minZoom else { return [] }
        let centers = snapshot.buildings.values.filter {
            $0.kind == .townCenter && $0.state == .operational
                && xRange.contains($0.anchor.x) && yRange.contains($0.anchor.y)
        }
        guard !centers.isEmpty else { return [] }
        let houses = snapshot.housePopulations.compactMap { id, pop in
            snapshot.buildings[id].map { (anchor: $0.anchor, residents: pop.population) }
        }
        var result: [Figure] = []
        for center in centers.sorted(by: { $0.id.raw < $1.id.raw }) {
            let residents = houses.reduce(UInt32(0)) { sum, house in
                let near = max(abs(house.anchor.x - center.anchor.x), abs(house.anchor.y - center.anchor.y)) <= reach
                return near ? sum &+ house.residents : sum
            }
            let count = min(maxPerPlaza, Int(residents / residentsPerFigure))
            for slot in 0 ..< count {
                result.append(figure(center: center, slot: slot, tick: snapshot.tickCount, reduceMotion: reduceMotion))
            }
        }
        return result
    }

    static func figure(center: Building, slot: Int, tick: UInt64, reduceMotion: Bool) -> Figure {
        let stagger = UInt64(slot) * ticksPerVisit / UInt64(maxPerPlaza) + UInt64(center.id.raw) * 13
        let clock = reduceMotion ? 0 : tick &+ stagger
        let visit = clock / ticksPerVisit
        let into = clock % ticksPerVisit
        let target = spot(center: center.id, slot: slot, visit: visit)
        let previous = visit == 0 ? target : spot(center: center.id, slot: slot, visit: visit - 1)
        let progress = min(1, Double(into) / Double(walkTicks))
        let localU = previous.u + (target.u - previous.u) * progress
        let localV = previous.v + (target.v - previous.v) * progress
        return Figure(
            townCenter: center.id,
            slot: slot,
            col: Double(center.anchor.x) - 0.5 + localU,
            row: Double(center.anchor.y) - 0.5 + localV,
            walking: progress < 1 && previous != target,
            facing: SpriteAtlas.WalkerFacing(stepX: target.u - previous.u, stepY: target.v - previous.v)
        )
    }

    /// A spot on the plaza for one visit, from a hash of its inputs.
    static func spot(center: EntityID, slot: Int, visit: UInt64) -> (u: Double, v: Double) {
        let seed = UInt64(center.raw) &* 0x9E37_79B9_7F4A_7C15 ^ UInt64(slot) &* 0xBF58_476D_1CE4_E5B9 ^ visit
        var rng = DeterministicRNG(seed: seed)
        let bits = rng.next()
        let unitU = Double(bits & 0xFFFF) / Double(0xFFFF)
        let unitV = Double((bits >> 16) & 0xFFFF) / Double(0xFFFF)
        return (
            plazaU.lowerBound + unitU * (plazaU.upperBound - plazaU.lowerBound),
            plazaV.lowerBound + unitV * (plazaV.upperBound - plazaV.lowerBound)
        )
    }

    /// Muted cloth tints, one per figure.
    static let tints: [SKColor] = [
        SKColor(red: 0.45, green: 0.32, blue: 0.20, alpha: 1),
        SKColor(red: 0.30, green: 0.38, blue: 0.48, alpha: 1),
        SKColor(red: 0.42, green: 0.45, blue: 0.28, alpha: 1),
        SKColor(red: 0.55, green: 0.50, blue: 0.42, alpha: 1),
        SKColor(red: 0.50, green: 0.25, blue: 0.22, alpha: 1)
    ]

    static func tint(center: EntityID, slot: Int) -> SKColor {
        var rng = DeterministicRNG(seed: UInt64(center.raw) << 8 | UInt64(slot))
        return tints[Int(rng.next() % UInt64(tints.count))]
    }
}

struct PlazaFigureKey: Hashable {
    let townCenter: EntityID
    let slot: Int
}

struct PlazaPose: Equatable {
    let walking: Bool
    let facing: SpriteAtlas.WalkerFacing
}

struct PlazaPass: Equatable {
    let tick: UInt64
    let xRange: ClosedRange<Int>?
    let yRange: ClosedRange<Int>?
    let shown: Bool
    let reduceMotion: Bool
}

extension IsoWorldScene {
    /// Re-plans the plaza crowd when the tick, the visible tiles, the
    /// zoom threshold or Reduce Motion change.
    func reconcilePlazaCrowd(with snapshot: WorldSnapshot) {
        let range = Culling.visibleTileRange(
            camera: snapshot.camera, viewSize: size, mapWidth: snapshot.mapWidth, mapHeight: snapshot.mapHeight
        )
        let pass = PlazaPass(
            tick: snapshot.tickCount, xRange: range?.xRange, yRange: range?.yRange,
            shown: snapshot.camera.zoom >= PlazaCrowdPlanner.minZoom, reduceMotion: reduceMotion
        )
        guard pass != lastPlazaPass else { return }
        lastPlazaPass = pass
        let figures = range.map {
            PlazaCrowdPlanner.figures(in: snapshot, xRange: $0.xRange, yRange: $0.yRange, reduceMotion: reduceMotion)
        } ?? []
        let keys = Set(figures.map { PlazaFigureKey(townCenter: $0.townCenter, slot: $0.slot) })
        for (key, figure) in plazaNodes where !keys.contains(key) {
            figure.node.removeFromParent()
            plazaNodes.removeValue(forKey: key)
        }
        for figure in figures {
            let key = PlazaFigureKey(townCenter: figure.townCenter, slot: figure.slot)
            let target = IsoMath.screenPoint(forTileFractionalX: figure.col, fractionalY: figure.row)
            let pose = PlazaPose(walking: figure.walking, facing: figure.facing)
            if var shown = plazaNodes[key] {
                if shown.node.position != target { shown.node.glide(to: target) }
                if shown.pose != pose {
                    shown.pose = pose
                    Self.apply(pose, to: shown.node)
                    plazaNodes[key] = shown
                }
                continue
            }
            let node = SKSpriteNode()
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            node.zPosition = 50
            node.color = PlazaCrowdPlanner.tint(center: figure.townCenter, slot: figure.slot)
            node.colorBlendFactor = 0.35
            node.position = target
            Self.apply(pose, to: node)
            addChild(node)
            plazaNodes[key] = (node, pose)
        }
    }

    /// Walk frames while moving, frame 0 while standing. The frames come
    /// from `SpriteAtlas.walkerAnimation`, the one walker lookup, so
    /// redrawn walkers show up here unchanged.
    private static func apply(_ pose: PlazaPose, to node: SKSpriteNode) {
        node.removeAction(forKey: "walk")
        guard let frames = SpriteAtlas.walkerAnimation(facing: pose.facing), let first = frames.first else { return }
        node.texture = first
        node.size = first.size()
        if pose.walking, frames.count > 1 {
            let perFrame = SpriteAnimation.entry(for: .walker(pose.facing))?.timePerFrame ?? 0.15
            node.run(.repeatForever(.animate(with: frames, timePerFrame: perFrame)), withKey: "walk")
        }
    }
}
