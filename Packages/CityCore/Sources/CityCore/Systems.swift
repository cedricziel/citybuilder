import Foundation

/// Per-tick simulation systems for production, carriers, population, and
/// economy. Each is a pure function of `(inout World) -> Void` so future
/// changes (parallelization, ordering tweaks) are easy.
extension World {
    mutating func runProductionSystem() {
        for (id, building) in buildings where building.state == .operational {
            guard let recipe = ProductionCatalog.recipe(for: building.kind) else { continue }
            var progress = productions[id] ?? ProductionProgress()
            var stockpile = stockpiles[id] ?? Stockpile(capacity: 16)

            // Stall: full output stockpile.
            let canStoreOutputs = recipe.outputs.allSatisfy { good, amount in
                stockpile.quantity(of: good) + amount <= stockpile.capacity - stockpile.totalStored + stockpile.quantity(of: good)
            }
            // Stall: missing inputs.
            let hasInputs = recipe.inputs.allSatisfy { good, amount in
                stockpile.quantity(of: good) >= amount
            }
            // Lumberjack: forest harvested from the world rather than the
            // stockpile, so we accept "no inputs needed" + grass-adjacency
            // proxy by checking adjacent forest tiles.
            let footprint = BuildingCatalog.spec(for: building.kind).footprint
            let lumberjackHasForest = building.kind == .lumberjackHut
                ? hasAdjacentForest(anchor: building.anchor, footprint: footprint)
                : true

            guard hasInputs, canStoreOutputs, lumberjackHasForest else {
                progress.isStalled = true
                productions[id] = progress
                stockpiles[id] = stockpile
                continue
            }

            progress.isStalled = false
            progress.ticksThisCycle &+= 1
            if progress.ticksThisCycle >= recipe.cycleTicks {
                // Consume inputs from stockpile.
                for (good, amount) in recipe.inputs {
                    stockpile.withdraw(good, amount: amount)
                }
                // Emit outputs.
                for (good, amount) in recipe.outputs {
                    stockpile.deposit(good, amount: amount)
                }
                // Lumberjack also clears a forest tile.
                if building.kind == .lumberjackHut {
                    clearAdjacentForest(anchor: building.anchor, footprint: footprint)
                }
                progress.ticksThisCycle = 0
            }
            productions[id] = progress
            stockpiles[id] = stockpile
        }
    }

    /// Carrier lifecycle: advance in-flight carriers along their path,
    /// deposit goods on arrival, then spawn fresh carriers from producers
    /// whose output stockpiles have something to ship.
    mutating func runCarrierSystem() {
        advanceCarriers()
        spawnCarriersFromProducers()
    }

    private mutating func advanceCarriers() {
        for (id, carrier) in carriers {
            if carrier.hasArrived {
                applyCarrierArrival(carrier)
                if case let .deliver(_, _, fromProducer, _) = carrier.mission {
                    carrierCountByProducer[fromProducer, default: 1] -= 1
                }
                carriers.removeValue(forKey: id)
            } else {
                var updated = carrier
                updated.pathIndex += 1
                carriers[id] = updated
            }
        }
    }

    private mutating func applyCarrierArrival(_ carrier: Carrier) {
        switch carrier.mission {
        case let .deliver(good, amount, _, toWarehouse):
            stockpiles[toWarehouse]?.deposit(good, amount: amount)
        case let .retrieve(good, amount, _, toConsumer):
            stockpiles[toConsumer]?.deposit(good, amount: amount)
        }
    }

    private mutating func spawnCarriersFromProducers() {
        for (producerId, building) in buildings where building.state == .operational {
            guard let recipe = ProductionCatalog.recipe(for: building.kind) else { continue }
            let inFlight = carrierCountByProducer[producerId, default: 0]
            guard inFlight < CarrierConfig.perProducerCap else { continue }
            // Pick the first output good currently in the producer's stockpile.
            guard let producerStock = stockpiles[producerId] else { continue }
            let footprint = BuildingCatalog.spec(for: building.kind).footprint
            guard let road = anyAdjacentRoad(anchor: building.anchor, footprint: footprint) else { continue }

            for (good, _) in recipe.outputs where producerStock.quantity(of: good) >= 1 {
                guard let (warehouseId, path) = findRoadConnectedWarehouse(
                    fromRoad: road,
                    good: good
                )
                else { continue }

                // Withdraw 1 unit and create the carrier.
                stockpiles[producerId]?.withdraw(good, amount: 1)
                let carrierId = EntityID(raw: nextEntityRaw)
                nextEntityRaw &+= 1
                let carrier = Carrier(
                    id: carrierId,
                    path: path,
                    mission: .deliver(good: good, amount: 1, fromProducer: producerId, toWarehouse: warehouseId)
                )
                carriers[carrierId] = carrier
                carrierCountByProducer[producerId, default: 0] += 1
                break // one carrier per producer per tick
            }
        }
    }

    /// Returns any road tile orthogonally adjacent to the footprint, or nil
    /// if the building isn't road-connected.
    private func anyAdjacentRoad(anchor: TileCoordinate, footprint: Footprint) -> TileCoordinate? {
        let occupied = Set(footprint.tiles(anchor: anchor))
        for tile in occupied {
            for neighbor in [
                TileCoordinate(x: tile.x + 1, y: tile.y),
                TileCoordinate(x: tile.x - 1, y: tile.y),
                TileCoordinate(x: tile.x, y: tile.y + 1),
                TileCoordinate(x: tile.x, y: tile.y - 1)
            ] where !occupied.contains(neighbor) && roadGraph.isConnected(neighbor) {
                return neighbor
            }
        }
        return nil
    }

