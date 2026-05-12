import Foundation

/// The full simulation state. Codable end-to-end so saves are snapshots
/// (design D6 + spec `simulation-core`).
///
/// M1 STUB: many properties exist but contain placeholder values until the
/// tests-first cycle drives real implementations. Methods that have not
/// been implemented yet trap with `fatalError`; behavior under test will
/// surface as expectation failures rather than crashes only once methods
/// return values.
public struct World: Codable, Sendable, Equatable {
    /// ---- identity --------------------------------------------------
    public let seed: UInt64

    // ---- time ------------------------------------------------------
    public private(set) var tickCount: UInt64
    public private(set) var simulatedTime: SimulationDuration

    /// ---- RNG -------------------------------------------------------
    public internal(set) var rng: DeterministicRNG

    // ---- map -------------------------------------------------------
    public let mapWidth: Int
    public let mapHeight: Int
    /// Row-major terrain grid of length mapWidth * mapHeight.
    public internal(set) var terrainGrid: [TerrainType]
    /// Named topology chosen at new-game creation. Persisted with
    /// the world; loaded saves restore the original choice.
    public internal(set) var layout: WorldLayout = .singleIsland
    /// Derived island metadata — one entry per maximal connected
    /// component of non-water buildable tiles. Recomputed only when
    /// terrain changes; serialized so `IslandID` values stay stable
    /// across save/load.
    public internal(set) var islands: [Island] = []

    /// Coordinates currently claimed by a building footprint. Buildings are
    /// modeled as opaque entity IDs for M1; full catalog arrives in M3.
    public internal(set) var occupiedTiles: [TileCoordinate: EntityID]
    /// Buildings keyed by EntityID. Construction state lives here.
    public internal(set) var buildings: [EntityID: Building] = [:]
    /// Per-building stockpiles. Warehouses, producers, and consumers all
    /// participate via the same Stockpile type.
    public internal(set) var stockpiles: [EntityID: Stockpile] = [:]
    /// Per-producer production progress.
    public internal(set) var productions: [EntityID: ProductionProgress] = [:]
    /// Per-house population state.
    public internal(set) var populations: [EntityID: HousePopulation] = [:]
    /// In-flight carriers keyed by ID.
    public internal(set) var carriers: [EntityID: Carrier] = [:]
    /// Counter for carrier in-flight count per producer.
    public internal(set) var carrierCountByProducer: [EntityID: Int] = [:]
    /// Sea entities. Continuous-position, integrated each tick by the
    /// `tickShips` system (spec `sea-transport`).
    public internal(set) var ships: [EntityID: Ship] = [:]
    /// Persistent route entities. Outlive ships — a route remains in
    /// the world after every assigned ship is destroyed and can be
    /// re-assigned later.
    public internal(set) var routes: [EntityID: Route] = [:]
    /// Connectivity graph over road tiles. Updated incrementally by
    /// place(.road) and demolish on road tiles.
    public internal(set) var roadGraph: RoadGraph = .init()
    /// Next entity ID to allocate. Auto-increments deterministically as
    /// buildings are placed.
    public internal(set) var nextEntityRaw: UInt32 = 1

    /// ---- pending player commands ----------------------------------
    public internal(set) var pendingCommands: [Command]

    /// ---- economy ---------------------------------------------------
    public internal(set) var economy: Economy = .init()

    /// ---- view state (persisted with the save) ---------------------
    public var camera: Camera

    /// Tick metrics are observability output, not part of the deterministic
    /// world state. They are returned by `tick()` rather than stored on
    /// World so two simulations with identical inputs remain Equatable
    /// regardless of wall-clock noise.
    public struct TickMetrics: Sendable, Equatable {
        public let wallClockNanoseconds: UInt64
        public init(wallClockNanoseconds: UInt64) {
            self.wallClockNanoseconds = wallClockNanoseconds
        }
    }

