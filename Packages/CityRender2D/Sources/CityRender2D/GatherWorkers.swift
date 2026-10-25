import CityCore
import CoreGraphics
import SpriteKit

/// Woodcutters and miners walking out from their sites and back with a
/// load. Drawn from the snapshot, never simulated. Spec: `rendering-2_5d` /
/// Workers walk out from the gather sites.
public enum GatherWorkerPlanner {
    public struct Worker: Hashable, Sendable {
        public let site: EntityID
        /// Position in fractional tile coordinates.
        public let col: Double
        public let row: Double
        public let walking: Bool
        public let facing: SpriteAtlas.WalkerFacing
        /// What the worker carries home, or nil on the way out and at rest.
        public let load: CarrierLoad?
    }

    /// Where a worker may walk, and what it works at.
    public struct Ground {
        /// Free grass or road.
        public let isWalkable: (TileCoordinate) -> Bool
        /// Unbuilt forest (for a hut) or mountain (for a mine).
        public let terrain: (TileCoordinate) -> TerrainType?

        public init(isWalkable: @escaping (TileCoordinate) -> Bool, terrain: @escaping (TileCoordinate) -> TerrainType?) {
            self.isWalkable = isWalkable
            self.terrain = terrain
        }
    }

    static let maxWorkers = 16
    static let minZoom = 0.5
    /// How far a miner walks from the mine. A mine has no catchment; its
    /// miner works the rock as close as a woodcutter works the forest.
    static let minerReach = 2
    static let ticksPerTile: UInt64 = 8
    static let workTicks: UInt64 = 40
    static let restTicks: UInt64 = 20

    /// The workers on screen. `trips` keeps each site's current trip from
    /// call to call: a worker finishes the trip it is on, so a tree felled
    /// or planted in the catchment never makes it jump. A trip is planned
    /// again only at the rest point by the site, or when a tile on it stops
    /// being walkable; then the worker turns for home from where it stands.
    public static func workers(
        in snapshot: WorldSnapshot, visible: (x: ClosedRange<Int>, y: ClosedRange<Int>), clock: UInt64, ground: Ground,
        trips: inout [EntityID: Trip]
    ) -> [Worker] {
        guard snapshot.camera.zoom >= minZoom else { return [] }
        let (xRange, yRange) = visible
        let reach = max(BuildingKind.lumberjackHut.catchmentRadius ?? 0, minerReach)
        let onScreen = { (site: Building) in xRange.contains(site.anchor.x) && yRange.contains(site.anchor.y) }
        // Sites on screen take the budget first, then those just off it, each by id.
        let sites = snapshot.buildings.values.filter {
            ($0.kind == .lumberjackHut || $0.kind == .mine) && $0.state == .operational && $0.owner == .player
                && snapshot.buildingIssues[$0.id] == nil
                && (xRange.lowerBound - reach ... xRange.upperBound + reach).contains($0.anchor.x)
                && (yRange.lowerBound - reach ... yRange.upperBound + reach).contains($0.anchor.y)
        }
        .sorted { (onScreen($0) ? 0 : 1, $0.id.raw) < (onScreen($1) ? 0 : 1, $1.id.raw) }
        var result: [Worker] = []
        var kept: [EntityID: Trip] = [:]
        for site in sites {
            guard result.count < maxWorkers else { break }
            guard let trip = nextTrip(for: site, ground: ground, clock: clock, previous: trips[site.id]) else { continue }
            kept[site.id] = trip
            result.append(worker(site, trip: trip, clock: clock))
        }
        trips = kept
        return result
    }

    /// One round trip: the tiles out to the worked tile, and the clock it began at.
    public struct Trip: Equatable, Sendable {
        let path: [TileCoordinate]
        let start: UInt64
        /// Cut short and heading home: its last tile is wherever the worker
        /// turned, not a tree or rock.
        var homeward = false

        var walkTicks: UInt64 {
            UInt64(max(1, path.count - 1)) * ticksPerTile
        }

        var cycle: UInt64 {
            walkTicks + workTicks + walkTicks + restTicks
        }
    }

    /// The trip a site's worker is on at `clock`.
    static func nextTrip(for site: Building, ground: Ground, clock: UInt64, previous: Trip?) -> Trip? {
        guard let previous else {
            // A first trip starts somewhere along its cycle, so workers seen
            // together are not in step.
            guard let path = route(from: site, ground: ground) else { return nil }
            var rng = DeterministicRNG(seed: UInt64(site.id.raw) &* 0x94D0_49BB_1331_11EB)
            let trip = Trip(path: path, start: 0)
            return Trip(path: path, start: clock &- rng.next() % trip.cycle)
        }
        let elapsed = clock &- previous.start
        let goalStands = previous.homeward || previous.path.last.map { ground.terrain($0) == wanted(by: site) } ?? false
        guard isStandable(previous.path, site: site, ground: ground), goalStands else {
            // Something was built on the way, or the tree is gone: head home
            // from here along the tiles already walked, if they still stand.
            let here = tileIndex(on: previous, elapsed: elapsed)
            let walked = Array(previous.path[...here])
            guard isStandable(walked, site: site, ground: ground) else { return nil }
            let back = Trip(path: walked, start: 0)
            return Trip(path: walked, start: clock &- (back.walkTicks + workTicks), homeward: true)
        }
        guard elapsed >= previous.cycle else { return previous }
        // Back at the site: the next trip leaves from the same spot.
        guard let path = route(from: site, ground: ground, leavingFrom: previous.path[0]) else { return nil }
        let end = previous.start &+ previous.cycle
        let next = Trip(path: path, start: end)
        return clock &- end < next.cycle ? next : Trip(path: path, start: clock)
    }

