import Foundation

// Port + Shipyard behaviors layered on top of the base `Building` /
// `Stockpile` storage. Per spec `port-and-shipyard`.

public extension World {
    /// True when at least one tile of the building's connectivity face
    /// is orthogonally adjacent to a road tile. For shore buildings
    /// the connectivity face is `landFaceTiles`; for land-only
    /// buildings it's the full footprint.
    func isRoadConnected(building: Building) -> Bool {
        let connectivityTiles = building.landFaceTiles.isEmpty
            ? BuildingCatalog.spec(for: building.kind).footprint.tiles(anchor: building.anchor)
            : building.landFaceTiles
        for tile in connectivityTiles {
            for neighbor in orthogonalNeighbors(of: tile) where roadGraph.roadTiles.contains(neighbor) {
                return true
            }
        }
        return false
    }

    /// Building kinds that take carrier deliveries and supply house
    /// needs. Spec: `warehouses-and-logistics` / Goods buffer storage.
    static let logisticsBufferKinds: Set<BuildingKind> = [.warehouse, .port, .townCenter]

    /// Goods-buffer query — returns every warehouse, port and town
    /// center in the world, sorted by `EntityID.raw` so callers that
    /// pick "first equidistant buffer" get deterministic tie-breaking.
    /// Spec: `warehouses-and-logistics` / Deterministic tie-break.
    func goodsBuffers() -> [Building] {
        buildings.values
            .filter { Self.logisticsBufferKinds.contains($0.kind) }
            .sorted { $0.id.raw < $1.id.raw }
    }

    /// Factory: emit a fresh ship from the named shipyard, parked at
    /// the shipyard's water-side tile in `.idle` state with empty
    /// cargo. Returns the new `EntityID`, or nil if the shipyard does
    /// not exist or has no sea-face tile. The M5 tick system will
    /// call this when a shipyard recipe completes; tests can also
    /// invoke it directly.
    @discardableResult
    mutating func emitShip(fromShipyard shipyardID: EntityID) -> EntityID? {
        guard let shipyard = buildings[shipyardID], shipyard.kind == .shipyard else { return nil }
        guard let waterTile = shipyard.seaFaceTiles.first else { return nil }
        let id = EntityID(raw: nextEntityRaw)
        nextEntityRaw &+= 1
        ships[id] = Ship(
            id: id,
            position: Fixed2D(x: Fixed(Int32(waterTile.x)), y: Fixed(Int32(waterTile.y))),
            heading: .zero,
            routeID: nil,
            waypointIdx: 0,
            cargo: [:],
            state: .idle,
            shipClass: .default,
            owner: shipyard.owner
        )
        return id
    }

    private func orthogonalNeighbors(of tile: TileCoordinate) -> [TileCoordinate] {
        [
            TileCoordinate(x: tile.x - 1, y: tile.y),
            TileCoordinate(x: tile.x + 1, y: tile.y),
            TileCoordinate(x: tile.x, y: tile.y - 1),
            TileCoordinate(x: tile.x, y: tile.y + 1)
        ]
    }
}
