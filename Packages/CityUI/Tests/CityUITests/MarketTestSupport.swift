@testable import CityCore

/// A grass strip with a road along y = 3 and a player town center at (0, 0),
/// whose road side runs to x = 2: a house at (x, 4) sits x - 2 road tiles
/// from it.
func marketStrip() -> (World, EntityID) {
    var world = World.fixtureWithTerrain(width: 44, height: 9, fill: .grass, seed: 1)
    world.culture = .northernEuropean
    for x in 0 ... 43 {
        let tile = TileCoordinate(x: x, y: 3)
        _ = placeOperational(.road, at: tile, in: &world)
        world.roadGraph.addRoad(at: tile)
    }
    let hub = placeOperational(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world)
    return (world, hub)
}

/// Puts an operational building at `anchor` without construction; a house
/// gets `residents` peasants.
@discardableResult
func placeOperational(
    _ kind: BuildingKind, at anchor: TileCoordinate, residents: UInt32 = 0, owner: Owner = .player, in world: inout World
) -> EntityID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.buildings[id] = Building(id: id, kind: kind, anchor: anchor, state: .operational, owner: owner)
    for tile in BuildingCatalog.spec(for: kind).footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    world.stockpiles[id] = World.newStockpile(for: kind)
    if kind == .house {
        var population = HousePopulation()
        population.population = residents
        world.populations[id] = population
    }
    return id
}