    /// Aggregate return value of `tick()`: the existing wall-clock metrics
    /// plus a transient `[WorldEvent]` produced during the tick. Events are
    /// not Codable and are not persisted; they exist only for the lifetime
    /// of the returned `TickResult` so downstream layers (audio, analytics)
    /// can react to what happened. Per spec `world-events`.
    public struct TickResult: Sendable, Equatable {
        public let metrics: TickMetrics
        public let events: [WorldEvent]
        public init(metrics: TickMetrics, events: [WorldEvent]) {
            self.metrics = metrics
            self.events = events
        }
    }

    /// ---- construction ---------------------------------------------
    public init(seed: UInt64) {
        self.init(seed: seed, mapWidth: 0, mapHeight: 0, terrainGrid: [])
    }

    init(seed: UInt64, mapWidth: Int, mapHeight: Int, terrainGrid: [TerrainType]) {
        precondition(terrainGrid.count == mapWidth * mapHeight, "terrainGrid size must equal width × height")
        self.seed = seed
        self.tickCount = 0
        self.simulatedTime = .zero
        self.rng = DeterministicRNG(seed: seed)
        self.mapWidth = mapWidth
        self.mapHeight = mapHeight
        self.terrainGrid = terrainGrid
        self.occupiedTiles = [:]
        self.pendingCommands = []
        self.camera = Camera(
            centerX: Double(mapWidth) / 2,
            centerY: Double(mapHeight) / 2,
            zoom: 1.0
        )
    }

    /// ---- terrain queries ------------------------------------------
    public func contains(_ coord: TileCoordinate) -> Bool {
        coord.x >= 0 && coord.x < mapWidth && coord.y >= 0 && coord.y < mapHeight
    }

    public func terrain(at coord: TileCoordinate) -> TerrainType? {
        guard contains(coord) else { return nil }
        return terrainGrid[coord.y * mapWidth + coord.x]
    }

    /// Returns the `IslandID` of the island whose buildable tiles
    /// contain `coord`, or `nil` for water tiles outside any island.
    /// Re-runs the connected-component detector — placement validation
    /// is rare enough to absorb the cost; the snapshot path caches its
    /// own copy of the map for the renderer.
    public func islandID(at coord: TileCoordinate) -> IslandID? {
        guard contains(coord) else { return nil }
        let map = IslandDetector.detect(
            width: mapWidth,
            height: mapHeight,
            terrain: terrainGrid,
            mapHeightForClimate: mapHeight,
            seed: seed
        ).tileToIsland
        return map[coord]
    }

    public func canPlace(_ kind: BuildingKind, at anchor: TileCoordinate) -> PlacementResult {
        let spec = BuildingCatalog.spec(for: kind)
        let tiles = spec.footprint.tiles(anchor: anchor)
        var landCount = 0
        var waterCount = 0
        for tile in tiles {
            guard contains(tile) else { return .rejected(.outOfBounds) }
            if occupiedTiles[tile] != nil { return .rejected(.tileOccupied) }
            let terrainHere = terrain(at: tile) ?? .water
            if terrainHere == .water {
                if spec.shorePlacement == nil {
                    return .rejected(.terrainNotBuildable)
                }
                waterCount += 1
            } else {
                landCount += 1
            }
        }
        if let shore = spec.shorePlacement {
            if landCount < shore.minLandTiles { return .rejected(.shoreRequiresLandTile) }
            if waterCount < shore.minWaterTiles { return .rejected(.shoreRequiresWaterTile) }
        }
        return .allowed
    }

    /// Classifies a candidate building's footprint into land-face and
    /// sea-face tiles at placement time. Order-preserving (footprint
    /// tile iteration order) so the result is deterministic.
    func classifyFootprint(
        kind: BuildingKind, anchor: TileCoordinate
    ) -> (land: [TileCoordinate], sea: [TileCoordinate]) {
        let spec = BuildingCatalog.spec(for: kind)
        var land: [TileCoordinate] = []
        var sea: [TileCoordinate] = []
        for tile in spec.footprint.tiles(anchor: anchor) {
            let terrainHere = terrain(at: tile) ?? .water
            if terrainHere == .water {
                sea.append(tile)
            } else {
                land.append(tile)
            }
        }
        return (land, sea)
    }

