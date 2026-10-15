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
        case let .marketBuy(townCenter, good, quantity):
            applyMarketTrade(.bought, good, quantity, at: townCenter, events: &events)
        case let .marketSell(townCenter, good, quantity):
            applyMarketTrade(.sold, good, quantity, at: townCenter, events: &events)
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
        if let capacity = Self.stockpileCapacity(for: kind) {
            stockpiles[id] = Stockpile(capacity: capacity)
        }
        let materialCost = materialCost(of: kind, for: owner)
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

    /// Stockpile capacity per building kind, the pack's `storage`. nil
    /// means "this kind has no stockpile", e.g. roads.
    static func stockpileCapacity(for kind: BuildingKind) -> Int? {
        kind.storage
    }
}
