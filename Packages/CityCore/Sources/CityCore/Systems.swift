import Foundation

/// Per-tick simulation systems for production, carriers, population, and
/// economy. Each is a pure function of `(inout World) -> Void` so future
/// changes (parallelization, ordering tweaks) are easy.
extension World {
    static let seasonalCrops: Set<BuildingKind> = [.farm, .grainFarm]

    mutating func runProductionSystem(signatureSources: [Building], events: inout [WorldEvent]) {
        for (id, building) in buildings where building.state == .operational {
            guard let recipe = Self.activeRecipe(of: building) else { continue }
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
                ? firstForestInCatchment(anchor: building.anchor, footprint: footprint) != nil
                : true

            // Capture the prior-tick stall state so transitions emit
            // exactly once on the edge (start of stall, end of stall).
            let wasStalled = progress.isStalled

            guard hasInputs, canStoreOutputs, lumberjackHasForest else {
                progress.isStalled = true
                if !wasStalled {
                    events.append(.productionStalled(producer: id, kind: building.kind))
                }
                productions[id] = progress
                stockpiles[id] = stockpile
                continue
            }

            progress.isStalled = false
            if wasStalled {
                events.append(.productionResumed(producer: id, kind: building.kind))
            }
            // Spec: `calendar-and-events` / Winter slows crops.
            if !(isCropWinter && Self.seasonalCrops.contains(building.kind) && tickCount.isMultiple(of: 2)) {
                progress.ticksThisCycle &+= 1 + workshopBonus(for: building, sources: signatureSources)
            }
            if progress.ticksThisCycle >= recipe.cycleTicks {
                // Consume inputs from stockpile.
                for (good, amount) in recipe.inputs {
                    stockpile.withdraw(good, amount: amount)
                }
                // Emit outputs.
                for (good, amount) in recipe.outputs {
                    stockpile.deposit(good, amount: amount)
                }
                clearHarvestedForest(after: building, footprint: footprint)
                // Shipyard emits a Ship entity on cycle completion.
                // Spec: `port-and-shipyard` / Shipyard emits ship on
                // recipe completion. Persist the stockpile mutation
                // here so the emit factory does not see stale data
                // through `self.stockpiles[id]`.
                if building.kind == .shipyard {
                    stockpiles[id] = stockpile
                    _ = emitShip(fromShipyard: id)
                    // Re-fetch stockpile in case emitShip mutated it.
                    stockpile = stockpiles[id] ?? stockpile
                }
                if building.kind == .monument {
                    completeProjectStage(of: id, events: &events)
                }
                progress.ticksThisCycle = 0
                events.append(.productionCycleCompleted(producer: id, kind: building.kind))
            }
            productions[id] = progress
            stockpiles[id] = stockpile
        }
    }

    /// A lumberjack's completed cycle clears a forest tile.
    private mutating func clearHarvestedForest(after building: Building, footprint: Footprint) {
        guard building.kind == .lumberjackHut,
              let tile = firstForestInCatchment(anchor: building.anchor, footprint: footprint)
        else { return }
        terrainGrid[tile.y * mapWidth + tile.x] = .grass
    }

    /// Carrier lifecycle: advance in-flight carriers along their path,
    /// deposit goods on arrival, then spawn fresh carriers from producers
    /// whose output stockpiles have something to ship.
    mutating func runCarrierSystem(events: inout [WorldEvent]) {
        advanceCarriers(events: &events)
        let tileToIsland = tileToIslandMap()
        spawnCarriersFromProducers(tileToIsland: tileToIsland, events: &events)
        spawnSupplyCarriers(events: &events)
        spawnExportCarriers(tileToIsland: tileToIsland, events: &events)
    }

    private mutating func advanceCarriers(events: inout [WorldEvent]) {
        for (id, carrier) in carriers {
            if carrier.hasArrived {
                applyCarrierArrival(carrier, events: &events)
                switch carrier.mission {
                case let .deliver(_, _, fromProducer, _),
                     let .deliverToConstructionSite(_, _, fromProducer, _):
                    carrierCountByProducer[fromProducer, default: 1] -= 1
                case .retrieve:
                    break
                }
                carriers.removeValue(forKey: id)
            } else {
                var updated = carrier
                updated.pathIndex += 1
                carriers[id] = updated
            }
        }
    }

