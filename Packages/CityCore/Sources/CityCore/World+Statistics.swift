import Foundation

/// Records the season history. Spec: `statistics`. The recording reads
/// the tick's events and the world's state and writes nothing but
/// `statistics`, so the systems it observes stay as they are.
extension World {
    /// Ticks between two samples of the producers' state.
    static let statisticsSampleTicks: UInt64 = 10

    /// Runs last in the tick. The tick that completes a season counts
    /// toward it.
    mutating func runStatisticsSystem(events: [WorldEvent]) {
        for event in events {
            record(event)
        }
        recordFuelBurns()
        if tickCount.isMultiple(of: Self.statisticsSampleTicks) {
            sampleProducers()
        }
        if tickCount > 0, tickCount.isMultiple(of: CalendarState.ticksPerSeason) {
            closeStatisticsSeason()
        }
    }

    private mutating func add(_ amount: Int, to field: WritableKeyPath<GoodFlow, Int>, of good: Good) {
        statistics.current.goods[good, default: GoodFlow()][keyPath: field] += amount
    }

    /// What a player house actually drew; called where houses consume.
    mutating func recordHouseUse(of good: Good, drawn: Int, by house: Building) {
        guard house.owner == .player, drawn > 0 else { return }
        add(drawn, to: \.usedByHouses, of: good)
    }

    private mutating func record(_ event: WorldEvent) {
        switch event {
        case let .productionCycleCompleted(producer, _):
            recordCycle(of: producer)
        case let .constructionCompleted(building, kind, _):
            guard buildings[building]?.owner == .player else { return }
            for (good, amount) in BuildingCatalog.spec(for: kind).materialCost {
                add(amount, to: \.usedByConstruction, of: good)
            }
        case let .marketTraded(good, quantity, total, direction),
             let .tradeCompleted(_, good, quantity, total, direction):
            recordTrade(good, quantity, total, direction)
        case let .caravanSold(building, goods, revenue):
            guard buildings[building]?.owner == .player else { return }
            for (good, quantity) in goods {
                add(quantity, to: \.sold, of: good)
            }
            statistics.current.money.tradeIncome += revenue
        case let .taxesCollected(amount):
            statistics.current.money.tax += amount
        case let .upkeepPaid(amount):
            statistics.current.money.upkeep += amount
        default:
            break
        }
    }

    private mutating func recordCycle(of producer: EntityID) {
        guard let building = buildings[producer], building.owner == .player,
              let recipe = Self.activeRecipe(of: building)
        else { return }
        for (good, amount) in recipe.outputs {
            add(amount, to: \.made, of: good)
        }
        for (good, amount) in recipe.inputs {
            add(amount, to: \.usedByProduction, of: good)
        }
    }

    private mutating func recordTrade(_ good: Good, _ quantity: Int, _ total: Int64, _ direction: TradeDirection) {
        switch direction {
        case .sold:
            add(quantity, to: \.sold, of: good)
            statistics.current.money.tradeIncome += total
        case .bought:
            add(quantity, to: \.bought, of: good)
            statistics.current.money.tradeSpending += total
        }
    }

    /// A fuelled building burned this tick when its burn tick left it fuelled.
    private mutating func recordFuelBurns() {
        for building in buildings.values where building.owner == .player && building.state == .operational {
            guard let fuel = building.kind.fuel, building.fuelled,
                  tickCount.isMultiple(of: fuel.intervalTicks)
            else { continue }
            add(fuel.amount, to: \.usedByProduction, of: fuel.good)
        }
    }

    private mutating func sampleProducers() {
        for (building, state) in playerProducerStates() {
            var activity = statistics.current.producers[building.kind, default: ProducerActivity()]
            switch state {
            case .working: activity.working += 1
            case .waiting: activity.waiting += 1
            case let .stuck(good):
                activity.stuck += 1
                add(1, to: \.stuckSamples, of: good)
            case .blocked: activity.blocked += 1
            }
            statistics.current.producers[building.kind] = activity
        }
    }

    /// Every operational player producer and what it is doing, in entity order.
    private func playerProducerStates() -> [(Building, ProducerState)] {
        operationalProducersInEntityOrder().compactMap { building in
            guard building.owner == .player, let recipe = Self.activeRecipe(of: building) else { return nil }
            return (building, producerState(of: building, recipe: recipe))
        }
    }

    /// Player producers stopped now because their output has nowhere to
    /// go, by the good that is stuck. The same rule the history samples.
    public var stuckProducerCounts: [Good: Int] {
        var counts: [Good: Int] = [:]
        for case let (_, .stuck(good)) in playerProducerStates() {
            counts[good, default: 0] += 1
        }
        return counts
    }

    private enum ProducerState: Equatable {
        case working
        case waiting
        case stuck(Good)
        case blocked
    }

    /// Mirrors the stall order in `runProductionSystem`: missing inputs
    /// first, then an output that does not fit the producer's own
    /// stockpile, then anything else.
    private func producerState(of building: Building, recipe: ProductionRecipe) -> ProducerState {
        guard productions[building.id]?.isStalled == true else { return .working }
        let stockpile = stockpiles[building.id] ?? Stockpile(capacity: 16)
        if recipe.inputs.contains(where: { stockpile.quantity(of: $0.key) < $0.value }) {
            return .waiting
        }
        let fits = recipe.outputs.allSatisfy { stockpile.totalStored + $0.value <= stockpile.capacity }
        let stuck = Good.allCases
            .filter { recipe.outputs[$0] != nil }
            .max { stockpile.quantity(of: $0) < stockpile.quantity(of: $1) }
        guard !fits, let good = stuck else { return .blocked }
        return .stuck(good)
    }

    private mutating func closeStatisticsSeason() {
        var record = statistics.current
        record.season = Int(tickCount / CalendarState.ticksPerSeason) - 1
        record.age = age
        for store in goodsBuffers(of: .player) where store.state == .operational {
            record.storeCapacity += stockpiles[store.id]?.capacity ?? 0
            for (good, amount) in stockpiles[store.id]?.contents ?? [:] where amount > 0 {
                record.goods[good, default: GoodFlow()].stored += amount
            }
        }
        record.goods = record.goods.filter { !$0.value.isEmpty }
        record.money.balance = economy.balance
        for (id, population) in populations where population.population > 0 && owner(of: id) == .player {
            record.residents[population.tier, default: 0] += Int(population.population)
        }
        record.rivals = rivals.sorted { $0.id < $1.id }.map { rival in
            RivalStatistics(id: rival.id, residents: population(of: rival.owner), age: rival.age, treasury: rival.treasury)
        }
        statistics.close(record)
    }
}
