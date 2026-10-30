import Foundation
import Testing
@testable import CityCore

// rival-towns / Rivals keep their houses in a market's reach
// (openspec/changes/visible-distribution, design D11).

/// The plan's block origin `column`, `row` blocks from the home block.
private func origin(_ column: Int, _ row: Int, around center: TileCoordinate) -> TileCoordinate {
    TileCoordinate(x: center.x + RivalTownPlan.span * column, y: center.y + RivalTownPlan.span * row)
}

/// The ring road tiles of the block at `origin`.
private func ring(at origin: TileCoordinate) -> [TileCoordinate] {
    var tiles: [TileCoordinate] = []
    for dy in -1 ... 4 {
        for dx in -1 ... 4 where dy == -1 || dy == 4 || dx == -1 || dx == 4 {
            tiles.append(TileCoordinate(x: origin.x + dx, y: origin.y + dy))
        }
    }
    return tiles
}

/// Lays the ring roads of every plan block up to `blocks` from the home
/// block, where the tiles are free grass.
private func openBlocks(around center: TileCoordinate, upTo blocks: Int, in world: inout World) {
    for row in -blocks ... blocks {
        for column in -blocks ... blocks {
            let free = ring(at: origin(column, row, around: center)).filter {
                world.occupiedTiles[$0] == nil && world.terrain(at: $0) == .grass
            }
            for tile in free {
                world.roadGraph.addRoad(at: tile)
            }
        }
    }
}

/// A house plot of the plan and its block.
private struct Plot {
    let anchor: TileCoordinate
    let column: Int
    let row: Int
}

/// The plan's house plots around `center`, with their blocks.
private func housePlots(around center: TileCoordinate) -> [Plot] {
    let range = -RivalTownPlan.radius ... RivalTownPlan.radius
    return range.flatMap { row in
        range.flatMap { column in
            [(0, 0), (2, 0), (0, 2), (2, 2)].map { dx, dy in
                let corner = origin(column, row, around: center)
                return Plot(anchor: TileCoordinate(x: corner.x + dx, y: corner.y + dy), column: column, row: row)
            }
        }
    }
}

/// Marks every free house plot the plan calls in reach as taken, so only
/// plots beyond the hubs' reach stay free.
private func takeHousePlotsInReach(around center: TileCoordinate, owner: Owner, in world: inout World) {
    var plan = RivalTownPlan(world: world, owner: owner, center: center)
    let blocker = EntityID(raw: 999_999)
    for plot in housePlots(around: center) where world.occupiedTiles[plot.anchor] == nil {
        if plan.isInHubReach(plot.anchor) { world.occupiedTiles[plot.anchor] = blocker }
    }
}

private func grassTown() -> (World, TileCoordinate) {
    var world = World.fixtureWithTerrain(width: 80, height: 80, fill: .grass, seed: 1)
    let center = TileCoordinate(x: 38, y: 38)
    world.testPlace(.townCenter, at: center, owner: .player)
    return (world, center)
}

@Test("scenario: A rival's houses stay near its hubs")
func housePlotsStayInAHubsReach() throws {
    let (world, center) = grassTown()
    var plan = RivalTownPlan(world: world, owner: .player, center: center)
    let found = plan.slot(for: .house)
    let slot = try #require(found)
    let near = plan.isInHubReach(slot.anchor)
    let far = plan.isInHubReach(TileCoordinate(x: center.x + 20, y: center.y))
    let needs = plan.needsMarketplace()
    #expect(near)
    #expect(!far)
    #expect(!needs)
}

@Test func everyPlotThePlanCallsInReachIsServedOnceItsRoadsExist() {
    let (world, center) = grassTown()
    var plan = RivalTownPlan(world: world, owner: .player, center: center)
    var checked = 0
    for plot in housePlots(around: center) where world.occupiedTiles[plot.anchor] == nil {
        guard plan.isInHubReach(plot.anchor) else { continue }
        var built = world
        let rings = ring(at: origin(0, 0, around: center)) + ring(at: origin(plot.column, plot.row, around: center))
        for tile in rings where built.occupiedTiles[tile] == nil {
            built.roadGraph.addRoad(at: tile)
        }
        let house = SignatureFixture.inject(.house, at: plot.anchor, in: &built)
        #expect(built.hubService().hubOf[house] != nil, "plot \(plot.anchor)")
        checked += 1
    }
    #expect(checked > 8)
}

@Test func aTownWithNoHouseRoomInReachNeedsAMarketplace() throws {
    var (world, center) = grassTown()
    openBlocks(around: center, upTo: 3, in: &world)
    takeHousePlotsInReach(around: center, owner: .player, in: &world)
    var plan = RivalTownPlan(world: world, owner: .player, center: center)
    let house = plan.slot(for: .house)
    let needs = plan.needsMarketplace()
    let slot = plan.slot(for: .marketplace)
    #expect(house == nil)
    #expect(needs)
    let market = try #require(slot)
    #expect(abs(market.anchor.x - center.x) + abs(market.anchor.y - center.y) >= 9)
}

@Test func aMarketplaceBeingBuiltBringsHousePlotsBackInReach() throws {
    var (world, center) = grassTown()
    openBlocks(around: center, upTo: 3, in: &world)
    takeHousePlotsInReach(around: center, owner: .player, in: &world)
    var plan = RivalTownPlan(world: world, owner: .player, center: center)
    let found = plan.slot(for: .marketplace)
    let market = try #require(found)
    world.testPlace(.marketplace, at: market.anchor, owner: .player)
    var later = RivalTownPlan(world: world, owner: .player, center: center)
    let house = later.slot(for: .house)
    let needs = later.needsMarketplace()
    #expect(house != nil)
    #expect(!needs)
}

@Test func aHouseNoHubServesCallsForAMarketplaceNearIt() throws {
    var (world, center) = grassTown()
    openBlocks(around: center, upTo: 4, in: &world)
    let far = origin(4, 2, around: center)
    _ = SignatureFixture.inject(.house, at: far, in: &world)
    var plan = RivalTownPlan(world: world, owner: .player, center: center)
    let needs = plan.needsMarketplace()
    let found = plan.slot(for: .marketplace)
    let market = try #require(found)
    #expect(needs)
    #expect(abs(market.anchor.x - far.x) + abs(market.anchor.y - far.y) <= 9)
}

@Test("scenario: A rival builds a marketplace when its houses would fall outside every hub")
func rivalBuildsAMarketplaceBeyondItsReach() throws {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    let rival = try #require(world.rival(1))
    let center = try #require(world.buildings[rival.townCenterID]).anchor
    openBlocks(around: center, upTo: 3, in: &world)
    takeHousePlotsInReach(around: center, owner: .rival(1), in: &world)
    world.setRivalStock(1, [.wood: 20, .planks: 20, .food: 20])
    world.setRival(1) { $0.treasury = 100_000 }
    let commands = world.takeTurn(1)
    #expect(commands.contains { if case .rivalPlace(1, .marketplace, _) = $0 { true } else { false } })
}
