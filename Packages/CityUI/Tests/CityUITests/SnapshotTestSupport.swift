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

/// `base` with its trees or open grass in reach replaced by `counts`.
func withCatchments(_ base: WorldSnapshot, _ counts: [EntityID: Int]) -> WorldSnapshot {
    WorldSnapshot(
        tickCount: base.tickCount, simulatedTime: base.simulatedTime, mapWidth: base.mapWidth, mapHeight: base.mapHeight,
        terrainGrid: base.terrainGrid, occupiedTiles: base.occupiedTiles, buildings: base.buildings, carriers: base.carriers,
        ships: base.ships, routes: base.routes, economy: base.economy, totalPopulation: base.totalPopulation, camera: base.camera,
        islandSummaries: base.islandSummaries, roadDisconnectedBuildings: base.roadDisconnectedBuildings,
        buildingIssues: base.buildingIssues, catchments: counts, housePopulations: base.housePopulations,
        date: base.date, culture: base.culture, age: base.age
    )
}

/// `base` with its building issues replaced by `issues`.
func withBuildingIssues(_ base: WorldSnapshot, _ issues: [EntityID: BuildingIssue]) -> WorldSnapshot {
    WorldSnapshot(
        tickCount: base.tickCount, simulatedTime: base.simulatedTime, mapWidth: base.mapWidth, mapHeight: base.mapHeight,
        terrainGrid: base.terrainGrid, occupiedTiles: base.occupiedTiles, buildings: base.buildings, carriers: base.carriers,
        ships: base.ships, routes: base.routes, economy: base.economy, totalPopulation: base.totalPopulation, camera: base.camera,
        islandSummaries: base.islandSummaries, roadDisconnectedBuildings: base.roadDisconnectedBuildings,
        buildingIssues: issues, catchments: base.catchments, housePopulations: base.housePopulations,
        date: base.date, culture: base.culture, age: base.age
    )
}