    /// Find the road-connected warehouse with capacity for `good`. Returns
    /// (warehouseId, road path) on the shortest path; nil if none reachable.
    private func findRoadConnectedWarehouse(
        fromRoad start: TileCoordinate,
        good: Good
    ) -> (EntityID, [TileCoordinate])? {
        var best: (EntityID, [TileCoordinate])?
        for (id, building) in buildings where building.kind == .warehouse && building.state == .operational {
            let warehouseFootprint = BuildingCatalog.spec(for: .warehouse).footprint
            guard let warehouseRoad = anyAdjacentRoad(
                anchor: building.anchor,
                footprint: warehouseFootprint
            )
            else { continue }
            guard let stock = stockpiles[id], stock.freeSpace > 0 else { continue }
            _ = good // future: check warehouse accepts this good type
            guard let path = PathFinder.path(
                from: start,
                to: warehouseRoad,
                in: roadGraph
            )
            else { continue }
            if best == nil || path.count < best!.1.count {
                best = (id, path)
            }
        }
        return best
    }

    mutating func runEconomySystem() {
        guard !economy.gameOver else { return }
        if tickCount > 0, tickCount.isMultiple(of: Economy.taxIntervalTicks) {
            var totalPop: Int64 = 0
            for pop in populations.values {
                totalPop += Int64(pop.population)
            }
            economy.credit(totalPop * Economy.taxPerPopUnit)
        }
        if tickCount > 0, tickCount.isMultiple(of: Economy.upkeepIntervalTicks) {
            var totalUpkeep: Int64 = 0
            for building in buildings.values where building.state == .operational {
                totalUpkeep += BuildingCatalog.spec(for: building.kind).upkeep
            }
            economy.deduct(totalUpkeep)
        }
        if economy.balance < 0 {
            economy.bankruptcyDeficitTicks &+= 1
            if economy.bankruptcyDeficitTicks >= Economy.bankruptcyGraceTicks {
                economy.gameOver = true
            }
        } else {
            economy.bankruptcyDeficitTicks = 0
        }
    }

    mutating func runPopulationSystem() {
        for (id, building) in buildings where building.kind == .house && building.state == .operational {
            var pop = populations[id] ?? HousePopulation()
            let footprint = BuildingCatalog.spec(for: building.kind).footprint
            // Food need: nearest road-connected warehouse with food.
            pop.foodSatisfied = hasGoodInReach(.food, fromAnchor: building.anchor, footprint: footprint)
            // Plank upkeep: same idea — visible planks somewhere in reach.
            pop.planksSatisfied = pop.population == 0
                || hasGoodInReach(.planks, fromAnchor: building.anchor, footprint: footprint)
            // Track satisfaction streak for growth/decline.
            pop.ticksAtCurrentSatisfaction &+= 1
            let canGrow = pop.allNeedsSatisfied
                && pop.ticksAtCurrentSatisfaction >= HousePopulation.growthIntervalTicks
                && pop.population < HousePopulation.capacity
            let mustShrink = !pop.allNeedsSatisfied
                && pop.ticksAtCurrentSatisfaction >= HousePopulation.declineIntervalTicks
                && pop.population > 0
            if canGrow {
                pop.population &+= 1
                pop.ticksAtCurrentSatisfaction = 0
            } else if mustShrink {
                pop.population &-= 1
                pop.ticksAtCurrentSatisfaction = 0
            }
            populations[id] = pop
        }
    }

    /// True if any warehouse holding `good` is road-connected (any path)
    /// from `anchor`. M4 simplified: we just check road-connected
    /// warehouses, not a full path-finding query. Carriers do the rest.
    func hasGoodInReach(_ good: Good, fromAnchor anchor: TileCoordinate, footprint: Footprint) -> Bool {
        guard roadGraph.isAnchorRoadConnected(anchor, footprint: footprint) else { return false }
        for (id, building) in buildings where building.kind == .warehouse && building.state == .operational {
            let stock = stockpiles[id] ?? Stockpile(capacity: 0)
            guard stock.quantity(of: good) > 0 else { continue }
            if roadGraph.isAnchorRoadConnected(building.anchor, footprint: BuildingCatalog.spec(for: .warehouse).footprint) {
                return true
            }
        }
        return false
    }

    func hasAdjacentForest(anchor: TileCoordinate, footprint: Footprint) -> Bool {
        let occupied = Set(footprint.tiles(anchor: anchor))
        for tile in occupied {
            for neighbor in [
                TileCoordinate(x: tile.x + 1, y: tile.y),
                TileCoordinate(x: tile.x - 1, y: tile.y),
                TileCoordinate(x: tile.x, y: tile.y + 1),
                TileCoordinate(x: tile.x, y: tile.y - 1)
            ] where !occupied.contains(neighbor) {
                if terrain(at: neighbor) == .forest { return true }
            }
        }
        return false
    }

    mutating func clearAdjacentForest(anchor: TileCoordinate, footprint: Footprint) {
        let occupied = Set(footprint.tiles(anchor: anchor))
        for tile in occupied {
            for neighbor in [
                TileCoordinate(x: tile.x + 1, y: tile.y),
                TileCoordinate(x: tile.x - 1, y: tile.y),
                TileCoordinate(x: tile.x, y: tile.y + 1),
                TileCoordinate(x: tile.x, y: tile.y - 1)
            ] where !occupied.contains(neighbor) {
                if terrain(at: neighbor) == .forest {
                    terrainGrid[neighbor.y * mapWidth + neighbor.x] = .grass
                    return
                }
            }
        }
    }
}
