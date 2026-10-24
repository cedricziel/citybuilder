import Testing
@testable import CityCore

// goods-and-production / Producers rest while the stores hold plenty, and
// warehouses-and-logistics / Buildings report why they are idle
// (openspec/changes/rest-when-stocked).

/// A warehouse holding `contents` and a `kind` producer on one road, after
/// the tick that lays the road and runs the first supply pass. A charcoal
/// burner below the road shares the sawmill's wood unless `sharer` is nil.
private func town(
    _ kind: BuildingKind, warehouse contents: [Good: Int], owner: Owner = .player,
    sharer: BuildingKind? = .charcoalBurner
) -> (World, EntityID) {
    var world = World.fixtureWithTerrain(width: 14, height: 8, fill: .grass, seed: 1)
    world.testMaterialCredits = [:]
    let producer = place(kind, at: TileCoordinate(x: 1, y: 1), owner: owner, in: &world)
    if let sharer {
        _ = place(sharer, at: TileCoordinate(x: 1, y: 4), owner: owner, in: &world)
    }
    let store = place(.warehouse, at: TileCoordinate(x: 9, y: 0), owner: owner, in: &world)
    for (good, amount) in contents.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
        world.stockpiles[store]?.deposit(good, amount: amount)
    }
    for x in 0 ... 12 {
        world.enqueue(.place(.road, at: TileCoordinate(x: x, y: 3)))
    }
    world.tick()
    return (world, producer)
}

private func place(_ kind: BuildingKind, at anchor: TileCoordinate, owner: Owner, in world: inout World) -> EntityID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.buildings[id] = Building(id: id, kind: kind, anchor: anchor, state: .operational, owner: owner)
    for tile in BuildingCatalog.spec(for: kind).footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    world.stockpiles[id] = World.stockpileCapacity(for: kind).map { Stockpile(capacity: $0) }
    return id
}

/// What the rest check reads about the fixture town's island.
private func homeContext(_ world: World) -> IslandRestContext {
    world.restContexts(of: .player, tileToIsland: world.tileToIslandMap()).values.first ?? IslandRestContext()
}

private func woodCarriers(to consumer: EntityID, in world: World) -> Int {
    world.carriers.values.count { carrier in
        if case let .retrieve(good, _, _, toConsumer) = carrier.mission { return good == .wood && toConsumer == consumer }
        return false
    }
}

@Test("scenario: a sawmill rests on 40 planks")
func scenarioASawmillRestsOn40Planks() throws {
    let (world, sawmill) = town(.sawmill, warehouse: [.planks: 40, .wood: 20])
    #expect(try world.isResting(#require(world.buildings[sawmill])) == .planks)
    #expect(woodCarriers(to: sawmill, in: world) == 0)
}

@Test("scenario: a sawmill works below the rest level")
func scenarioASawmillWorksBelowTheRestLevel() throws {
    let (world, sawmill) = town(.sawmill, warehouse: [.planks: 39, .wood: 20])
    #expect(try world.isResting(#require(world.buildings[sawmill])) == nil)
    #expect(woodCarriers(to: sawmill, in: world) > 0)
}

/// Direct hops from a producer to a short consumer ask `needsSupply` too,
/// so the rest check there covers every route that feeds a producer.
@Test("no route offers a resting producer more input")
func noRouteOffersARestingProducerMoreInput() {
    let (resting, sawmill) = town(.sawmill, warehouse: [.planks: 40])
    #expect(!resting.needsSupply(sawmill, good: .wood, amount: 1, context: homeContext(resting)))
    let (working, other) = town(.sawmill, warehouse: [.planks: 39])
    #expect(working.needsSupply(other, good: .wood, amount: 1, context: homeContext(working)))
}

@Test("scenario: supply resumes below the rest level")
func scenarioSupplyResumesBelowTheRestLevel() throws {
    var (world, sawmill) = town(.sawmill, warehouse: [.planks: 40, .wood: 20])
    #expect(woodCarriers(to: sawmill, in: world) == 0)
    let store = try #require(world.buildings.values.first { $0.kind == .warehouse }?.id)
    world.stockpiles[store]?.withdraw(.planks, amount: 1)
    world.tick()
    #expect(woodCarriers(to: sawmill, in: world) > 0)
}

@Test("scenario: every output must be stocked")
func scenarioEveryOutputMustBeStocked() {
    let shared: [Good: Set<BuildingKind>] = [.wood: [.sawmill, .charcoalBurner]]
    func resting(_ outputs: [Good: Int], _ stored: [Good: Int]) -> Good? {
        let recipe = ProductionRecipe(inputs: [.wood: 1], outputs: outputs, cycleTicks: 25)
        return World.restingGood(for: recipe, of: .sawmill, context: IslandRestContext(stored: stored, inputUsers: shared))
    }
    #expect(resting([.planks: 1, .flour: 1], [.planks: 40]) == nil)
    #expect(resting([.planks: 1, .flour: 1], [.planks: 40, .flour: 40]) == .planks)
    #expect(resting([.planks: 1, .food: 1], [.planks: 40, .food: 400]) == nil)
}

