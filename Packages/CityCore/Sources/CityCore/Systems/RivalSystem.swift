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
    /// Open grass a forester slot must share with a rival hut's
    /// catchment (`add-forestry` D6).
    static let foresterMinSharedGrass = 4
    /// Money other steps leave for houses until enough are lived in, and
    /// the houses a town needs before it plants foresters
    /// (`rival-ai-viability` D1, D3).
    static let houseReserve: Int64 = 150
    static let reserveUntilOccupiedHouses = 3
    static let foresterMinHouses = 4

    /// Planks a house needs.
    static var housePlanks: Int {
        BuildingCatalog.spec(for: .house).materialCost[.planks, default: 0]
    }

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

/// What a rival has on its island when its turn starts (design D5).
struct RivalTurn {
    let rival: RivalTown
    /// Buildings by kind; huts low on forest are left out.
    var counts: [BuildingKind: Int] = [:]
    /// Buildings that count toward the building cap: all but roads and
    /// foresters (`rival-ai-viability` D6).
    var cappedBuildings = 0
    /// Kinds of the rival's sites waiting for materials.
    var waiting: Set<BuildingKind> = []
    /// Forest left in the catchments of the rival's huts: the wood they
    /// can still cut.
    var forestLeft = 0
    /// Every lumberjack hut, thinned ones included.
    var allHuts = 0
    /// Houses with at least one resident.
    var occupiedHouses = 0
    /// True when one of the rival's houses went short of food.
    var hasHouseShortOfFood = false
    /// Room in the town center, where market purchases go.
    var centerFreeSpace = 0
    let stock: [Good: Int]

    /// The threshold rules that apply, in order (design D5). A town
    /// without a sawmill builds one before its planks fall below a
    /// house's worth, since a sawmill needs a plank too; the planks rule
    /// waits for the end of the opening; food and wood apply at any time.
    /// A farm per house keeps food up (`rival-ai-viability` D2, D4); huts
    /// are replaced before their last forest is cut.
    func thresholdKinds(pastOpening: Bool) -> [BuildingKind] {
        let houses = counts[.house, default: 0]
        let huts = counts[.lumberjackHut, default: 0]
        let sawmills = counts[.sawmill, default: 0]
        let planks = stock[.planks, default: 0]
        var kinds: [BuildingKind] = []
        if stock[.food, default: 0] < 4, counts[.farm, default: 0] < houses { kinds.append(.farm) }
        if sawmills == 0, allHuts > 0, planks < RivalAI.housePlanks { kinds.append(.sawmill) }
        if pastOpening, planks < 6, sawmills < huts { kinds.append(.sawmill) }
        if stock[.wood, default: 0] < 4, huts < 1 + houses / 4 || forestLeft < RivalAI.hutMinForest {
            kinds.append(.lumberjackHut)
        }
        // A thinned hut needs a forester most, so every hut counts; a
        // young town's starter grove holds its first huts' trees.
        if pastOpening, houses >= RivalAI.foresterMinHouses, counts[.forester, default: 0] < allHuts {
            kinds.append(.forester)
        }
        return kinds
    }

    /// Money a step must leave for houses: none for houses and farms,
    /// which house and feed the first residents, none for a first sawmill
    /// once planks run short of a house, and none once enough houses are
    /// lived in (`rival-ai-viability` D1).
    func reserve(before kind: BuildingKind) -> Int64 {
        let neededSawmill = kind == .sawmill && counts[.sawmill, default: 0] == 0
            && stock[.planks, default: 0] < RivalAI.housePlanks
        let exempt = kind == .house || kind == .farm || neededSawmill
        return exempt || occupiedHouses >= RivalAI.reserveUntilOccupiedHouses ? 0 : RivalAI.houseReserve
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
        if let next = rival.age.next, population(of: rival.owner) >= next.rivalResidents {
            rivals[index].age = next
            events.append(.rivalAgeAdvanced(id, next))
        }
    }

    private mutating func takeRivalStep(_ index: Int) {
        let rival = rivals[index]
        guard let center = buildings[rival.townCenterID] else { return }
        var plan = RivalTownPlan(world: self, owner: rival.owner, center: center.anchor)
        let turn = rivalTurn(rival, stock: islandStockpile(at: center.anchor, tileToIsland: plan.tileToIsland))
        if let trades = rivalMarketCommands(turn: turn) {
            pendingCommands += trades
            return
        }
        guard turn.cappedBuildings < difficulty.rivalBuildingCap else { return }
        if let commands = thresholdCommands(turn: turn, plan: &plan) {
            pendingCommands += commands
            return
        }
        guard turn.waiting.isEmpty else { return }
        let portRuleTookTurn = takeRivalPortTurn(
            index, houses: turn.counts[.house, default: 0], hasPort: turn.counts[.port, default: 0] > 0,
            tileToIsland: plan.tileToIsland
        )
        guard !portRuleTookTurn else { return }
        var ai = rival.ai
        var kind = RivalAI.scriptKind(at: ai.scriptIndex)
        // Bounded: the growth loop holds non-house steps.
        let atHouseCap = turn.counts[.house, default: 0] >= difficulty.rivalHouseCap
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
        turn.centerFreeSpace = stockpiles[rival.townCenterID]?.freeSpace ?? 0
        let hutFootprint = BuildingCatalog.spec(for: .lumberjackHut).footprint
        for building in buildings.values where building.owner == rival.owner {
            turn.cappedBuildings += building.kind == .road || building.kind == .forester ? 0 : 1
            if building.state == .constructing, building.constructionState == .waitingForMaterials {
                turn.waiting.insert(building.kind)
            }
            if building.kind == .house, let pop = populations[building.id] {
                if pop.population > 0 { turn.occupiedHouses += 1 }
                if pop.isShort(.food) { turn.hasHouseShortOfFood = true }
            }
            if building.kind == .lumberjackHut {
                turn.allHuts += 1
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
        let cost = materialCost(of: kind, for: rival.owner)
        // A step that lacks only wood or planks buys them first
        // (`rival-towns` / Rival market trades).
        guard let buys = turn.canSupply(cost) ? ([], 0) : shortfallBuys(cost, turn: turn),
              rival.treasury >= spec.cost + RivalAI.safetyMargin + buys.price,
              let slot = plan.slot(for: kind)
        else { return nil }
        let roadCost = BuildingCatalog.spec(for: .road).cost * Int64(slot.roads.count)
        let reserve = turn.reserve(before: kind)
        guard rival.treasury >= spec.cost + roadCost + RivalAI.safetyMargin + reserve + buys.price else { return nil }
        return buys.commands + slot.roads.map { .rivalPlace(rival.id, .road, at: $0) }
            + [.rivalPlace(rival.id, kind, at: slot.anchor)]
    }
}
