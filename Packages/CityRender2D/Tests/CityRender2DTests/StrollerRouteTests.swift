import CityCore
import Testing
@testable import CityRender2D

// rendering-2_5d / Residents stroll the streets: routes follow the roads (#180).

/// A 14 × 14 meadow with a house at (5, 5) (tiles 5–6 × 5–6) and a second house beside it at (8, 5).
/// Roads run behind the houses (row 3) and in front (row 8), joined down column 2 and down column 7
/// between the houses, plus a stub on row 10 that no road reaches inside the first house's reach.
private func town() -> (WorldSnapshot, EntityID) {
    let base = World.fixtureWithTerrain(width: 14, height: 14, fill: .grass, seed: 1).snapshot()
    let home = Building(id: EntityID(raw: 1), kind: .house, anchor: TileCoordinate(x: 5, y: 5), state: .operational)
    var buildings = [home, Building(id: EntityID(raw: 2), kind: .house, anchor: TileCoordinate(x: 8, y: 5), state: .operational)]
    let roads = (2 ... 10).map { TileCoordinate(x: $0, y: 3) } + (2 ... 10).map { TileCoordinate(x: $0, y: 8) }
        + (4 ... 7).map { TileCoordinate(x: 2, y: $0) } + (4 ... 7).map { TileCoordinate(x: 7, y: $0) }
        + (6 ... 8).map { TileCoordinate(x: $0, y: 10) }
    for (index, tile) in roads.enumerated() {
        buildings.append(Building(id: EntityID(raw: UInt32(100 + index)), kind: .road, anchor: tile, state: .operational))
    }
    var occupied: [TileCoordinate: EntityID] = [:]
    for building in buildings {
        for tile in BuildingCatalog.spec(for: building.kind).footprint.tiles(anchor: building.anchor) {
            occupied[tile] = building.id
        }
    }
    var pop = HousePopulation()
    pop.population = 9
    let snapshot = WorldSnapshot(
        tickCount: 0, simulatedTime: base.simulatedTime, mapWidth: 14, mapHeight: 14, terrainGrid: base.terrainGrid,
        occupiedTiles: occupied, buildings: Dictionary(uniqueKeysWithValues: buildings.map { ($0.id, $0) }), carriers: [],
        economy: base.economy, totalPopulation: 0, camera: base.camera, housePopulations: [home.id: pop]
    )
    return (snapshot, home.id)
}

/// Every stroller the planner places in daylight over a long stretch of ticks.
private func daytimeStrollers(_ snapshot: WorldSnapshot) -> [StrollerPlanner.Stroller] {
    (UInt64(0) ..< 2400).filter { StrollerPlanner.residentsOut(atTick: $0) && $0 % 3 == 0 }.flatMap { tick in
        var shown = snapshot
        shown.tickCount = tick
        return StrollerPlanner.strollers(in: shown)
    }
}

@Test("scenario: Every stroller leg joins two neighbouring road tiles")
func everyLegJoinsNeighbouringRoads() {
    let (snapshot, _) = town()
    let roads = Set(snapshot.buildings.values.filter { $0.kind == .road }.map(\.anchor))
    let strollers = daytimeStrollers(snapshot)
    #expect(strollers.count > 100)
    for stroller in strollers {
        #expect(roads.contains(stroller.from) && roads.contains(stroller.to), "\(stroller)")
        #expect(abs(stroller.to.x - stroller.from.x) + abs(stroller.to.y - stroller.from.y) == 1, "\(stroller)")
    }
}

@Test("scenario: A stroller's feet never land on a building that is not a road")
func feetNeverLandOnAPlot() {
    let (snapshot, _) = town()
    for stroller in daytimeStrollers(snapshot) {
        for along in stride(from: 0.0, through: 1.0, by: 0.05) {
            let col = Double(stroller.from.x) + 0.5 + Double(stroller.to.x - stroller.from.x) * along
            let row = Double(stroller.from.y) + 0.5 + Double(stroller.to.y - stroller.from.y) * along
            let tile = TileCoordinate(x: Int(col.rounded(.down)), y: Int(row.rounded(.down)))
            let standing = snapshot.occupiedTiles[tile].flatMap { snapshot.buildings[$0]?.kind }
            #expect(standing == nil || standing == .road, "\(stroller) at \(along) stands on a \(String(describing: standing))")
        }
    }
}

@Test("a route is a road walk from the road nearest the house, the same every time")
func routesWalkTheRoadsFromTheNearestTile() throws {
    let (snapshot, home) = town()
    let house = try #require(snapshot.buildings[home])
    let roads = Set(snapshot.buildings.values.filter { $0.kind == .road }.map(\.anchor))
    let route = StrollerPlanner.nearbyRoads(of: house, in: roads)
    #expect(route.count > 1)
    // It starts on a road touching the house (column 7, beside its right side) and stays within reach,
    // never on the unconnected stub of row 10.
    #expect(route.first?.x == 7 && (5 ... 6).contains(route.first?.y ?? 0))
    #expect(!route.contains { $0.y == 10 })
    for (from, to) in zip(route, route.dropFirst()) {
        #expect(abs(to.x - from.x) + abs(to.y - from.y) == 1)
    }
    #expect(StrollerPlanner.nearbyRoads(of: house, in: roads) == route)
}