    private mutating func applyCarrierArrival(_ carrier: Carrier, events: inout [WorldEvent]) {
        // `currentTile` is `nil` only on a malformed empty path; arrived
        // carriers always have a positive pathIndex < path.count. Use
        // `path.last` as the safe destination fallback.
        let arrivalTile = carrier.currentTile ?? carrier.path.last ?? TileCoordinate(x: 0, y: 0)
        switch carrier.mission {
        case let .deliver(good, amount, _, toWarehouse):
            stockpiles[toWarehouse]?.deposit(good, amount: amount)
            events.append(.carrierArrived(
                carrier: carrier.id, at: arrivalTile, good: good, amount: amount
            ))
        case let .retrieve(good, amount, _, toConsumer):
            stockpiles[toConsumer]?.deposit(good, amount: amount)
            events.append(.carrierArrived(
                carrier: carrier.id, at: arrivalTile, good: good, amount: amount
            ))
        case let .deliverToConstructionSite(good, amount, _, toBuilding):
            applyConstructionDelivery(
                ConstructionDelivery(
                    building: toBuilding,
                    good: good,
                    amount: amount,
                    carrier: carrier,
                    arrivalTile: arrivalTile
                ),
                events: &events
            )
        }
    }

    /// Side-effect of a `.deliverToConstructionSite` arrival: bumps
    /// the site's `materialsDelivered`, emits `carrierArrived`, and
    /// flips the substate to `.actively` (plus `constructionStarted`)
    /// when the recipe is satisfied. Spec
    /// `add-construction-stalls` / M5.
    /// Bundle of `.deliverToConstructionSite` arrival parameters,
    /// packed so the apply method stays under the lint parameter-count
    /// gate.
    private struct ConstructionDelivery {
        let building: EntityID
        let good: Good
        let amount: Int
        let carrier: Carrier
        let arrivalTile: TileCoordinate
    }

    private mutating func applyConstructionDelivery(
        _ delivery: ConstructionDelivery,
        events: inout [WorldEvent]
    ) {
        guard var site = buildings[delivery.building] else { return }
        site.materialsDelivered[delivery.good, default: 0] += delivery.amount
        let cost = BuildingCatalog.spec(for: site.kind).materialCost
        let satisfied = cost.allSatisfy {
            (site.materialsDelivered[$0.key] ?? 0) >= $0.value
        }
        let wasWaiting = site.constructionState == .waitingForMaterials
        if wasWaiting, satisfied {
            site.constructionState = .actively
        }
        buildings[delivery.building] = site
        events.append(.carrierArrived(
            carrier: delivery.carrier.id,
            at: delivery.arrivalTile,
            good: delivery.good,
            amount: delivery.amount
        ))
        if wasWaiting, satisfied {
            events.append(.constructionStarted(building: delivery.building))
        }
    }

    private mutating func spawnCarriersFromProducers(
        tileToIsland: [TileCoordinate: IslandID],
        events: inout [WorldEvent]
    ) {
        for (producerId, building) in buildings where building.state == .operational {
            guard let recipe = ProductionCatalog.recipe(for: building.kind) else { continue }
            let inFlight = carrierCountByProducer[producerId, default: 0]
            guard inFlight < CarrierConfig.perProducerCap else { continue }
            guard let producerStock = stockpiles[producerId] else { continue }
            let footprint = BuildingCatalog.spec(for: building.kind).footprint
            guard let road = anyAdjacentRoad(anchor: building.anchor, footprint: footprint)
            else { continue }
            let islandID = islandFor(building: building, tileToIsland: tileToIsland)

            for (good, _) in recipe.outputs where producerStock.quantity(of: good) >= 1 {
                if let (siteId, sitePath) = findWaitingSiteOnIsland(
                    fromRoad: road, good: good, islandID: islandID, tileToIsland: tileToIsland
                ) {
                    spawnCarrier(
                        CarrierSpawn(
                            producerId: producerId,
                            road: road,
                            good: good,
                            mission: .deliverToConstructionSite(
                                good: good, amount: 1,
                                fromProducer: producerId, toBuilding: siteId
                            ),
                            path: sitePath
                        ),
                        events: &events
                    )
                    break
                }
                guard let (warehouseId, path) = findRoadConnectedBuffer(
                    fromRoad: road, good: good
                )
                else { continue }
                spawnCarrier(
                    CarrierSpawn(
                        producerId: producerId,
                        road: road,
                        good: good,
                        mission: .deliver(
                            good: good, amount: 1,
                            fromProducer: producerId, toWarehouse: warehouseId
                        ),
                        path: path
                    ),
                    events: &events
                )
                break
            }
        }
    }

