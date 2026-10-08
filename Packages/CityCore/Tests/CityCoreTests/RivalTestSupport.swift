@testable import CityCore

// Shared helpers for the `add-rival-towns` tests.

extension World {
    func testTownCenter(onIsland islandID: IslandID) -> Building? {
        townCenter(onIsland: islandID, tileToIsland: tileToIslandMap())
    }

    /// First tile on `islandID`, row-major, matching `predicate`.
    func testFirstTile(onIsland islandID: IslandID, where predicate: (TileCoordinate) -> Bool) -> TileCoordinate? {
        let map = tileToIslandMap()
        guard let island = islands.first(where: { $0.id == islandID }) else { return nil }
        for y in island.bounds.minY ... island.bounds.maxY {
            for x in island.bounds.minX ... island.bounds.maxX {
                let tile = TileCoordinate(x: x, y: y)
                if map[tile] == islandID, predicate(tile) { return tile }
            }
        }
        return nil
    }

    /// First anchor on `islandID` where `owner` may place `kind`.
    func testFirstPlaceable(_ kind: BuildingKind, onIsland islandID: IslandID, for owner: Owner) -> TileCoordinate? {
        testFirstTile(onIsland: islandID) { canPlace(kind, at: $0, for: owner) == .allowed }
    }

    func testFirstForest(onIsland islandID: IslandID) -> TileCoordinate? {
        testFirstTile(onIsland: islandID) { terrain(at: $0) == .forest }
    }

    /// Adds an operational building off the map, outside any island.
    @discardableResult
    mutating func testAddBuilding(_ kind: BuildingKind, owner: Owner) -> EntityID {
        let id = EntityID(raw: nextEntityRaw)
        nextEntityRaw &+= 1
        buildings[id] = Building(
            id: id, kind: kind, anchor: TileCoordinate(x: -10, y: -10 - 3 * Int(id.raw)),
            state: .operational, owner: owner
        )
        return id
    }

    /// Adds an operational house off the map holding `residents`, so
    /// population totals can be set up without a working town.
    @discardableResult
    mutating func testAddHouse(owner: Owner, residents: UInt32, tier: HouseTier = .peasants) -> EntityID {
        let id = testAddBuilding(.house, owner: owner)
        var pop = HousePopulation()
        pop.tier = tier
        pop.population = residents
        populations[id] = pop
        return id
    }

    /// Adds `residents` to `owner`, four (peasants) per house.
    mutating func testAddResidents(_ residents: UInt32, owner: Owner, tier: HouseTier = .peasants) {
        var left = residents
        while left > 0 {
            let here = min(left, tier.capacity)
            testAddHouse(owner: owner, residents: here, tier: tier)
            left -= here
        }
    }

    /// Seats rival 1 without an island, for fixture worlds.
    mutating func testSeatRival() {
        rivals = [RivalTown(
            id: 1, name: "Ravenshore", islandID: 99, culture: .mediterranean, colour: .crimson,
            age: age, treasury: 0, townCenterID: EntityID(raw: 9999), ai: RivalAIState()
        )]
    }

    mutating func testRun(ticks: Int) -> [WorldEvent] {
        (0 ..< ticks).flatMap { _ in tick().events }
    }
}
