import Foundation

/// Ownership queries and rival setup. Spec: `rival-towns`.
public extension World {
    func rival(_ id: RivalID) -> RivalTown? {
        rivals.first { $0.id == id }
    }

    /// The rival seated on the island, otherwise the player (design D3).
    func owner(ofIsland islandID: IslandID) -> Owner {
        rivals.first { $0.islandID == islandID }?.owner ?? .player
    }

    /// A building's owner. Unknown IDs count as the player's, so houses
    /// set up without a building stay in the player's totals.
    func owner(of id: EntityID) -> Owner {
        buildings[id]?.owner ?? .player
    }

    /// Goods buffers belonging to `owner`, in entity ID order.
    func goodsBuffers(of owner: Owner) -> [Building] {
        buildings.values
            .filter { Self.logisticsBufferKinds.contains($0.kind) && $0.owner == owner }
            .sorted { $0.id.raw < $1.id.raw }
    }

    /// Residents in `owner`'s houses.
    func population(of owner: Owner) -> Int {
        populations(of: owner).reduce(0) { $0 + Int($1.population) }
    }
}

extension World {
    /// Populations of `owner`'s houses.
    func populations(of owner: Owner) -> [HousePopulation] {
        populations.filter { self.owner(of: $0.key) == owner }.map(\.value)
    }

    /// False on a rival's island; the player may not clear its forests.
    func isPlayerLand(_ coord: TileCoordinate) -> Bool {
        islandID(at: coord).map { owner(ofIsland: $0) == .player } ?? true
    }

    /// The lowest-ID town center standing on the island.
    func townCenter(onIsland islandID: IslandID, tileToIsland: [TileCoordinate: IslandID]) -> Building? {
        buildings.values
            .filter { $0.kind == .townCenter && buildingIsOnIsland($0, islandID: islandID, tileToIsland: tileToIsland) }
            .min { $0.id.raw < $1.id.raw }
    }

    func rivalIndex(_ id: RivalID) -> Int? {
        rivals.firstIndex { $0.id == id }
    }

    /// Takes `amount` from `owner`'s purse when it covers it.
    mutating func charge(_ amount: Int64, to owner: Owner) -> Bool {
        switch owner {
        case .player:
            guard economy.balance >= amount else { return false }
            economy.deduct(amount)
        case let .rival(id):
            guard let index = rivalIndex(id), rivals[index].treasury >= amount else { return false }
            rivals[index].treasury -= amount
        }
        return true
    }

    /// Adds `amount` (negative for a payment) to `owner`'s purse.
    mutating func credit(_ amount: Int64, to owner: Owner) {
        switch owner {
        case .player: economy.credit(amount)
        case let .rival(id): if let index = rivalIndex(id) { rivals[index].treasury += amount }
        }
    }

    /// Rejects a footprint with a land tile on an island `owner` doesn't
    /// own, naming the island's owner. Water tiles are not checked.
    func foreignIslandRejection(
        tiles: [TileCoordinate],
        for owner: Owner,
        tileToIsland: [TileCoordinate: IslandID]
    ) -> PlacementRejection? {
        for tile in tiles {
            guard let islandID = tileToIsland[tile] else { continue }
            let islandOwner = self.owner(ofIsland: islandID)
            if islandOwner != owner { return .foreignIsland(islandOwner) }
        }
        return nil
    }

    /// Seats `difficulty.rivalCount` rivals on the islands other than the
    /// home island, largest first, and hands each the town center
    /// already seeded there (design D2).
    mutating func seedRivals() {
        let map = tileToIslandMap()
        let center = TileCoordinate(x: mapWidth / 2, y: mapHeight / 2)
        let bySize = islands.sorted { ($0.tileCount, -Int($0.id)) > ($1.tileCount, -Int($1.id)) }
        guard let home = map[center] ?? bySize.first?.id else { return }
        let rivalCultures = Culture.allCases.filter { $0 != culture }
        let seats = bySize.filter { $0.id != home }.prefix(difficulty.rivalCount)
        for (offset, island) in seats.enumerated() {
            let id = RivalID(offset + 1)
            guard let townCenter = townCenter(onIsland: island.id, tileToIsland: map), offset < rivalCultures.count else { continue }
            buildings[townCenter.id]?.owner = .rival(id)
            rivals.append(RivalTown(
                id: id, name: island.name, islandID: island.id, culture: rivalCultures[offset],
                colour: .forRival(id), age: age, treasury: difficulty.rivalTreasury,
                townCenterID: townCenter.id, ai: RivalAIState()
            ))
        }
    }
}