    /// Bundle of spawn arguments, packed so `spawnCarrier` stays
    /// under the lint parameter-count gate.
    private struct CarrierSpawn {
        let producerId: EntityID
        let road: TileCoordinate
        let good: Good
        let mission: Carrier.Mission
        let path: [TileCoordinate]
    }

    private mutating func spawnCarrier(
        _ spawn: CarrierSpawn,
        events: inout [WorldEvent]
    ) {
        stockpiles[spawn.producerId]?.withdraw(spawn.good, amount: 1)
        let carrierId = EntityID(raw: nextEntityRaw)
        nextEntityRaw &+= 1
        carriers[carrierId] = Carrier(id: carrierId, path: spawn.path, mission: spawn.mission)
        carrierCountByProducer[spawn.producerId, default: 0] += 1
        events.append(.carrierDeparted(
            carrier: carrierId, from: spawn.road, good: spawn.good
        ))
    }

    /// Closest road-connected waiting construction site on `islandID`
    /// that still needs `good` to complete its recipe. Returns nil if
    /// no such site is reachable. Spec: `add-construction-stalls` /
    /// `Producer prioritizes waiting construction sites`.
    private func findWaitingSiteOnIsland(
        fromRoad start: TileCoordinate,
        good: Good,
        islandID: IslandID?,
        tileToIsland: [TileCoordinate: IslandID]
    ) -> (EntityID, [TileCoordinate])? {
        var best: (EntityID, [TileCoordinate])?
        for site in buildings.values.sorted(by: { $0.id.raw < $1.id.raw }) {
            let id = site.id
            guard site.state == .constructing else { continue }
            guard site.constructionState == .waitingForMaterials else { continue }
            let cost = BuildingCatalog.spec(for: site.kind).materialCost
            let needed = (cost[good] ?? 0) - (site.materialsDelivered[good] ?? 0)
            guard needed > 0 else { continue }
            if let islandID {
                let onIsland = buildingIsOnIsland(
                    site, islandID: islandID, tileToIsland: tileToIsland
                )
                if !onIsland { continue }
            }
            let footprint = BuildingCatalog.spec(for: site.kind).footprint
            guard let siteRoad = anyAdjacentRoad(anchor: site.anchor, footprint: footprint)
            else { continue }
            guard let path = PathFinder.path(from: start, to: siteRoad, in: roadGraph)
            else { continue }
            if best == nil || path.count < best!.1.count {
                best = (id, path)
            }
        }
        return best
    }

    func islandFor(
        building: Building,
        tileToIsland: [TileCoordinate: IslandID]
    ) -> IslandID? {
        let footprint = BuildingCatalog.spec(for: building.kind).footprint
        for tile in footprint.tiles(anchor: building.anchor) {
            if let id = tileToIsland[tile] { return id }
        }
        return nil
    }

