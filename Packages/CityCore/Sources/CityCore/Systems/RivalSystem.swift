import Foundation

/// The rival AI: a rule-based builder that issues `rivalPlace` commands
/// through the command queue. Reads only world state and never touches
/// the world RNG. Spec: `rival-towns` (design D4–D6, D8).
enum RivalAI {
    static let opening: [BuildingKind] = [
        .lumberjackHut, .sawmill, .farm, .house, .lumberjackHut, .house,
        .house, .farm, .house, .house, .lumberjackHut, .warehouse
    ]
    static let growthLoop: [BuildingKind] = [.house, .house, .farm, .house, .house, .lumberjackHut, .house, .sawmill]
    static let houseCap = 30
    static let buildingCap = 50
    static let waitLimit = 10
    static let safetyMargin: Int64 = 50
    /// A hut with fewer forest tiles left stops counting, so the wood
    /// rule replaces it while it still yields.
    static let hutLowForest = 4
    /// Forest tiles a new hut's catchment needs.
    static let hutMinForest = 6
    /// Unopened blocks a hut step may open on its way to forest, and the
    /// forest tiles each must add to be worth its roads.
    static let hutReach = 1
    static let forestPerOpenedBlock = 8

    static func scriptKind(at index: Int) -> BuildingKind {
        index < opening.count ? opening[index] : growthLoop[(index - opening.count) % growthLoop.count]
    }
}

extension RivalAIState {
    var isPastOpening: Bool {
        scriptIndex >= RivalAI.opening.count
    }

    /// Next script step; the growth loop wraps back to its start.
    mutating func advance() {
        scriptIndex += 1
        if scriptIndex >= RivalAI.opening.count + RivalAI.growthLoop.count {
            scriptIndex = RivalAI.opening.count
        }
    }
}

extension Age {
    /// Residents a rival needs to enter this age (design D8).
    var rivalResidentThreshold: Int {
        switch self {
        case .antiquity: 0
        case .medieval: 24
        case .renaissance: 60
        case .industrial: 108
        case .modern: 150
        }
    }
}

/// What a rival has on its island when its turn starts (design D5).
private struct RivalTurn {
    let rival: RivalTown
    /// Buildings by kind; huts low on forest are left out.
    var counts: [BuildingKind: Int] = [:]
    var nonRoad = 0
    /// Kinds of the rival's sites waiting for materials.
    var waiting: Set<BuildingKind> = []
    /// Forest left in the catchments of the rival's huts: the wood they
    /// can still cut.
    var forestLeft = 0
    let stock: [Good: Int]

    /// The threshold rules that apply, in order (design D5). The planks
    /// rule waits for the end of the opening; food and wood apply at any
    /// time. A peasant house eats about what one farm grows, so farms
    /// keep pace with four in five houses; huts are replaced before their
    /// last forest is cut.
    func thresholdKinds(pastOpening: Bool) -> [BuildingKind] {
        let houses = counts[.house, default: 0]
        let huts = counts[.lumberjackHut, default: 0]
        var kinds: [BuildingKind] = []
        if stock[.food, default: 0] < 4, counts[.farm, default: 0] < (houses * 4 + 4) / 5 { kinds.append(.farm) }
        if pastOpening, stock[.planks, default: 0] < 6, counts[.sawmill, default: 0] < huts { kinds.append(.sawmill) }
        if stock[.wood, default: 0] < 4, huts < 1 + houses / 4 || forestLeft < RivalAI.hutMinForest {
            kinds.append(.lumberjackHut)
        }
        return kinds
    }

    /// True when the stock covers `cost`, or the rival's own huts and
    /// sawmill can still deliver the rest to a waiting site, so a site
    /// never waits for wood nobody will cut.
    func canSupply(_ cost: [Good: Int]) -> Bool {
        let wood = stock[.wood, default: 0] + forestLeft
        let planks = stock[.planks, default: 0]
        return cost.allSatisfy { good, amount in
            switch good {
            case .wood: wood >= amount
            case .planks: planks >= amount || (counts[.sawmill, default: 0] > 0 && planks + wood >= amount)
            default: stock[good, default: 0] >= amount
            }
        }
    }
}

extension World {
    /// Rivals take turns on staggered ticks, in ID order (design D4).
    mutating func runRivalSystem(events: inout [WorldEvent]) {
        let interval = difficulty.rivalTurnTicks
        for id in rivals.map(\.id) where tickCount % interval == UInt64(id) - 1 {
            runRivalTurn(id, events: &events)
        }
    }

    /// One step, then the age check (design D5, D8).
    mutating func runRivalTurn(_ id: RivalID, events: inout [WorldEvent]) {
        guard let index = rivalIndex(id) else { return }
        takeRivalStep(index)
        let rival = rivals[index]
        if let next = rival.age.next, population(of: rival.owner) >= next.rivalResidentThreshold {
            rivals[index].age = next
            events.append(.rivalAgeAdvanced(id, next))
        }
    }