    /// What a site's worker works at: forest for a hut, mountain for a mine.
    static func wanted(by site: Building) -> TerrainType {
        site.kind == .mine ? .mountain : .forest
    }

    /// Every tile still one a worker may stand on.
    static func isStandable(_ path: [TileCoordinate], site: Building, ground: Ground) -> Bool {
        let footprint = BuildingCatalog.spec(for: site.kind).footprint.tiles(anchor: site.anchor)
        return path.allSatisfy { !footprint.contains($0) && (ground.isWalkable($0) || ground.terrain($0) == wanted(by: site)) }
    }

    /// The path tile nearest the worker `elapsed` ticks into a trip.
    static func tileIndex(on trip: Trip, elapsed: UInt64) -> Int {
        let last = trip.path.count - 1
        let walk = trip.walkTicks
        let steps = { (ticks: UInt64) in Int((Double(ticks) / Double(ticksPerTile)).rounded()) }
        switch elapsed {
        case ..<walk: return min(last, steps(elapsed))
        case ..<(walk + workTicks): return last
        case ..<(walk + workTicks + walk): return max(0, last - steps(elapsed - walk - workTicks))
        default: return 0
        }
    }

    /// Breadth first from the tiles beside the site, over free grass, road
    /// and the site's own terrain (forest for a hut, mountain for a mine);
    /// the worked tile is one of the reachable forest or mountain tiles at
    /// the edge of the woods or rock in the catchment, picked by a hash of
    /// the site.
    /// A walk from beside the site (from `leavingFrom`, while a worker may
    /// still stand there) into its woods or rock: the tiles in order, each a
    /// 4-connected step from the one before.
    static func route(from site: Building, ground: Ground, leavingFrom: TileCoordinate? = nil) -> [TileCoordinate]? {
        let footprint = BuildingCatalog.spec(for: site.kind).footprint
        let reach = site.kind.catchmentRadius ?? minerReach
        let wanted: TerrainType = site.kind == .mine ? .mountain : .forest
        let cols = (site.anchor.x - reach) ... (site.anchor.x + footprint.width - 1 + reach)
        let rows = (site.anchor.y - reach) ... (site.anchor.y + footprint.height - 1 + reach)
        let onSite = { (tile: TileCoordinate) in
            (site.anchor.x ..< site.anchor.x + footprint.width).contains(tile.x)
                && (site.anchor.y ..< site.anchor.y + footprint.height).contains(tile.y)
        }
        let isWorkable = { (tile: TileCoordinate) in ground.terrain(tile) == wanted }
        let canStand = { (tile: TileCoordinate) in
            cols.contains(tile.x) && rows.contains(tile.y) && !onSite(tile) && (ground.isWalkable(tile) || isWorkable(tile))
        }
        let steps = [(1, 0), (0, 1), (-1, 0), (0, -1)]
        func neighbours(_ tile: TileCoordinate) -> [TileCoordinate] {
            steps.map { TileCoordinate(x: tile.x + $0.0, y: tile.y + $0.1) }
        }
        let doorstep = Array(Set(footprint.tiles(anchor: site.anchor).flatMap(neighbours).filter(canStand)))
            .sorted { ($0.y, $0.x) < ($1.y, $1.x) }
        var queue = leavingFrom.map { doorstep.contains($0) ? [$0] : doorstep } ?? doorstep
        var cameFrom: [TileCoordinate: TileCoordinate] = [:]
        var seen = Set(queue)
        var goals: [TileCoordinate] = []
        var index = 0
        while index < queue.count {
            let tile = queue[index]
            index += 1
            // At the edge of the woods or rock, where the worker can be seen.
            if isWorkable(tile), neighbours(tile).contains(where: ground.isWalkable) { goals.append(tile) }
            for next in neighbours(tile) where canStand(next) && !seen.contains(next) {
                seen.insert(next)
                cameFrom[next] = tile
                queue.append(next)
            }
        }
        guard !goals.isEmpty else { return nil }
        var rng = DeterministicRNG(seed: UInt64(site.id.raw) &* 0xBF58_476D_1CE4_E5B9)
        var path = [goals[Int(rng.next() % UInt64(goals.count))]]
        while let back = cameFrom[path[0]] {
            path.insert(back, at: 0)
        }
        return path
    }