/// Archipelago seed 0 starts the player with a town center on two
/// islands. Home holds plenty of planks; the outpost holds none, so its
/// sawmill must keep working: home's stores never reach its sites.
@Test("scenario: an outpost rests only on its own island's stores")
func scenarioAnOutpostRestsOnlyOnItsOwnIslandsStores() throws {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .easy)
    let map = world.tileToIslandMap()
    let centers = world.buildings.values
        .filter { $0.kind == .townCenter && $0.owner == .player }
        .sorted { $0.id.raw < $1.id.raw }
    let home = try #require(centers.first)
    let outpost = try #require(centers.first { map[$0.anchor] != map[home.anchor] })
    let outpostPlanks = world.stockpiles[outpost.id]?.quantity(of: .planks) ?? 0
    world.stockpiles[outpost.id]?.withdraw(.planks, amount: outpostPlanks)
    world.stockpiles[outpost.id]?.deposit(.wood, amount: 10)
    world.stockpiles[home.id]?.deposit(.planks, amount: 40)
    let sawmill = try #require(placeBesideRoad(.sawmill, near: outpost, in: &world, map: map))
    _ = try #require(placeBesideRoad(.charcoalBurner, near: outpost, in: &world, map: map))
    world.tick()
    #expect(try world.isResting(#require(world.buildings[sawmill])) == nil)
    #expect(woodCarriers(to: sawmill, in: world) > 0)
}

/// An operational `kind` on free grass of `center`'s island, beside a road.
private func placeBesideRoad(
    _ kind: BuildingKind, near center: Building, in world: inout World, map: [TileCoordinate: IslandID]
) -> EntityID? {
    let footprint = BuildingCatalog.spec(for: kind).footprint
    let island = map[center.anchor]
    for dy in -10 ... 10 {
        for dx in -10 ... 10 {
            let anchor = TileCoordinate(x: center.anchor.x + dx, y: center.anchor.y + dy)
            let free = footprint.tiles(anchor: anchor).allSatisfy {
                map[$0] == island && world.occupiedTiles[$0] == nil && world.terrain(at: $0) == .grass
                    && !world.roadGraph.roadTiles.contains($0)
            }
            if free, world.anyAdjacentRoad(anchor: anchor, footprint: footprint) != nil {
                return place(kind, at: anchor, owner: .player, in: &world)
            }
        }
    }
    return nil
}

@Test("scenario: a producer that shares no input keeps working")
func scenarioAProducerThatSharesNoInputKeepsWorking() throws {
    let (world, sawmill) = town(.sawmill, warehouse: [.planks: 40, .wood: 20], sharer: nil)
    #expect(try world.isResting(#require(world.buildings[sawmill])) == nil)
    #expect(woodCarriers(to: sawmill, in: world) > 0)
}

@Test("scenario: a resting producer finishes its cycle")
func scenarioARestingProducerFinishesItsCycle() {
    var (world, sawmill) = town(.sawmill, warehouse: [.planks: 40])
    world.stockpiles[sawmill]?.deposit(.wood, amount: 1)
    var finished = false
    for _ in 0 ..< 40 where !finished {
        finished = world.tick().events.contains(.productionCycleCompleted(producer: sawmill, kind: .sawmill))
    }
    #expect(finished)
}

@Test("scenario: gatherers never rest")
func scenarioGatherersNeverRest() throws {
    let (world, hut) = town(.lumberjackHut, warehouse: [.wood: 40, .planks: 40])
    #expect(try world.isResting(#require(world.buildings[hut])) == nil)
}

@Test("a rival's producer rests on the rival's stores")
func rivalProducerRestsOnRivalStores() throws {
    let (world, sawmill) = town(.sawmill, warehouse: [.planks: 40, .wood: 20], owner: .rival(RivalID(1)))
    #expect(try world.isResting(#require(world.buildings[sawmill])) == .planks)
    #expect(woodCarriers(to: sawmill, in: world) == 0)
}

@Test("scenario: a resting producer reports resting")
func scenarioARestingProducerReportsResting() {
    let (world, sawmill) = town(.sawmill, warehouse: [.planks: 40])
    #expect(world.buildingIssues()[sawmill] == .resting(.planks))
}

@Test("a resting producer with inputs on hand still reads as working")
func restingProducerWithInputsOnHandReadsAsWorking() {
    var (world, sawmill) = town(.sawmill, warehouse: [.planks: 40])
    world.stockpiles[sawmill]?.deposit(.wood, amount: 1)
    #expect(world.buildingIssues()[sawmill] == nil)
}