    /// Returns any road tile orthogonally adjacent to the footprint, or nil
    /// if the building isn't road-connected.
    func anyAdjacentRoad(anchor: TileCoordinate, footprint: Footprint) -> TileCoordinate? {
        let tiles = footprint.tiles(anchor: anchor)
        let occupied = Set(tiles)
        for tile in tiles {
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

    /// Find the road-connected goods buffer with capacity for `good`.
    /// Returns (bufferId, road path) on the shortest path; nil if none
    /// reachable. Equal-length paths resolve to the lowest entity ID.
    func findRoadConnectedBuffer(
        fromRoad start: TileCoordinate,
        good: Good
    ) -> (EntityID, [TileCoordinate])? {
        var best: (EntityID, [TileCoordinate])?
        for building in goodsBuffers() where building.state == .operational {
            let id = building.id
            guard let bufferRoad = anyAdjacentRoad(
                anchor: building.anchor,
                footprint: BuildingCatalog.spec(for: building.kind).footprint
            )
            else { continue }
            guard let stock = stockpiles[id], stock.freeSpace > 0 else { continue }
            _ = good // future: check warehouse accepts this good type
            guard let path = roadPath(from: start, to: bufferRoad)
            else { continue }
            if best == nil || path.count < best!.1.count {
                best = (id, path)
            }
        }
        return best
    }

    mutating func runEconomySystem(signatureSources sources: [Building], events: inout [WorldEvent]) {
        guard !economy.gameOver else { return }
        if tickCount > 0, tickCount.isMultiple(of: Economy.taxIntervalTicks) {
            var taxes = taxesByOwner(sources: sources)
            let amount = taxes.removeValue(forKey: .player) ?? 0
            economy.credit(amount)
            creditRivals(taxes)
            // Only emit when actual money flowed — `taxesCollected` is a
            // meaningful event the audio layer binds to a coin sound, not
            // a 5-second heartbeat for empty cities.
            if amount > 0 {
                events.append(.taxesCollected(amount: amount))
            }
        }
        if tickCount > 0, tickCount.isMultiple(of: Economy.upkeepIntervalTicks) {
            var upkeepByOwner: [Owner: Int64] = [:]
            for building in buildings.values where building.state == .operational {
                upkeepByOwner[building.owner, default: 0] += upkeep(of: building, sources: sources)
            }
            // Difficulty scaling applies to the player only.
            let totalUpkeep = difficulty.scaledUpkeep(upkeepByOwner.removeValue(forKey: .player) ?? 0)
            economy.deduct(totalUpkeep)
            creditRivals(upkeepByOwner.mapValues { -$0 })
            // Same as above — empty cities and free-upkeep buildings shouldn't
            // generate a per-interval no-op event.
            if totalUpkeep > 0 {
                events.append(.upkeepPaid(amount: totalUpkeep))
            }
        }
        // Track bankruptcy state transitions so events fire on the edges only.
        let priorDeficitTicks = economy.bankruptcyDeficitTicks
        let priorGameOver = economy.gameOver
        if economy.balance < 0 {
            economy.bankruptcyDeficitTicks &+= 1
            if priorDeficitTicks == 0 {
                events.append(.bankruptcyWarning(deficitTicks: economy.bankruptcyDeficitTicks))
            }
            if economy.bankruptcyDeficitTicks >= difficulty.bankruptcyGraceTicks {
                economy.gameOver = true
                if !priorGameOver {
                    events.append(.gameOver)
                }
            }
        } else {
            economy.bankruptcyDeficitTicks = 0
            if priorDeficitTicks > 0 {
                events.append(.bankruptcyResolved)
            }
        }
    }

    /// Spec: `population-and-needs` / Taxes scale with tier; each house
    /// pays its owner (spec `economy` / Each owner has its own purse),
    /// with the owner's monument bonus.
    private func taxesByOwner(sources: [Building]) -> [Owner: Int64] {
        var taxes: [Owner: Int64] = [:]
        for (id, pop) in populations {
            taxes[owner(of: id), default: 0] += houseTax(house: id, population: pop, sources: sources)
        }
        for (owner, amount) in taxes {
            taxes[owner] = taxWithMonumentBonus(amount, for: owner)
        }
        return taxes
    }

    /// Books per-rival amounts in rival ID order. Rivals never go
    /// bankrupt; a negative treasury only makes them wait.
    private mutating func creditRivals(_ amounts: [Owner: Int64]) {
        for (owner, amount) in amounts.sorted(by: { ($0.key.rivalID ?? 0) < ($1.key.rivalID ?? 0) }) {
            credit(amount, to: owner)
        }
    }

    /// True if any warehouse holding `good` is road-connected (any path)
    /// from `anchor`. M4 simplified: we just check road-connected
    /// warehouses, not a full path-finding query. Carriers do the rest.
    func hasGoodInReach(_ good: Good, fromAnchor anchor: TileCoordinate, footprint: Footprint) -> Bool {
        guard roadGraph.isAnchorRoadConnected(anchor, footprint: footprint) else { return false }
        for building in goodsBuffers() where building.state == .operational {
            guard (stockpiles[building.id]?.quantity(of: good) ?? 0) > 0 else { continue }
            let bufferFootprint = BuildingCatalog.spec(for: building.kind).footprint
            if sharesRoadNetwork(anchor, footprint, with: building.anchor, bufferFootprint) {
                return true
            }
        }
        return false
    }
}
