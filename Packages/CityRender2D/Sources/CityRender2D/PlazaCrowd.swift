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
        /// The town center's iso depth; figures draw just above it.
        public let depth: Double
    }

    static let maxPerPlaza = 8
    static let residentsPerFigure: UInt32 = 3
    static let reach = 12
    static let minZoom = 0.5
    static let ticksPerVisit: UInt64 = 60
    static let walkTicks: UInt64 = 20

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
            let layout = PlazaLayout.layout(for: culture(of: center, in: snapshot))
            for slot in 0 ..< count {
                result.append(figure(center: center, slot: slot, layout: layout, tick: snapshot.tickCount, reduceMotion: reduceMotion))
            }
        }
        return result
    }

    /// The culture a town center is drawn in: its owner's.
    static func culture(of center: Building, in snapshot: WorldSnapshot) -> Culture {
        guard let rival = center.owner.rivalID else { return snapshot.culture }
        return snapshot.rivals.first { $0.id == rival }?.culture ?? snapshot.culture
    }

    /// Figures share their lane's schedule and take distinct spots in it
    /// (one rank apart), so no two stand on the same spot; each rank sets
    /// off a little later, so a lane never moves in step.
    static func figure(center: Building, slot: Int, layout: PlazaLayout, tick: UInt64, reduceMotion: Bool) -> Figure {
        let footprint = BuildingCatalog.spec(for: center.kind).footprint
        let laneIndex = slot % layout.lanes.count, rank = slot / layout.lanes.count
        let lane = layout.lanes[laneIndex]
        let stagger = UInt64(laneIndex) * ticksPerVisit / UInt64(layout.lanes.count) + UInt64(center.id.raw) * 13
        let clock = reduceMotion ? 0 : tick &+ stagger
        let visit = clock / ticksPerVisit
        let into = Double(clock % ticksPerVisit) - Double(rank * 6)
        let target = spot(in: lane, center: center.id, lane: laneIndex, rank: rank, visit: visit)
        let previous = visit == 0 ? target : spot(in: lane, center: center.id, lane: laneIndex, rank: rank, visit: visit - 1)
        let progress = min(1, max(0, into / Double(walkTicks)))
        let localU = previous.u + (target.u - previous.u) * progress
        let localV = previous.v + (target.v - previous.v) * progress
        return Figure(
            townCenter: center.id,
            slot: slot,
            col: Double(center.anchor.x) - 0.5 + localU,
            row: Double(center.anchor.y) - 0.5 + localV,
            walking: progress < 1 && previous != target,
            facing: SpriteAtlas.WalkerFacing(stepX: target.u - previous.u, stepY: target.v - previous.v),
            depth: Double(center.anchor.x + center.anchor.y) + Double(footprint.width + footprint.height) / 2
        )
    }

    /// The lane spot for one visit: a hash of the town center, lane and
    /// visit picks the lane's rotation, and the rank offsets it.
    static func spot(in lane: [PlazaLayout.Spot], center: EntityID, lane laneIndex: Int, rank: Int, visit: UInt64) -> PlazaLayout.Spot {
        let seed = UInt64(center.raw) &* 0x9E37_79B9_7F4A_7C15 ^ UInt64(laneIndex) &* 0xBF58_476D_1CE4_E5B9 ^ visit
        var rng = DeterministicRNG(seed: seed)
        return lane[(Int(rng.next() % UInt64(lane.count)) + rank) % lane.count]
    }

    /// A worker or a woman, from a hash of the town center and slot.
    static func look(center: EntityID, slot: Int) -> SpriteAtlas.WalkerLook {
        var rng = DeterministicRNG(seed: UInt64(center.raw) << 8 | UInt64(slot))
        let looks = SpriteAtlas.WalkerLook.allCases
        return looks[Int(rng.next() % UInt64(looks.count))]
    }
}

struct PlazaFigureKey: Hashable {
    let townCenter: EntityID
    let slot: Int
}

struct PlazaPose: Equatable {
    let walking: Bool
    let facing: SpriteAtlas.WalkerFacing
    let look: SpriteAtlas.WalkerLook
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
    func reconcilePlazaCrowd(with snapshot: WorldSnapshot, now: TimeInterval) {
        let range = Culling.visibleTileRange(
            camera: snapshot.camera, viewSize: size, mapWidth: snapshot.mapWidth, mapHeight: snapshot.mapHeight
        )
        let pass = PlazaPass(
            tick: snapshot.tickCount, xRange: range?.xRange, yRange: range?.yRange,
            shown: snapshot.camera.zoom >= PlazaCrowdPlanner.minZoom, reduceMotion: reduceMotion
        )
        guard pass != lastPlazaPass else {
            standStillIfPaused(now: now)
            return
        }
        if pass.tick != lastPlazaPass?.tick { plazaTickAt = now }
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
            let pose = PlazaPose(
                walking: figure.walking, facing: figure.facing,
                look: PlazaCrowdPlanner.look(center: figure.townCenter, slot: figure.slot)
            )
            if var shown = plazaNodes[key] {
                if shown.node.position != target { shown.node.glide(to: target) }
                if shown.pose != pose {
                    shown.pose = pose
                    Self.apply(pose, to: shown.node)
                    plazaNodes[key] = shown
                }
                continue
            }
            let node = SKSpriteNode.walker()
            node.zPosition = Self.depthZ(figure.depth) + Self.figureLift
            node.position = target
            Self.apply(pose, to: node)
            addChild(node)
            plazaNodes[key] = (node, pose)
        }
    }

    /// No new tick for a while means the game is paused (or the title
    /// screen is showing a still town): stop walk cycles mid-stride.
    private func standStillIfPaused(now: TimeInterval) {
        guard now - plazaTickAt > 0.3 else { return }
        for (key, shown) in plazaNodes where shown.pose.walking {
            let standing = PlazaPose(walking: false, facing: shown.pose.facing, look: shown.pose.look)
            Self.apply(standing, to: shown.node)
            plazaNodes[key] = (shown.node, standing)
        }
    }

    /// Walk frames while moving, frame 0 while standing. The frames come
    /// from `SpriteAtlas.walkerAnimation`, the one walker lookup, so
    /// redrawn walkers show up here unchanged.
    private static func apply(_ pose: PlazaPose, to node: SKSpriteNode) {
        node.playWalkCycle(
            .walker(pose.facing, pose.look),
            frames: SpriteAtlas.walkerAnimation(facing: pose.facing, look: pose.look),
            moving: pose.walking
        )
    }
}
