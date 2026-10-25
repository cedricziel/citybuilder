import Foundation

/// Applying queued commands at the start of a tick: placement,
/// demolition, routes and forest harvesting. Kept out of `World.swift` so
/// that file stays under SwiftLint's length limit.
extension World {
    mutating func apply(_ command: Command, events: inout [WorldEvent]) {
        switch command {
        case .noop:
            return
        case let .chooseResearch(tech):
            applyChooseResearch(tech)
        case let .harvestForest(coord):
            applyHarvestForest(at: coord, events: &events)
        case let .place(kind, anchor):
            applyPlace(kind: kind, anchor: anchor, owner: .player, events: &events)
        case let .rivalPlace(id, kind, anchor):
            applyPlace(kind: kind, anchor: anchor, owner: .rival(id), events: &events)
        case let .demolish(anchor):
            applyDemolish(anchor: anchor, events: &events)
        case .createRoute, .editRoute, .deleteRoute, .assignShipToRoute, .unassignShip, .setRoutePaused:
            applyRouteCommand(command)
        case let .commission(gallery):
            applyCommission(gallery, events: &events)
        case let .setExport(caravanserai, good):
            applySetExport(caravanserai, good: good)
        case .marketBuy, .marketSell, .rivalMarketBuy, .rivalMarketSell:
            applyMarketCommand(command, events: &events)
        case .acceptOrder, .declineOrder, .abandonOrder, .dispatchOrder:
            applyOrderCommand(command, events: &events)
        }
    }

    /// The player's and the rivals' market trades.
    private mutating func applyMarketCommand(_ command: Command, events: inout [WorldEvent]) {
        if case let .marketBuy(townCenter, good, quantity) = command {
            applyMarketTrade(.bought, good, quantity, at: townCenter, events: &events)
        } else if case let .marketSell(townCenter, good, quantity) = command {
            applyMarketTrade(.sold, good, quantity, at: townCenter, events: &events)
        } else if case let .rivalMarketBuy(rival, good, quantity) = command {
            applyRivalMarketTrade(.bought, good, quantity, for: rival)
        } else if case let .rivalMarketSell(rival, good, quantity) = command {
            applyRivalMarketTrade(.sold, good, quantity, for: rival)
        }
    }

    /// Forests becoming grass when harvested per spec `world-terrain`
    /// ("Forest tile can be cleared"); never on a rival's island.
    private mutating func applyHarvestForest(at coord: TileCoordinate, events: inout [WorldEvent]) {
        guard contains(coord), terrain(at: coord) == .forest, isPlayerLand(coord) else { return }
        terrainGrid[coord.y * mapWidth + coord.x] = .grass
        events.append(.forestHarvested(at: coord))
    }

    /// Rival rejections are silent: the player never sees a banner for
    /// the AI (design D3).
    private mutating func applyPlace(
        kind: BuildingKind,
        anchor: TileCoordinate,
        owner: Owner,
        events: inout [WorldEvent]
    ) {
        let spec = BuildingCatalog.spec(for: kind)
        // Insufficient funds rejects the placement (spec economy).
        guard case .allowed = canPlace(kind, at: anchor, for: owner), charge(spec.cost, to: owner) else {
            if owner == .player {
                events.append(.placementRejected(kind: kind, anchor: anchor))
            }
            return
        }
        // Priced before the building exists, so a rival's first sawmill
        // is still its first (`rival-ai-viability` D2).
        let materialCost = materialCost(of: kind, for: owner)
        let id = EntityID(raw: nextEntityRaw)
        nextEntityRaw &+= 1
        let initialState: BuildingState = spec.buildDurationTicks == 0 ? .operational : .constructing
        let (landFace, seaFace): ([TileCoordinate], [TileCoordinate])
        let shipAnchor: TileCoordinate?
        if spec.shorePlacement != nil {
            let classified = classifyFootprint(kind: kind, anchor: anchor)
            landFace = classified.land
            seaFace = classified.sea
            // Anchor selection: first sea-face tile in deterministic
            // footprint iteration order. Ports use it for docking;
            // other shore buildings may ignore it.
            shipAnchor = (kind == .port) ? seaFace.first : nil
        } else {
            landFace = []
            seaFace = []
            shipAnchor = nil
        }
        let building = Building(
            id: id, kind: kind, anchor: anchor, state: initialState,
            landFaceTiles: landFace, seaFaceTiles: seaFace, shipAnchor: shipAnchor, owner: owner
        )
        buildings[id] = building
        for tile in spec.footprint.tiles(anchor: anchor) {
            occupiedTiles[tile] = id
        }
        if kind == .road {
            roadGraph.addRoad(at: anchor)
        }
        stockpiles[id] = Self.newStockpile(for: kind)
        if !materialCost.isEmpty {
            let delivered = deductMaterialsPartial(cost: materialCost, anchor: anchor)
            buildings[id]?.materialsDelivered = delivered
            let missing = shortfall(for: materialCost, delivered: delivered)
            if missing.isEmpty {
                events.append(.materialsDeducted(building: id, cost: materialCost))
            } else {
                buildings[id]?.constructionState = .waitingForMaterials
                events.append(.constructionWaitingForMaterials(building: id, missing: missing))
                // Partial deduction still surfaces as `materialsDeducted`
                // for what actually moved out of warehouses, so audio +
                // observability stay consistent. Spec leaves this
                // implicit (the scenarios don't forbid co-emission).
                let taken = delivered.filter { $0.value > 0 }
                if !taken.isEmpty {
                    events.append(.materialsDeducted(building: id, cost: taken))
                }
            }
        }
        events.append(.buildingPlaced(building: id, kind: kind, anchor: anchor))
    }

    private func shortfall(
        for cost: [Good: Int],
        delivered: [Good: Int]
    ) -> [Good: Int] {
        var result: [Good: Int] = [:]
        for (good, need) in cost {
            let have = delivered[good] ?? 0
            if have < need { result[good] = need - have }
        }
        return result
    }

    /// A new, empty stockpile for `kind`: per good for stores with the
    /// pack's `storagePerGood`, shared for those with `storage`; nil for a
    /// kind with no stockpile, e.g. roads.
    static func newStockpile(for kind: BuildingKind) -> Stockpile? {
        if let perGood = kind.storagePerGood { return Stockpile(perGood: perGood) }
        return kind.storage.map { Stockpile(capacity: $0) }
    }
}
