import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/fix-mac-playtest-findings:
// buildings-and-construction / Town center starter road.

private func ring(around anchor: TileCoordinate) -> [TileCoordinate] {
    let footprint = BuildingCatalog.spec(for: .townCenter).footprint
    var tiles: [TileCoordinate] = []
    for y in anchor.y - 1 ... anchor.y + footprint.height {
        for x in anchor.x - 1 ... anchor.x + footprint.width {
            let onEdge = x == anchor.x - 1 || x == anchor.x + footprint.width
                || y == anchor.y - 1 || y == anchor.y + footprint.height
            if onEdge { tiles.append(TileCoordinate(x: x, y: y)) }
        }
    }
    return tiles
}

@Test("scenario: fresh-world town center starts ringed by road")
func scenarioFreshWorldTownCenterStartsRingedByRoad() throws {
    let world = World.newGame()
    let center = try #require(world.buildings.values.first { $0.kind == .townCenter })
    for tile in ring(around: center.anchor) where world.terrain(at: tile) != .water {
        #expect(world.roadGraph.isConnected(tile), "missing road at \(tile)")
        let id = try #require(world.occupiedTiles[tile])
        #expect(world.buildings[id]?.kind == .road)
        #expect(world.buildings[id]?.owner == .player)
    }
    #expect(!world.snapshot().roadDisconnectedBuildings.contains(center.id))
}

@Test("scenario: the starter road is free")
func scenarioTheStarterRoadIsFree() {
    let world = World.newGame()
    #expect(world.economy.balance == Difficulty.normal.startingBalance)
}

@Test("scenario: rival town centers get no starter road")
func scenarioRivalTownCentersGetNoStarterRoad() throws {
    let world = World.newGame(layout: .archipelago, seed: 5)
    let rival = try #require(world.rivals.first)
    let center = try #require(world.buildings[rival.townCenterID])
    for tile in ring(around: center.anchor) {
        #expect(!world.roadGraph.isConnected(tile))
    }
}