    static func worker(_ site: Building, trip: Trip, clock: UInt64) -> Worker {
        // A site whose tree or rock is right at the door still takes a
        // short turn to carry its load in.
        let walk = trip.walkTicks
        let time = min(clock &- trip.start, trip.cycle - 1)
        let load: CarrierLoad = site.kind == .mine ? .crate : .logs
        let home = trip.path[0], far = trip.path[trip.path.count - 1]
        // Between two neighbouring tiles of the path, `ticks` into the walk.
        func along(_ ticks: UInt64, _ path: [TileCoordinate], carrying: CarrierLoad?) -> Worker {
            guard path.count > 1 else {
                return Worker(site: site.id, col: Double(path[0].x), row: Double(path[0].y), walking: false, facing: .se, load: carrying)
            }
            let step = min(Int(ticks / ticksPerTile), path.count - 2)
            let from = path[step], to = path[step + 1]
            let part = Double(ticks - UInt64(step) * ticksPerTile) / Double(ticksPerTile)
            return Worker(
                site: site.id,
                col: Double(from.x) + Double(to.x - from.x) * part, row: Double(from.y) + Double(to.y - from.y) * part,
                walking: true, facing: SpriteAtlas.WalkerFacing(stepX: Double(to.x - from.x), stepY: Double(to.y - from.y)),
                load: carrying
            )
        }
        let last = trip.path.count > 1 ? trip.path[trip.path.count - 2] : far
        let toWork = SpriteAtlas.WalkerFacing(stepX: Double(far.x - last.x), stepY: Double(far.y - last.y))
        switch time {
        case ..<walk:
            return along(time, trip.path, carrying: nil)
        case ..<(walk + workTicks):
            return Worker(site: site.id, col: Double(far.x), row: Double(far.y), walking: false, facing: toWork, load: nil)
        case ..<(walk + workTicks + walk):
            return along(time - walk - workTicks, trip.path.reversed(), carrying: load)
        default:
            return Worker(site: site.id, col: Double(home.x), row: Double(home.y), walking: false, facing: .se, load: nil)
        }
    }
}

struct GatherPose: Equatable {
    let facing: SpriteAtlas.WalkerFacing
    let load: CarrierLoad?
    let moving: Bool
}

extension IsoWorldScene {
    /// Re-plans the workers once per tick, or when the view changes; at
    /// night, while paused and with Reduce Motion they hold their frame 0.
    func reconcileGatherWorkers(with snapshot: WorldSnapshot, now: TimeInterval) {
        let range = Culling.visibleTileRange(
            camera: snapshot.camera, viewSize: size, mapWidth: snapshot.mapWidth, mapHeight: snapshot.mapHeight,
            margin: Culling.screenMargin
        )
        let still = simulationIsStill(now: now) || reduceMotion || TimeOfDay(tick: snapshot.tickCount).phase == .night
        let pass = AnimalPass(
            tick: snapshot.tickCount, xRange: range?.xRange, yRange: range?.yRange,
            zoom: snapshot.camera.zoom, reduceMotion: reduceMotion
        )
        guard pass != lastGatherPass else {
            if still { holdGatherWorkers() }
            return
        }
        lastGatherPass = pass
        let ground = GatherWorkerPlanner.Ground(
            isWalkable: { self.isYard($0, in: snapshot) },
            terrain: { snapshot.occupiedTiles[$0] == nil ? snapshot.terrain(at: $0) : nil }
        )
        var workers: [GatherWorkerPlanner.Worker] = []
        if let visible = range {
            workers = GatherWorkerPlanner.workers(
                in: snapshot, visible: (visible.xRange, visible.yRange), clock: ambientClock(for: snapshot),
                ground: ground, trips: &gatherTrips
            )
        } else {
            gatherTrips = [:]
        }
        let sites = Set(workers.map(\.site))
        for (site, shown) in gatherNodes where !sites.contains(site) {
            shown.node.removeFromParent()
            gatherNodes.removeValue(forKey: site)
        }
        for worker in workers {
            let target = IsoMath.screenPoint(forTileFractionalX: worker.col, fractionalY: worker.row)
            let pose = GatherPose(facing: worker.facing, load: worker.load, moving: worker.walking && !still)
            let node = gatherNodes[worker.site]?.node ?? {
                let made = SKSpriteNode.walker()
                made.position = target
                addChild(made)
                return made
            }()
            node.glide(to: target, sortingBy: Self.figureZ(at:))
            if gatherNodes[worker.site]?.pose != pose {
                Self.apply(pose, to: node)
            }
            gatherNodes[worker.site] = (node, pose)
        }
    }

    func holdGatherWorkers() {
        for (site, shown) in gatherNodes where shown.pose.moving {
            let held = GatherPose(facing: shown.pose.facing, load: shown.pose.load, moving: false)
            Self.apply(held, to: shown.node)
            gatherNodes[site] = (shown.node, held)
        }
    }

    /// Walker frames on the way out, carrier frames on the way home.
    private static func apply(_ pose: GatherPose, to node: SKSpriteNode) {
        if let load = pose.load {
            node.playWalkCycle(
                .carrier(load, pose.facing), frames: SpriteAtlas.carrierAnimation(load: load, facing: pose.facing), moving: pose.moving
            )
        } else {
            node.playWalkCycle(.walker(pose.facing), frames: SpriteAtlas.walkerAnimation(facing: pose.facing), moving: pose.moving)
        }
    }
}
