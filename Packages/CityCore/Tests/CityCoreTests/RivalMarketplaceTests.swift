import Foundation
import Testing
@testable import CityCore

// rival-towns / Rivals keep their houses in a market's reach
// (openspec/changes/visible-distribution, design D11).

/// Marks every house plot of the plan around `center` that lies within the
/// town center's reach as taken, so only plots beyond it stay free.
private func takeHousePlotsInReach(around center: TileCoordinate, in world: inout World) {
    let radius = BuildingKind.townCenter.hub?.radius ?? 0
    let blocker = EntityID(raw: 999_999)
    for row in -RivalTownPlan.radius ... RivalTownPlan.radius {
        for column in -RivalTownPlan.radius ... RivalTownPlan.radius {
            let origin = TileCoordinate(x: center.x + RivalTownPlan.span * column, y: center.y + RivalTownPlan.span * row)
            for (dx, dy) in [(0, 0), (2, 0), (0, 2), (2, 2)] {
                let anchor = TileCoordinate(x: origin.x + dx, y: origin.y + dy)
                let distance = abs(anchor.x - center.x) + abs(anchor.y - center.y)
                if distance + RivalTownPlan.hubReachMargin <= radius, world.occupiedTiles[anchor] == nil {
                    world.occupiedTiles[anchor] = blocker
                }
            }
        }
    }
}

/// Lays the ring roads of every plan block up to `blocks` from the home
/// block, where the tiles are free.
private func openBlocks(around center: TileCoordinate, upTo blocks: Int, in world: inout World) {
    for row in -blocks ... blocks {
        for column in -blocks ... blocks {
            let corner = TileCoordinate(x: center.x + RivalTownPlan.span * column, y: center.y + RivalTownPlan.span * row)
            for dy in -1 ... 4 {
                for dx in -1 ... 4 where dy == -1 || dy == 4 || dx == -1 || dx == 4 {
                    let tile = TileCoordinate(x: corner.x + dx, y: corner.y + dy)
                    if world.occupiedTiles[tile] == nil, world.terrain(at: tile) == .grass {
                        world.roadGraph.addRoad(at: tile)
                    }
                }
            }
        }
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
    let needs = plan.needsMarketplace()
    #expect(plan.isInHubReach(slot.anchor))
    #expect(!plan.isInHubReach(TileCoordinate(x: center.x + 20, y: center.y)))
    #expect(!needs)
}

@Test func aTownWithNoHouseRoomInReachNeedsAMarketplace() throws {
    var (world, center) = grassTown()
    openBlocks(around: center, upTo: 3, in: &world)
    takeHousePlotsInReach(around: center, in: &world)
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
    takeHousePlotsInReach(around: center, in: &world)
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

@Test("scenario: A rival builds a marketplace when its houses would fall outside every hub")
func rivalBuildsAMarketplaceBeyondItsReach() throws {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    let rival = try #require(world.rival(1))
    let center = try #require(world.buildings[rival.townCenterID]).anchor
    openBlocks(around: center, upTo: 3, in: &world)
    takeHousePlotsInReach(around: center, in: &world)
    world.setRivalStock(1, [.wood: 20, .planks: 20, .food: 20])
    world.setRival(1) { $0.treasury = 100_000 }
    let commands = world.takeTurn(1)
    #expect(commands.contains { if case .rivalPlace(1, .marketplace, _) = $0 { true } else { false } })
}
