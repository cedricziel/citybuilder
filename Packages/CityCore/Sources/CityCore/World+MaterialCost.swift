import Foundation

/// Placement-time material-cost helpers. Lives in its own file so the
/// World struct body stays under SwiftLint's `type_body_length` ceiling.
/// Spec: `add-build-materials-cost` (buildings-and-construction,
/// warehouses-and-logistics).
public extension World {
    /// Building kinds whose stockpiles back placement material checks.
    /// Mirrors `WorldSnapshot.goodsBufferKinds` but lives on World so
    /// canPlace doesn't depend on snapshot construction.
    static let placementBufferKinds: Set<BuildingKind> = [
        .warehouse, .port, .shipyard, .townCenter
    ]

    /// Sum of goods across every goods-buffer building (warehouse,
    /// port, shipyard, town center) anchored on the island that
    /// contains the given tile, plus any virtual `testMaterialCredits`.
    func islandStockpile(
        at anchor: TileCoordinate,
        tileToIsland: [TileCoordinate: IslandID]
    ) -> [Good: Int] {
        guard let islandID = tileToIsland[anchor] else { return [:] }
        var totals: [Good: Int] = [:]
        for (id, building) in buildings where Self.placementBufferKinds.contains(building.kind) {
            guard buildingIsOnIsland(building, islandID: islandID, tileToIsland: tileToIsland)
            else { continue }
            guard let stockpile = stockpiles[id] else { continue }
            for (good, amount) in stockpile.contents where amount > 0 {
                totals[good, default: 0] += amount
            }
        }
        for (good, amount) in testMaterialCredits where amount > 0 {
            totals[good, default: 0] += amount
        }
        return totals
    }

    /// Tile-to-island map used to scope placement lookups to a single
    /// island. Served from `IslandMapCache`, which only rescans when the
    /// water mask changes.
    func tileToIslandMap() -> [TileCoordinate: IslandID] {
        IslandMapCache.shared.map(width: mapWidth, height: mapHeight, terrain: terrainGrid)
    }
}

extension World {
    /// Returns per-good shortfall (need − have) for the given recipe
    /// against the island that contains `anchor`. A good is considered
    /// satisfiable when either (a) the island's goods buffers hold
    /// enough or (b) at least one operational producer on the island
    /// outputs it (`add-construction-stalls`: queueable). Empty result
    /// means the placement can proceed — possibly entering the
    /// waiting-for-materials substate. Per spec
    /// `buildings-and-construction` / "canPlace allowed when production
    /// exists".
    func materialShortfall(
        cost: [Good: Int],
        anchor: TileCoordinate,
        tileToIsland map: [TileCoordinate: IslandID]
    ) -> [Good: Int] {
        let availability = islandStockpile(at: anchor, tileToIsland: map)
        let islandID = map[anchor]
        var shortfall: [Good: Int] = [:]
        for (good, need) in cost {
            let have = availability[good] ?? 0
            guard have < need else { continue }
            if let islandID, producesGood(onIsland: islandID, good: good, tileToIsland: map) {
                // A producer covers this good — placement is allowed,
                // the building will queue on the missing units.
                continue
            }
            shortfall[good] = need - have
        }
        return shortfall
    }

    /// True when at least one operational producer anchored on the
    /// given island has a recipe that outputs `good`. The producer's
    /// stockpile is irrelevant — current emptiness is what makes the
    /// placement queueable rather than satisfied.
    public func producesGood(
        onIsland islandID: IslandID,
        good: Good,
        tileToIsland: [TileCoordinate: IslandID]
    ) -> Bool {
        for (_, building) in buildings where building.state == .operational {
            guard let recipe = ProductionCatalog.recipe(for: building.kind) else { continue }
            guard recipe.outputs[good] ?? 0 > 0 else { continue }
            if buildingIsOnIsland(building, islandID: islandID, tileToIsland: tileToIsland) {
                return true
            }
        }
        return false
    }