    /// ---- command queue --------------------------------------------
    public mutating func enqueue(_ command: Command) {
        pendingCommands.append(command)
    }

    /// Advances the simulation by one fixed tick (100 ms). Drains the
    /// pending-command queue at the boundary, applies each command, then
    /// returns observability metrics (wall-clock elapsed nanoseconds) so
    /// render layers and CI perf gates can observe per-tick cost without
    /// polluting the deterministic world state.
    @discardableResult
    public mutating func tick() -> TickResult {
        let startNanos = currentMonotonicNanoseconds()

        // Per-tick event scratch buffer. Local — not stored on World, per
        // `world-events` spec ("Events not in World"). Each system threads
        // it through via `inout` and appends emissions as side effects.
        var events: [WorldEvent] = []

        let drained = pendingCommands
        pendingCommands.removeAll(keepingCapacity: true)
        for command in drained {
            apply(command, events: &events)
        }
        tickCount &+= 1
        simulatedTime += .tick
        advanceBuildings(events: &events)
        runProductionSystem(events: &events)
        runCarrierSystem(events: &events)
        runShipSystem()
        runPopulationSystem()
        runEconomySystem(events: &events)

        let endNanos = currentMonotonicNanoseconds()
        let elapsed = endNanos > startNanos ? endNanos - startNanos : 0
        return TickResult(
            metrics: TickMetrics(wallClockNanoseconds: elapsed),
            // Stable sort guarantees byte-identical event sequences across
            // replays regardless of `Dictionary` iteration order in systems.
            events: events.stablySortedForEmission()
        )
    }

    private mutating func advanceBuildings(events: inout [WorldEvent]) {
        for (id, building) in buildings where building.state == .constructing {
            var updated = building
            updated.ticksSincePlacement &+= 1
            let spec = BuildingCatalog.spec(for: building.kind)
            if updated.ticksSincePlacement >= spec.buildDurationTicks {
                updated.state = .operational
                events.append(.constructionCompleted(
                    building: id,
                    kind: building.kind,
                    anchor: building.anchor
                ))
            }
            buildings[id] = updated
        }
    }

    /// Monotonic clock reading in nanoseconds. Built on `DispatchTime` so it
    /// works identically on Apple platforms and Linux (Dispatch is part of
    /// swift-corelibs-libdispatch). Not affected by wall-clock adjustments.
    private func currentMonotonicNanoseconds() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    private mutating func apply(_ command: Command, events: inout [WorldEvent]) {
        switch command {
        case .noop:
            return
        case let .harvestForest(coord):
            // Forests becoming grass when harvested per spec
            // `world-terrain` ("Forest tile can be cleared").
            guard contains(coord), terrain(at: coord) == .forest else { return }
            terrainGrid[coord.y * mapWidth + coord.x] = .grass
            events.append(.forestHarvested(at: coord))
        case let .place(kind, anchor):
            applyPlace(kind: kind, anchor: anchor, events: &events)
        case let .demolish(anchor):
            applyDemolish(anchor: anchor, events: &events)
        case let .createRoute(waypoints, manifest, speed):
            applyCreateRoute(waypoints: waypoints, manifest: manifest, speed: speed)
        case let .editRoute(id, waypoints, manifest):
            applyEditRoute(id: id, waypoints: waypoints, manifest: manifest)
        case let .deleteRoute(id):
            applyDeleteRoute(id: id)
        case let .assignShipToRoute(shipID, routeID):
            applyAssignShipToRoute(shipID: shipID, routeID: routeID)
        case let .unassignShip(shipID):
            applyUnassignShip(shipID: shipID)
        }
    }

