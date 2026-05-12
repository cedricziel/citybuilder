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

    /// One-shot connected-component scan used to scope placement
    /// lookups to a single island. Tests + production paths re-build
    /// the map per placement; canPlace + applyPlace each pay one O(N).
    func tileToIslandMap() -> [TileCoordinate: IslandID] {
        IslandDetector.detect(
            width: mapWidth,
            height: mapHeight,
            terrain: terrainGrid,
            mapHeightForClimate: mapHeight,
            seed: seed
        ).tileToIsland
    }
}

extension World {
    /// Returns per-good shortfall (need − have) for the given recipe
    /// against the island that contains `anchor`. Empty result means
    /// the island can supply the full cost from its goods-buffer
    /// buildings. Per spec `buildings-and-construction` /
    /// "Placement rejected when island materials are short".
    func materialShortfall(
        cost: [Good: Int],
        anchor: TileCoordinate
    ) -> [Good: Int] {
        let map = tileToIslandMap()
        let availability = islandStockpile(at: anchor, tileToIsland: map)
        var shortfall: [Good: Int] = [:]
        for (good, need) in cost {
            let have = availability[good] ?? 0
            if have < need {
                shortfall[good] = need - have
            }
        }
        return shortfall
    }

    /// Withdraws `cost` from goods-buffer buildings on the island
    /// containing `anchor`, in road-distance-ascending order
    /// (Manhattan distance as the v0 approximation; spec design D3
    /// leaves room for true road-graph distance later). Ties break by
    /// ascending `EntityID.raw`. canPlace must have already cleared
    /// the request, so `cost` is guaranteed to be satisfiable.
    mutating func deductMaterials(
        cost: [Good: Int],
        anchor: TileCoordinate
    ) {
        let tileToIsland = tileToIslandMap()
        guard let islandID = tileToIsland[anchor] else { return }
        let sortedBuffers = sortedGoodsBuffers(
            islandID: islandID,
            anchor: anchor,
            tileToIsland: tileToIsland
        )
        for good in Good.allCases {
            guard let needed = cost[good], needed > 0 else { continue }
            withdraw(good: good, amount: needed, from: sortedBuffers)
        }
    }

    private mutating func withdraw(
        good: Good,
        amount: Int,
        from sortedBuffers: [EntityID]
    ) {
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
        }
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