    /// Withdraws as much of `cost` as the island can supply from its
    /// goods-buffer buildings, sorted by Manhattan distance (v0
    /// stand-in for true road-graph distance), tiebreak ascending
    /// `EntityID`. Returns the per-good actually-taken map so
    /// `applyPlace` can seed `Building.materialsDelivered` and decide
    /// whether the placement enters the waiting substate. Spec design
    /// D3 (`add-construction-stalls`) — when the island falls short,
    /// the caller proceeds with a partial deduction.
    @discardableResult
    mutating func deductMaterialsPartial(
        cost: [Good: Int],
        anchor: TileCoordinate
    ) -> [Good: Int] {
        let tileToIsland = tileToIslandMap()
        guard let islandID = tileToIsland[anchor] else { return [:] }
        let sortedBuffers = sortedGoodsBuffers(
            islandID: islandID,
            anchor: anchor,
            tileToIsland: tileToIsland
        )
        var delivered: [Good: Int] = [:]
        for good in Good.allCases {
            guard let needed = cost[good], needed > 0 else { continue }
            delivered[good] = withdraw(good: good, amount: needed, from: sortedBuffers)
        }
        return delivered
    }

    /// Back-compat wrapper for callers that want the eager full-cost
    /// deduction behavior (pre-`add-construction-stalls`). Returns
    /// whether the deduction was complete.
    @discardableResult
    mutating func deductMaterials(
        cost: [Good: Int],
        anchor: TileCoordinate
    ) -> Bool {
        let delivered = deductMaterialsPartial(cost: cost, anchor: anchor)
        return cost.allSatisfy { (delivered[$0.key] ?? 0) >= $0.value }
    }

    private mutating func withdraw(
        good: Good,
        amount: Int,
        from sortedBuffers: [EntityID]
    ) -> Int {
        var remaining = amount
        for bufferID in sortedBuffers where remaining > 0 {
            guard var stockpile = stockpiles[bufferID] else { continue }
            let taken = stockpile.withdraw(good, amount: remaining)
            stockpiles[bufferID] = stockpile
            remaining -= taken
        }
        // Virtual test credits absorb any remaining shortfall — see
        // `seedUnlimitedTestInventory` on World+Fixture for the
        // reasoning. In production code with no credits granted,
        // this never executes.
        if remaining > 0, let credit = testMaterialCredits[good], credit > 0 {
            let take = min(remaining, credit)
            testMaterialCredits[good] = credit - take
            remaining -= take
        }
        return amount - remaining
    }

    private func sortedGoodsBuffers(
        islandID: IslandID,
        anchor: TileCoordinate,
        tileToIsland: [TileCoordinate: IslandID]
    ) -> [EntityID] {
        buildings
            .filter { Self.placementBufferKinds.contains($0.value.kind) }
            .filter { _, building in
                buildingIsOnIsland(building, islandID: islandID, tileToIsland: tileToIsland)
            }
            .sorted { lhs, rhs in
                let lhsDistance = manhattan(anchor, lhs.value.anchor)
                let rhsDistance = manhattan(anchor, rhs.value.anchor)
                if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
                return lhs.key.raw < rhs.key.raw
            }
            .map(\.key)
    }

    /// True when any tile in `building`'s footprint resolves to the
    /// island. Used by canPlace + applyPlace's deduction loop.
    func buildingIsOnIsland(
        _ building: Building,
        islandID: IslandID,
        tileToIsland: [TileCoordinate: IslandID]
    ) -> Bool {
        let footprint = BuildingCatalog.spec(for: building.kind).footprint
        for tile in footprint.tiles(anchor: building.anchor) where tileToIsland[tile] == islandID {
            return true
        }
        return false
    }

    private func manhattan(_ lhs: TileCoordinate, _ rhs: TileCoordinate) -> Int {
        abs(lhs.x - rhs.x) + abs(lhs.y - rhs.y)
    }
}
