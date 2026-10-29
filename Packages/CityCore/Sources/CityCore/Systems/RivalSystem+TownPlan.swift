import Foundation

/// The road grid around a rival's town center: grid lines every five
/// tiles enclose 4×4 blocks with four 2×2 corner slots (design D6).
/// Block states are memoised, so one turn's searches share the work;
/// every search visits at most the 81 blocks within `radius`.
struct RivalTownPlan {
    struct Block: Hashable {
        let column: Int
        let row: Int
    }

    static let radius = 4
    static let span = 5
    private static let home = Block(column: 0, row: 0)

    /// Blocks by Chebyshev distance from the home block, then row, then
    /// column.
    private static let searchOrder: [Block] = (0 ... radius).flatMap { distance in
        (-distance ... distance).flatMap { row in
            (-distance ... distance).compactMap { column in
                max(abs(column), abs(row)) == distance ? Block(column: column, row: row) : nil
            }
        }
    }

    let world: World
    let owner: Owner
    let center: TileCoordinate
    let tileToIsland: [TileCoordinate: IslandID]
    /// The owner's hubs, built or being built: anchor and radius.
    private let hubs: [(anchor: TileCoordinate, radius: Int)]
    private var missingRings: [Block: [TileCoordinate]] = [:]
    private var openable: [Block: Bool] = [:]

    init(world: World, owner: Owner, center: TileCoordinate) {
        self.world = world
        self.owner = owner
        self.center = center
        tileToIsland = world.tileToIslandMap()
        hubs = world.buildings.values
            .filter { $0.owner == owner }
            .sorted { $0.id.raw < $1.id.raw }
            .compactMap { hub in hub.kind.hub.map { (hub.anchor, $0.radius) } }
    }

    private static func gridDistance(_ lhs: TileCoordinate, _ rhs: TileCoordinate) -> Int {
        abs(lhs.x - rhs.x) + abs(lhs.y - rhs.y)
    }

    /// Road tiles a grid detour adds to the straight distance, at most.
    static let hubReachMargin = 2

    /// True when a house at `anchor` lies within some hub's radius, by grid
    /// distance plus the detour a ring road adds (visible-distribution D11).
    func isInHubReach(_ anchor: TileCoordinate) -> Bool {
        hubs.contains { Self.gridDistance(anchor, $0.anchor) + Self.hubReachMargin <= $0.radius }
    }

    /// True when a marketplace at `anchor` would reach houses the existing
    /// hubs don't: at least half a radius from each.
    private func extendsHubReach(_ anchor: TileCoordinate) -> Bool {
        hubs.allSatisfy { Self.gridDistance(anchor, $0.anchor) >= $0.radius / 2 }
    }

    /// True when the next house would fall outside every hub's reach: no
    /// free house slot lies in reach, but one lies beyond it.
    mutating func needsMarketplace() -> Bool {
        slot(for: .house) == nil && slot(for: .house, inReach: false) != nil
    }

    /// The slot for `kind` with the ring roads to lay first: the first
    /// free one in search order, in an opened block or one next to an
    /// opened block. Lumberjack huts look further (`hutSlot`).
    /// Houses take only slots within a hub's reach, and a marketplace only
    /// one that extends it, unless `inReach` is false.
    mutating func slot(for kind: BuildingKind, inReach: Bool = true) -> (roads: [TileCoordinate], anchor: TileCoordinate)? {
        let homeOpen = isOpened(Self.home)
        guard homeOpen || canOpen(Self.home) else { return nil }
        if kind == .lumberjackHut { return hutSlot(homeOpen: homeOpen) }
        if kind == .forester { return foresterSlot(homeOpen: homeOpen) }
        let fits: (TileCoordinate) -> Bool = switch kind {
        case .house where inReach: isInHubReach
        case .marketplace: extendsHubReach
        default: { _ in true }
        }
        for block in Self.searchOrder where isOpened(block) || (touchesOpened(block) && canOpen(block)) {
            if let anchor = candidateAnchors(for: kind, in: block).first(where: { fits($0) && isFree(kind, at: $0) }) {
                return (roads(opening: [block], homeOpen: homeOpen), anchor)
            }
        }
        return nil
    }

