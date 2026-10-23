import Testing
@testable import CityCore

// platform-shells / Idle-good hint (openspec/changes/keep-the-town-supplied):
// the CityCore query the hint reads.

/// A northern European grass world with a player warehouse holding
/// `contents`, the research of a new medieval game plus `researched`,
/// and the player's `kinds` at `state`.
private func town(
    _ contents: [Good: Int], researched: [Tech] = [], kinds: [BuildingKind] = [], state: BuildingState = .operational
) -> World {
    var world = World.fixtureWithTerrain(width: 20, height: 12, fill: .grass, seed: 1)
    world.culture = .northernEuropean
    world.research = ResearchState(researched: [.scholarship, .feudalOrder] + researched)
    let store = add(.warehouse, at: TileCoordinate(x: 1, y: 1), state: .operational, to: &world)
    for (good, amount) in contents.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
        world.stockpiles[store]?.deposit(good, amount: amount)
    }
    for (index, kind) in kinds.enumerated() {
        add(kind, at: TileCoordinate(x: 6 + index * 3, y: 1), state: state, to: &world)
    }
    return world
}

@discardableResult
private func add(_ kind: BuildingKind, at anchor: TileCoordinate, state: BuildingState, to world: inout World) -> EntityID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.buildings[id] = Building(id: id, kind: kind, anchor: anchor, state: state)
    for tile in BuildingCatalog.spec(for: kind).footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    world.stockpiles[id] = World.stockpileCapacity(for: kind).map { Stockpile(capacity: $0) }
    return id
}

@Test("hops with no brewery are idle once cultivation is researched")
func hopsWithoutBreweryAreIdle() {
    #expect(town([.hops: 22]).idleGoods(of: .player) == [])
    #expect(town([.hops: 22], researched: [.cultivation]).idleGoods(of: .player) == [IdleGood(good: .hops, users: [.brewery])])
}

@Test("a user under construction silences the good")
func userUnderConstructionSilences() {
    let world = town([.hops: 22], researched: [.cultivation], kinds: [.brewery], state: .constructing)
    #expect(world.idleGoods(of: .player) == [])
}

@Test("goods houses need never count")
func houseGoodsNeverCount() {
    #expect(town([.planks: 40], researched: [.mining, .metallurgy]).idleGoods(of: .player) == [])
    #expect(town([.food: 40]).idleGoods(of: .player) == [])
}

@Test("below the threshold nothing is idle")
func belowThresholdNothingIdle() {
    #expect(town([.hops: World.idleGoodThreshold - 1], researched: [.cultivation]).idleGoods(of: .player) == [])
}

@Test("the mill follows milling")
func millFollowsMilling() {
    #expect(town([.grain: 25]).idleGoods(of: .player).map(\.users) == [[.quernHouse]])
    #expect(town([.grain: 25], researched: [.milling]).idleGoods(of: .player).map(\.users) == [[.windmill]])
}

@Test("projects that make nothing don't use a good")
func projectsDontUseGoods() {
    #expect(!World.allUsers(of: .bread).contains(.monument))
    #expect(World.allUsers(of: .wood).contains(.sawmill))
}