    private mutating func applyPlace(
        kind: BuildingKind,
        anchor: TileCoordinate,
        events: inout [WorldEvent]
    ) {
        guard case .allowed = canPlace(kind, at: anchor) else {
            events.append(.placementRejected(kind: kind, anchor: anchor))
            return
        }
        let spec = BuildingCatalog.spec(for: kind)
        // Insufficient funds rejects the placement (spec economy).
        if economy.balance < spec.cost {
            events.append(.placementRejected(kind: kind, anchor: anchor))
            return
        }
        economy.deduct(spec.cost)
        let id = EntityID(raw: nextEntityRaw)
        nextEntityRaw &+= 1
        let initialState: BuildingState = spec.buildDurationTicks == 0 ? .operational : .constructing
        let (landFace, seaFace): ([TileCoordinate], [TileCoordinate])
        let shipAnchor: TileCoordinate?
        if spec.shorePlacement != nil {
            let classified = classifyFootprint(kind: kind, anchor: anchor)
            landFace = classified.land
            seaFace = classified.sea
            // Anchor selection: first sea-face tile in deterministic
            // footprint iteration order. Ports use it for docking;
            // other shore buildings may ignore it.
            shipAnchor = (kind == .port) ? seaFace.first : nil
        } else {
            landFace = []
            seaFace = []
            shipAnchor = nil
        }
        let building = Building(
            id: id, kind: kind, anchor: anchor, state: initialState,
            landFaceTiles: landFace, seaFaceTiles: seaFace, shipAnchor: shipAnchor
        )
        buildings[id] = building
        for tile in spec.footprint.tiles(anchor: anchor) {
            occupiedTiles[tile] = id
        }
        if kind == .road {
            roadGraph.addRoad(at: anchor)
        }
        if let capacity = Self.stockpileCapacity(for: kind) {
            stockpiles[id] = Stockpile(capacity: capacity)
        }
        events.append(.buildingPlaced(building: id, kind: kind, anchor: anchor))
    }

    /// Default stockpile capacity per building kind. nil means "this kind
    /// has no stockpile" — e.g. roads and the town center.
    private static func stockpileCapacity(for kind: BuildingKind) -> Int? {
        switch kind {
        case .warehouse: 200
        case .lumberjackHut, .sawmill: 16
        case .house, .townCenter: 8
        case .road: nil
        case .port: 200
        case .shipyard: 64
        }
    }

    private mutating func applyDemolish(anchor: TileCoordinate, events: inout [WorldEvent]) {
        guard let id = occupiedTiles[anchor],
              let building = buildings[id]
        else { return }
        // Anchor lookup uses the literal tile — but multi-tile buildings
        // resolve via the building's recorded anchor.
        let spec = BuildingCatalog.spec(for: building.kind)
        for tile in spec.footprint.tiles(anchor: building.anchor) {
            occupiedTiles.removeValue(forKey: tile)
        }
        buildings.removeValue(forKey: id)
        stockpiles.removeValue(forKey: id)
        if building.kind == .road {
            roadGraph.removeRoad(at: building.anchor)
        }
        // Port demolition: any route whose waypoints reference this
        // port transitions to `.broken(unknownPort)`, and every ship
        // currently assigned to such a route flips to `.returning`.
        // Spec: `port-and-shipyard` / Port and shipyard demolition.
        if building.kind == .port {
            for (routeID, route) in routes {
                let referencesPort = route.waypoints.contains { waypoint in
                    if case let .port(portID) = waypoint { return portID == id }
                    return false
                }
                guard referencesPort else { continue }
                routes[routeID]?.state = .broken(reason: .unknownPort(portID: id))
            }
            for (shipID, ship) in ships {
                guard let routeID = ship.routeID, routes[routeID]?.state != .active else {
                    continue
                }
                ships[shipID]?.state = .returning
            }
            // Second pass: any ship sailing a route that JUST became
            // broken on this demolish needs to flip too.
            for (shipID, ship) in ships {
                guard let routeID = ship.routeID,
                      case .broken = routes[routeID]?.state
                else { continue }
                ships[shipID]?.state = .returning
            }
        }
        events.append(.buildingDemolished(building: id, kind: building.kind, anchor: building.anchor))
    }
}
