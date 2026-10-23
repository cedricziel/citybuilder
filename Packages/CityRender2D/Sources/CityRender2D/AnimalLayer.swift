import CityCore
import CoreGraphics
import SpriteKit

typealias AnimalKey = AnimalPlanner.Key

struct AnimalPose: Equatable {
    let action: SpriteAtlas.AnimalAction
    let facing: SpriteAtlas.WalkerFacing
    let moving: Bool
}

struct AnimalPass: Equatable {
    let tick: UInt64
    let xRange: ClosedRange<Int>?
    let yRange: ClosedRange<Int>?
    let zoom: Double
    let reduceMotion: Bool
}

extension AnimalPlanner.Animal {
    /// What the sprite shows: walking or grazing for sheep and cows,
    /// pecking for hens.
    var action: SpriteAtlas.AnimalAction {
        switch kind {
        case .sheep: walking ? .sheepWalk : .sheepGraze
        case .cow: walking ? .cowWalk : .cowGraze
        case .hen: .hen
        }
    }
}

extension IsoWorldScene {
    /// Animals may stand on grass with no building, road, field, tree or
    /// rock: the same occupancy the terrain object map reads.
    func isFreeGrass(_ tile: TileCoordinate, in snapshot: WorldSnapshot) -> Bool {
        snapshot.terrain(at: tile) == .grass && snapshot.occupiedTiles[tile] == nil && objectMap?.object(at: tile) == nil
    }

    /// The clock animals and workers move by: the day clock, held where it
    /// was when Reduce Motion came on.
    func ambientClock(for snapshot: WorldSnapshot) -> UInt64 {
        let dayClock = AnimalPlanner.dayClock(tick: snapshot.tickCount)
        let clock = reduceMotion ? (animalFrozenClock ?? dayClock) : dayClock
        animalFrozenClock = reduceMotion ? clock : nil
        return clock
    }

    /// Hens may also stand on a road in front of the house.
    func isYard(_ tile: TileCoordinate, in snapshot: WorldSnapshot) -> Bool {
        if let id = snapshot.occupiedTiles[tile] { return snapshot.buildings[id]?.kind == .road }
        return isFreeGrass(tile, in: snapshot)
    }

    /// Re-plans the animals once per tick, or when the view, zoom or Reduce
    /// Motion change; at night and while paused they hold their frame 0.
    func reconcileAnimals(with snapshot: WorldSnapshot, now: TimeInterval) {
        let range = Culling.visibleTileRange(
            camera: snapshot.camera, viewSize: size, mapWidth: snapshot.mapWidth, mapHeight: snapshot.mapHeight,
            margin: Culling.screenMargin
        )
        let pass = AnimalPass(
            tick: snapshot.tickCount, xRange: range?.xRange, yRange: range?.yRange,
            zoom: snapshot.camera.zoom, reduceMotion: reduceMotion
        )
        let still = simulationIsStill(now: now) || reduceMotion || TimeOfDay(tick: snapshot.tickCount).phase == .night
        guard pass != lastAnimalPass else {
            if still { holdAnimals() }
            return
        }
        lastAnimalPass = pass
        let clock = ambientClock(for: snapshot)
        let animals = range.map { visible in
            AnimalPlanner.animals(
                in: snapshot, visible: (visible.xRange, visible.yRange), clock: clock,
                ground: AnimalPlanner.Ground(
                    isFreeGrass: { self.isFreeGrass($0, in: snapshot) }, isYard: { self.isYard($0, in: snapshot) }
                ),
                tours: &animalTours
            )
        } ?? []
        let keys = Set(animals.map { AnimalKey(home: $0.home, slot: $0.slot) })
        for (key, shown) in animalNodes where !keys.contains(key) {
            shown.node.removeFromParent()
            animalNodes.removeValue(forKey: key)
        }
        for animal in animals {
            let key = AnimalKey(home: animal.home, slot: animal.slot)
            let target = IsoMath.screenPoint(forTileFractionalX: animal.col, fractionalY: animal.row)
            let pose = AnimalPose(action: animal.action, facing: animal.facing, moving: !still)
            if var shown = animalNodes[key] {
                shown.node.glide(to: target, sortingBy: Self.figureZ(at:))
                if shown.pose != pose {
                    shown.pose = pose
                    Self.apply(pose, to: shown.node)
                    animalNodes[key] = shown
                }
                continue
            }
            let node = SKSpriteNode()
            node.position = target
            node.zPosition = Self.figureZ(at: target)
            Self.apply(pose, to: node)
            addChild(node)
            animalNodes[key] = (node, pose)
        }
    }

    func holdAnimals() {
        for (key, shown) in animalNodes where shown.pose.moving {
            let held = AnimalPose(action: shown.pose.action, facing: shown.pose.facing, moving: false)
            Self.apply(held, to: shown.node)
            animalNodes[key] = (shown.node, held)
        }
    }

    /// Frames from `SpriteAtlas.animalAnimation`, the one animal lookup,
    /// anchored at the action's feet.
    private static func apply(_ pose: AnimalPose, to node: SKSpriteNode) {
        node.anchorPoint = pose.action.anchor
        node.playWalkCycle(
            .animal(pose.action, pose.facing),
            frames: SpriteAtlas.animalAnimation(pose.action, facing: pose.facing),
            moving: pose.moving
        )
    }
}