    /// A hut goes where its catchment holds the most forest, at least
    /// `RivalAI.hutMinForest` tiles.
    private mutating func hutSlot(homeOpen: Bool) -> (roads: [TileCoordinate], anchor: TileCoordinate)? {
        let world = world
        return bestSlot(for: .lumberjackHut, homeOpen: homeOpen) { anchor in
            let forest = world.forestTiles(inCatchmentOf: .lumberjackHut, at: anchor)
            return forest >= RivalAI.hutMinForest ? forest : nil
        }
    }

    /// A forester goes where its catchment shares the most open grass
    /// with the catchment of one of the rival's huts, at least
    /// `RivalAI.foresterMinSharedGrass`, searched like a hut's slot
    /// (`add-forestry` D6).
    private mutating func foresterSlot(homeOpen: Bool) -> (roads: [TileCoordinate], anchor: TileCoordinate)? {
        let footprint = BuildingCatalog.spec(for: .forester).footprint
        let world = world
        let isOpen = world.openGrass(for: owner, tileToIsland: tileToIsland)
        var hutGrass: [Set<TileCoordinate>] = []
        for hut in world.buildings.values where hut.owner == owner && hut.kind == .lumberjackHut {
            var grass = Set<TileCoordinate>()
            world.visitCatchment(of: hut.kind, anchor: hut.anchor, where: isOpen) { tile in
                grass.insert(tile)
                return true
            }
            if grass.count >= RivalAI.foresterMinSharedGrass { hutGrass.append(grass) }
        }
        let anyHutGrass = hutGrass.reduce(into: Set<TileCoordinate>()) { $0.formUnion($1) }
        guard !anyHutGrass.isEmpty else { return nil }
        return bestSlot(for: .forester, homeOpen: homeOpen) { anchor in
            let columns = anchor.x ..< anchor.x + footprint.width, rows = anchor.y ..< anchor.y + footprint.height
            var shared = [Int](repeating: 0, count: hutGrass.count)
            world.visitCatchment(of: .forester, anchor: anchor, where: anyHutGrass.contains) { tile in
                guard !(columns.contains(tile.x) && rows.contains(tile.y)) else { return true }
                for (index, grass) in hutGrass.enumerated() where grass.contains(tile) {
                    shared[index] += 1
                }
                return true
            }
            let best = shared.max() ?? 0
            return best >= RivalAI.foresterMinSharedGrass ? best : nil
        }
    }

    /// The free slot with the best `value` (nil when unfit), among the
    /// blocks reachable through at most `RivalAI.hutReach` unopened
    /// blocks, opening the blocks on the way; each opened block costs
    /// `RivalAI.forestPerOpenedBlock` of value. Earlier in breadth-first
    /// order wins a tie. Visits each block of the plan at most once.
    private mutating func bestSlot(
        for kind: BuildingKind, homeOpen: Bool, value: (TileCoordinate) -> Int?
    ) -> (roads: [TileCoordinate], anchor: TileCoordinate)? {
        var depth: [Block: Int] = [Self.home: 0]
        var parent: [Block: Block] = [:]
        var queue = [Self.home]
        var cursor = 0
        var best: (block: Block, anchor: TileCoordinate)?
        var bestScore = Int.min
        while cursor < queue.count {
            let block = queue[cursor]
            cursor += 1
            let blockDepth = depth[block] ?? 0
            for anchor in candidateAnchors(for: kind, in: block) where isFree(kind, at: anchor) {
                guard let value = value(anchor) else { continue }
                let score = value - RivalAI.forestPerOpenedBlock * blockDepth
                if score > bestScore {
                    best = (block, anchor)
                    bestScore = score
                }
            }
            for next in Self.neighbours(of: block) where depth[next] == nil {
                let opened = isOpened(next)
                let nextDepth = blockDepth + (opened ? 0 : 1)
                guard nextDepth <= RivalAI.hutReach, opened || canOpen(next) else { continue }
                depth[next] = nextDepth
                parent[next] = block
                queue.append(next)
            }
        }
        guard let best else { return nil }
        var path: [Block] = []
        var step = best.block
        while step != Self.home, let previous = parent[step] {
            path.insert(step, at: 0)
            step = previous
        }
        return (roads(opening: path, homeOpen: homeOpen), best.anchor)
    }

