import Foundation

/// Per-tick simulation systems. Each is a pure function of
/// `(inout World) -> Void` so future changes (parallelization, ordering
/// tweaks) are easy. Production lives here; carriers, economy and
/// population have their own `World+…` files.
extension World {
    static let seasonalCrops: Set<BuildingKind> = [.farm, .grainFarm, .forester]

    /// Operational producers by entity ID. They share forests, buffers and
    /// new entity IDs, so they run in this order and replays don't depend
    /// on dictionary order.
    func operationalProducersInEntityOrder() -> [Building] {
        buildings.values
            .filter { $0.state == .operational && ProductionCatalog.recipe(for: $0.kind) != nil }
            .sorted { $0.id.raw < $1.id.raw }
    }

    mutating func runProductionSystem(signatureSources: [Building], events: inout [WorldEvent]) {
        for building in operationalProducersInEntityOrder() {
            let id = building.id
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

    /// What a pass over every house needs to answer `hasGoodInReach`:
    /// the operational goods buffers and the road network's components.
    /// Consumption changes stock, not buildings or roads, so one snapshot
    /// serves the whole pass instead of a listing and a path search per
    /// house, need and buffer.
    struct SupplyReach {
        /// Each operational buffer, in entity order, with the road
        /// component of its first adjacent road (nil without one).
        let buffers: [(id: EntityID, component: Int?)]
        let roadComponents: [TileCoordinate: Int]
    }

    func supplyReach() -> SupplyReach {
        let components = roadGraph.componentLabels()
        let buffers = goodsBuffers().filter { $0.state == .operational }.map { buffer in
            let road = anyAdjacentRoad(anchor: buffer.anchor, footprint: BuildingCatalog.spec(for: buffer.kind).footprint)
            return (buffer.id, road.flatMap { components[$0] })
        }
        return SupplyReach(buffers: buffers, roadComponents: components)
    }

    /// True if any operational buffer holding `good` is road-connected
    /// (any path) from `anchor`. M4 simplified: we just check
    /// road-connected warehouses, not a full path-finding query.
    /// Carriers do the rest.
    func hasGoodInReach(
        _ good: Good, fromAnchor anchor: TileCoordinate, footprint: Footprint, reach: SupplyReach
    ) -> Bool {
        guard let from = anyAdjacentRoad(anchor: anchor, footprint: footprint),
              let component = reach.roadComponents[from]
        else { return false }
        return reach.buffers.contains { buffer in
            buffer.component == component && (stockpiles[buffer.id]?.quantity(of: good) ?? 0) > 0
        }
    }
}
