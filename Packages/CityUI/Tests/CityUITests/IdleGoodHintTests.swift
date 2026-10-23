import Testing
@testable import CityCore
@testable import CityUI

// platform-shells / Idle-good hint (openspec/changes/keep-the-town-supplied).

/// A session on a northern European grass world with a player warehouse
/// holding `contents`, `researched` on top of a new medieval game's
/// research, and the player's `kinds` at `state`. The first-hour guide is
/// hidden so its card doesn't matter here.
@MainActor
private func session(
    _ contents: [Good: Int], researched: [Tech] = [.cultivation], kinds: [BuildingKind] = [],
    state: BuildingState = .operational
) -> (GameSession, EntityID) {
    var world = World.fixtureWithTerrain(width: 20, height: 12, fill: .grass, seed: 1)
    world.culture = .northernEuropean
    world.research = ResearchState(researched: [.scholarship, .feudalOrder] + researched)
    world.economy.credit(1000)
    let store = add(.warehouse, at: TileCoordinate(x: 1, y: 1), state: .operational, to: &world)
    for (good, amount) in contents.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
        world.stockpiles[store]?.deposit(good, amount: amount)
    }
    for (index, kind) in kinds.enumerated() {
        add(kind, at: TileCoordinate(x: 6 + index * 3, y: 1), state: state, to: &world)
    }
    let session = GameSession(world: world)
    session.hideFirstSteps()
    return (session, store)
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

@MainActor
@Test("scenario: hops pile up without a brewery")
func scenarioHopsPileUpWithoutABrewery() {
    let (session, _) = session([.hops: 22])
    session.step()
    #expect(session.banner?.title == "Nothing uses your hops")
    #expect(session.banner?.description == "Build a brewery for it, or sell hops at the town center's market.")
}

@MainActor
@Test("scenario: a user in town silences the hint")
func scenarioAUserInTownSilencesTheHint() {
    let (session, _) = session([.hops: 22], kinds: [.brewery], state: .constructing)
    session.step()
    #expect(session.banner == nil)
}

@MainActor
@Test("scenario: house goods never count")
func scenarioHouseGoodsNeverCount() {
    let (session, _) = session([.planks: 40], researched: [.mining, .metallurgy])
    session.step()
    #expect(session.banner == nil)
}

@MainActor
@Test("two users are named with or")
func twoIdleUsersNamedWithOr() {
    let hint = GameSession.idleGoodHint(IdleGood(good: .wood, users: [.sawmill, .charcoalBurner]))
    #expect(hint.description == "Build a sawmill or a charcoal burner for it, or sell wood at the town center's market.")
}

@MainActor
@Test("scenario: hint once per good")
func scenarioHintOncePerGood() {
    let (session, store) = session([.hops: 22])
    session.step()
    #expect(session.banner?.title == "Nothing uses your hops")
    session.world.stockpiles[store]?.withdraw(.hops, amount: 22)
    for _ in 0 ..< GameSession.bannerTicks {
        session.step()
    }
    #expect(session.banner == nil)
    session.world.stockpiles[store]?.deposit(.hops, amount: 22)
    session.step()
    #expect(session.banner == nil)
}

@MainActor
@Test("scenario: the first-steps card speaks first")
func scenarioTheFirstStepsCardSpeaksFirst() {
    var world = World.fixtureWithTerrain(width: 20, height: 12, fill: .grass, seed: 1)
    world.research = ResearchState(researched: [.scholarship, .feudalOrder])
    let store = add(.warehouse, at: TileCoordinate(x: 1, y: 1), state: .operational, to: &world)
    world.stockpiles[store]?.deposit(.wood, amount: 25)
    let session = GameSession(world: world)
    #expect(session.firstStepsGuide?.met.contains(.planks) == false)
    session.step()
    #expect(session.banner == nil)
    session.hideFirstSteps()
    session.step()
    #expect(session.banner?.title == "Nothing uses your wood")
}

@MainActor
@Test("scenario: hint doesn't pause")
func scenarioHintDoesntPause() {
    let (session, _) = session([.hops: 22])
    session.step()
    #expect(session.banner != nil)
    let tick = session.world.tickCount
    session.step()
    #expect(session.world.tickCount == tick + 1)
}
