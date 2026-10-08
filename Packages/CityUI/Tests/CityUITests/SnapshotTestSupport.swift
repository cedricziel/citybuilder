import CityCore

/// `base` with its house populations (and optionally its culture) replaced.
func withHousePopulations(
    _ base: WorldSnapshot, _ pops: [EntityID: HousePopulation], culture: Culture? = nil
) -> WorldSnapshot {
    WorldSnapshot(
        tickCount: base.tickCount, simulatedTime: base.simulatedTime, mapWidth: base.mapWidth, mapHeight: base.mapHeight,
        terrainGrid: base.terrainGrid, occupiedTiles: base.occupiedTiles, buildings: base.buildings, carriers: base.carriers,
        ships: base.ships, routes: base.routes, economy: base.economy, totalPopulation: base.totalPopulation, camera: base.camera,
        islandSummaries: base.islandSummaries, roadDisconnectedBuildings: base.roadDisconnectedBuildings,
        housePopulations: pops, culture: culture ?? base.culture
    )
}
