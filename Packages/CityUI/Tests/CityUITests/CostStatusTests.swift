import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// Tests for the cost-breakdown CostStatus added by
// `add-construction-stalls` → M6. Scenarios under `Requirement: Ghost
// preview status tints` in
// openspec/changes/add-construction-stalls/specs/rendering-2_5d/spec.md.

private func emptyTownCenter(in world: inout World) {
    for (id, building) in world.buildings where building.kind == .townCenter {
        world.stockpiles[id] = Stockpile(capacity: 8)
    }
}

private func injectOperational(
    in world: inout World,
    kind: BuildingKind,
    at anchor: TileCoordinate
) {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    let footprint = BuildingCatalog.spec(for: kind).footprint
    world.buildings[id] = Building(
        id: id, kind: kind, anchor: anchor,
        state: .operational, ticksSincePlacement: 0
    )
    for tile in footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
}

@MainActor
private func session(
    armed kind: BuildingKind,
    configure: (inout World) -> Void = { _ in }
) -> GameSession {
    var world = World.newGame()
    configure(&world)
    let tile = world.firstTile(of: .grass) ?? TileCoordinate(x: 48, y: 48)
    let session = GameSession(world: world)
    session.selectTool(.place(kind))
    session.handleHover(at: tile)
    return session
}

@MainActor
@Test("scenario: cost status is ok when have >= need")
func scenarioCostStatusIsOkWhenHaveGreaterEqualNeed() throws {
    // Fresh world: town center has 4 wood + 2 planks. Lumberjack hut
    // needs 2 wood. Status for wood = .ok.
    let session = session(armed: .lumberjackHut)
    let ghost = try #require(session.ghostState())
    let breakdown = try #require(ghost.costBreakdown)
    #expect(breakdown[.wood]?.status == .ok)
}

@MainActor
@Test("scenario: cost status is queueable when have < need but producers supply")
func scenarioCostStatusIsQueueableWhenHaveLessThanNeedButProducersSupply() throws {
    // Sawmill needs 4 wood + 1 plank. Empty town center, inject a
    // lumberjack producer → wood becomes queueable.
    let session = session(armed: .sawmill) { world in
        emptyTownCenter(in: &world)
        let grass = world.firstTile(of: .grass) ?? TileCoordinate(x: 48, y: 48)
        let anchor = TileCoordinate(x: grass.x + 4, y: grass.y)
        injectOperational(in: &world, kind: .lumberjackHut, at: anchor)
        let anchor2 = TileCoordinate(x: grass.x + 8, y: grass.y)
        injectOperational(in: &world, kind: .sawmill, at: anchor2)
    }
    let ghost = try #require(session.ghostState())
    let breakdown = try #require(ghost.costBreakdown)
    #expect(breakdown[.wood]?.status == .queueable)
    #expect(breakdown[.planks]?.status == .queueable)
}

@MainActor
@Test("scenario: cost status is blocked when no path to supply")
func scenarioCostStatusIsBlockedWhenNoPathToSupply() throws {
    let session = session(armed: .sawmill) { world in
        emptyTownCenter(in: &world)
        // No producers on the island.
    }
    let ghost = try #require(session.ghostState())
    let breakdown = try #require(ghost.costBreakdown)
    #expect(breakdown[.wood]?.status == .blocked)
    #expect(ghost.valid == false)
}

@MainActor
@Test("scenario: placement allowed when at least one good is queueable and none are blocked")
func scenarioPlacementAllowedWhenAtLeastOneGoodIsQueueableAndNoneAreBlocked() throws {
    // Town center starts with 4 wood + 2 planks. Sawmill needs 4 wood
    // + 1 plank → wood is ok, planks is ok. Bump town center down so
    // planks becomes queueable but wood stays ok; need a sawmill
    // producer to make planks queueable.
    let session = session(armed: .sawmill) { world in
        for (id, building) in world.buildings where building.kind == .townCenter {
            var stockpile = Stockpile(capacity: 8)
            _ = stockpile.deposit(.wood, amount: 4) // wood ok
            // planks = 0 → queueable
            world.stockpiles[id] = stockpile
        }
        let grass = world.firstTile(of: .grass) ?? TileCoordinate(x: 48, y: 48)
        let anchor = TileCoordinate(x: grass.x + 4, y: grass.y)
        injectOperational(in: &world, kind: .sawmill, at: anchor)
    }
    let ghost = try #require(session.ghostState())
    let breakdown = try #require(ghost.costBreakdown)
    #expect(breakdown[.wood]?.status == .ok)
    #expect(breakdown[.planks]?.status == .queueable)
    #expect(ghost.valid == true)
}
