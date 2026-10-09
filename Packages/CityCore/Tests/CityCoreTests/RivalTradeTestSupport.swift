@testable import CityCore

// Shared fixture for the `add-rival-trade` tests.

/// Two islands across open water: the player's to the west (x 0…3) and
/// rival 1's to the east (x 20…23), each with a port on the facing
/// shore. Rival 1 owns a town center and a warehouse, both empty.
struct TradeFixture {
    var world: World
    let playerPort: EntityID
    let rivalPort: EntityID
    let townCenter: EntityID
    let warehouse: EntityID

    init(treasury: Int64 = 1000) {
        var world = World.fixtureWithTerrain(width: 24, height: 10, fill: .water, seed: 7)
        world.testMaterialCredits = [:]
        for y in 0 ..< world.mapHeight {
            for x in [0, 1, 2, 3, 20, 21, 22, 23] {
                world.terrainGrid[y * world.mapWidth + x] = .grass
            }
        }
        world.islands = IslandDetector.detectIslands(
            width: world.mapWidth, height: world.mapHeight, terrain: world.terrainGrid,
            mapHeightForClimate: world.mapHeight, seed: 7
        )
        let east = world.tileToIslandMap()[TileCoordinate(x: 21, y: 5)] ?? 0
        let rival = Owner.rival(1)
        townCenter = world.testPlace(.townCenter, at: TileCoordinate(x: 21, y: 6), owner: rival)
        warehouse = world.testPlace(.warehouse, at: TileCoordinate(x: 21, y: 1), owner: rival)
        playerPort = world.testPlace(.port, at: TileCoordinate(x: 3, y: 1), owner: .player)
        rivalPort = world.testPlace(.port, at: TileCoordinate(x: 19, y: 1), owner: rival)
        world.rivals = [RivalTown(
            id: 1, name: "Ravenshore", islandID: east, culture: .mediterranean, colour: .crimson,
            age: world.age, treasury: treasury, townCenterID: townCenter, ai: RivalAIState()
        )]
        self.world = world
    }

    /// Replaces the stock of one of the rival's buffers.
    mutating func setStock(_ stock: [Good: Int], in buffer: EntityID? = nil) {
        world.testSetStock(stock, in: buffer ?? warehouse)
    }

    /// A player ship docked at `port` on a route between both ports,
    /// with `actions` as that port's manifest.
    @discardableResult
    mutating func dockShip(at port: EntityID, actions: [ManifestAction], cargo: [Good: Int] = [:]) -> EntityID {
        let routeID = EntityID(raw: world.nextEntityRaw)
        let shipID = EntityID(raw: world.nextEntityRaw + 1)
        world.nextEntityRaw &+= 2
        world.routes[routeID] = Route(
            id: routeID, waypoints: [.port(id: playerPort), .port(id: rivalPort)],
            manifest: [port: actions], speed: .one, state: .active
        )
        let anchor = world.buildings[port]?.shipAnchor ?? TileCoordinate(x: 0, y: 0)
        world.ships[shipID] = Ship(
            id: shipID, position: Fixed2D(x: Fixed(Int32(anchor.x)), y: Fixed(Int32(anchor.y))),
            heading: .zero, routeID: routeID, waypointIdx: port == playerPort ? 0 : 1,
            cargo: cargo, state: .docked, shipClass: .default
        )
        return shipID
    }

    /// Runs the ship system once and returns its events.
    mutating func dock() -> [WorldEvent] {
        var events: [WorldEvent] = []
        world.runShipSystem(events: &events)
        return events
    }

    var treasury: Int64 {
        world.rival(1)?.treasury ?? 0
    }
}

extension World {
    /// Inserts an operational building, with shore faces and a stockpile
    /// where its kind has them, bypassing placement rules.
    @discardableResult
    mutating func testPlace(_ kind: BuildingKind, at anchor: TileCoordinate, owner: Owner) -> EntityID {
        let id = EntityID(raw: nextEntityRaw)
        nextEntityRaw &+= 1
        let spec = BuildingCatalog.spec(for: kind)
        let faces = spec.shorePlacement == nil ? ([], []) : classifyFootprint(kind: kind, anchor: anchor)
        buildings[id] = Building(
            id: id, kind: kind, anchor: anchor, state: .operational,
            landFaceTiles: faces.0, seaFaceTiles: faces.1,
            shipAnchor: kind == .port ? faces.1.first : nil, owner: owner
        )
        for tile in spec.footprint.tiles(anchor: anchor) {
            occupiedTiles[tile] = id
        }
        if let capacity = Self.stockpileCapacity(for: kind) {
            stockpiles[id] = Stockpile(capacity: capacity)
        }
        return id
    }
}