    private mutating func takeRivalStep(_ index: Int) {
        let rival = rivals[index]
        guard let center = buildings[rival.townCenterID] else { return }
        var plan = RivalTownPlan(world: self, owner: rival.owner, center: center.anchor)
        let turn = rivalTurn(rival, stock: islandStockpile(at: center.anchor, tileToIsland: plan.tileToIsland))
        guard turn.nonRoad < RivalAI.buildingCap else { return }
        if let commands = thresholdCommands(turn: turn, plan: &plan) {
            pendingCommands += commands
            return
        }
        guard turn.waiting.isEmpty else { return }
        let portRuleTookTurn = takeRivalPortTurn(
            index, houses: turn.counts[.house, default: 0], hasPort: turn.counts[.port, default: 0] > 0,
            stock: turn.stock, tileToIsland: plan.tileToIsland
        )
        guard !portRuleTookTurn else { return }
        var ai = rival.ai
        var kind = RivalAI.scriptKind(at: ai.scriptIndex)
        // Bounded: the growth loop holds non-house steps.
        let atHouseCap = turn.counts[.house, default: 0] >= RivalAI.houseCap
        for _ in RivalAI.growthLoop.indices where kind == .house && atHouseCap {
            ai.advance()
            kind = RivalAI.scriptKind(at: ai.scriptIndex)
        }
        if let commands = rivalCommands(kind, turn: turn, plan: &plan) {
            pendingCommands += commands
            ai.advance()
            ai.waitTurns = 0
        } else {
            ai.waitTurns += 1
            if ai.waitTurns >= RivalAI.waitLimit {
                ai.advance()
                ai.waitTurns = 0
            }
        }
        rivals[index].ai = ai
    }

    /// The first threshold rule the rival can carry out wins; threshold
    /// rules never move the script, and when none can be carried out the
    /// script step comes. While a site waits for materials, only a hut
    /// may join it, so wood keeps coming.
    private func thresholdCommands(turn: RivalTurn, plan: inout RivalTownPlan) -> [Command]? {
        for kind in turn.thresholdKinds(pastOpening: turn.rival.ai.isPastOpening) {
            guard turn.waiting.isEmpty || (kind == .lumberjackHut && !turn.waiting.contains(kind)) else { continue }
            if let commands = rivalCommands(kind, turn: turn, plan: &plan) { return commands }
        }
        return nil
    }

    private func rivalTurn(_ rival: RivalTown, stock: [Good: Int]) -> RivalTurn {
        var turn = RivalTurn(rival: rival, stock: stock)
        let hutFootprint = BuildingCatalog.spec(for: .lumberjackHut).footprint
        for building in buildings.values where building.owner == rival.owner {
            turn.nonRoad += building.kind == .road ? 0 : 1
            if building.state == .constructing, building.constructionState == .waitingForMaterials {
                turn.waiting.insert(building.kind)
            }
            if building.kind == .lumberjackHut {
                let forest = forestTiles(inCatchmentOf: building.anchor, footprint: hutFootprint)
                turn.forestLeft += forest
                guard forest >= RivalAI.hutLowForest else { continue }
            }
            turn.counts[building.kind, default: 0] += 1
        }
        return turn
    }

    /// The batch for one step, or nil when the rival must wait: missing
    /// materials, not enough money, or no slot (design D5, D6).
    private func rivalCommands(_ kind: BuildingKind, turn: RivalTurn, plan: inout RivalTownPlan) -> [Command]? {
        let spec = BuildingCatalog.spec(for: kind)
        let rival = turn.rival
        guard turn.canSupply(materialCost(of: kind, for: rival.owner)),
              rival.treasury >= spec.cost + RivalAI.safetyMargin,
              let slot = plan.slot(for: kind)
        else { return nil }
        let roadCost = BuildingCatalog.spec(for: .road).cost * Int64(slot.roads.count)
        guard rival.treasury >= spec.cost + roadCost + RivalAI.safetyMargin else { return nil }
        return slot.roads.map { .rivalPlace(rival.id, .road, at: $0) } + [.rivalPlace(rival.id, kind, at: slot.anchor)]
    }
}

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
    private var missingRings: [Block: [TileCoordinate]] = [:]
    private var openable: [Block: Bool] = [:]

    init(world: World, owner: Owner, center: TileCoordinate) {
        self.world = world
        self.owner = owner
        self.center = center
        tileToIsland = world.tileToIslandMap()
    }

    /// The slot for `kind` with the ring roads to lay first: the first
    /// free one in search order, in an opened block or one next to an
    /// opened block. Lumberjack huts look further (`hutSlot`).
    mutating func slot(for kind: BuildingKind) -> (roads: [TileCoordinate], anchor: TileCoordinate)? {
        let homeOpen = isOpened(Self.home)
        guard homeOpen || canOpen(Self.home) else { return nil }
        if kind == .lumberjackHut { return hutSlot(homeOpen: homeOpen) }
        for block in Self.searchOrder where isOpened(block) || (touchesOpened(block) && canOpen(block)) {
            if let anchor = candidateAnchors(for: kind, in: block).first(where: { isFree(kind, at: $0) }) {
                return (roads(opening: [block], homeOpen: homeOpen), anchor)
            }
        }
        return nil
    }

    /// A hut goes where its catchment holds the most forest, among the
    /// blocks reachable through at most `RivalAI.hutReach` unopened
    /// blocks, opening the blocks on the way; each opened block must pay
    /// for its roads with `RivalAI.forestPerOpenedBlock` more forest.
    /// Earlier in breadth-first order wins a tie. Visits each block of
    /// the plan at most once.
    private mutating func hutSlot(homeOpen: Bool) -> (roads: [TileCoordinate], anchor: TileCoordinate)? {
        let footprint = BuildingCatalog.spec(for: .lumberjackHut).footprint
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
            for anchor in candidateAnchors(for: .lumberjackHut, in: block) where isFree(.lumberjackHut, at: anchor) {
                let forest = world.forestTiles(inCatchmentOf: anchor, footprint: footprint)
                let score = forest - RivalAI.forestPerOpenedBlock * blockDepth
                if forest >= RivalAI.hutMinForest, score > bestScore {
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