    private static func neighbours(of block: Block) -> [Block] {
        [(0, -1), (-1, 0), (1, 0), (0, 1)].compactMap { dx, dy in
            let next = Block(column: block.column + dx, row: block.row + dy)
            return max(abs(next.column), abs(next.row)) <= radius ? next : nil
        }
    }

    /// Missing ring roads: the home block's first while it is unopened,
    /// then each block's in order, each ring row-major, each tile once.
    private mutating func roads(opening blocks: [Block], homeOpen: Bool) -> [TileCoordinate] {
        var roads = homeOpen ? [] : missingRing(Self.home)
        for block in blocks {
            for tile in missingRing(block) where !roads.contains(tile) {
                roads.append(tile)
            }
        }
        return roads
    }

    private func origin(of block: Block) -> TileCoordinate {
        TileCoordinate(x: center.x + Self.span * block.column, y: center.y + Self.span * block.row)
    }

    /// The block's missing ring road tiles, row-major.
    private mutating func missingRing(_ block: Block) -> [TileCoordinate] {
        if let known = missingRings[block] { return known }
        let corner = origin(of: block)
        let last = Self.span - 1
        var tiles: [TileCoordinate] = []
        for dy in -1 ... last {
            for dx in -1 ... last where dy == -1 || dy == last || dx == -1 || dx == last {
                let tile = TileCoordinate(x: corner.x + dx, y: corner.y + dy)
                if !world.roadGraph.roadTiles.contains(tile) { tiles.append(tile) }
            }
        }
        missingRings[block] = tiles
        return tiles
    }

    private mutating func isOpened(_ block: Block) -> Bool {
        missingRing(block).isEmpty
    }

    private mutating func canOpen(_ block: Block) -> Bool {
        if let known = openable[block] { return known }
        let result = missingRing(block).allSatisfy { isFree(.road, at: $0) }
        openable[block] = result
        return result
    }

    /// The home block counts as opened: the batch opens it first.
    private mutating func touchesOpened(_ block: Block) -> Bool {
        [(1, 0), (-1, 0), (0, 1), (0, -1)].contains { dx, dy in
            let neighbour = Block(column: block.column + dx, row: block.row + dy)
            return neighbour == Self.home || isOpened(neighbour)
        }
    }

    /// The block's slots in slot order; a 3×3 kind takes the whole
    /// block, so it needs it empty.
    private func candidateAnchors(for kind: BuildingKind, in block: Block) -> [TileCoordinate] {
        let corner = origin(of: block)
        guard BuildingCatalog.spec(for: kind).footprint.width <= 2 else {
            let empty = !Footprint(width: 4, height: 4).tiles(anchor: corner).contains { world.occupiedTiles[$0] != nil }
            return empty ? [corner] : []
        }
        return [(0, 0), (2, 0), (0, 2), (2, 2)].map { TileCoordinate(x: corner.x + $0.0, y: corner.y + $0.1) }
    }

    /// Materials are checked once per step, so only the site counts.
    private func isFree(_ kind: BuildingKind, at anchor: TileCoordinate) -> Bool {
        world.siteRejection(kind, at: anchor, for: owner, tileToIsland: tileToIsland) == nil
    }
}
