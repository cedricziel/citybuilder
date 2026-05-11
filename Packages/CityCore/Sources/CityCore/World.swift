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

    /// Coordinates currently claimed by a building footprint. Buildings are
    /// modeled as opaque entity IDs for M1; full catalog arrives in M3.
    public internal(set) var occupiedTiles: [TileCoordinate: EntityID]
    /// Buildings keyed by EntityID. Construction state lives here.
    public internal(set) var buildings: [EntityID: Building] = [:]
    /// Per-building stockpiles. Warehouses, producers, and consumers all
    /// participate via the same Stockpile type.
    public internal(set) var stockpiles: [EntityID: Stockpile] = [:]
    /// Connectivity graph over road tiles. Updated incrementally by
    /// place(.road) and demolish on road tiles.
    public internal(set) var roadGraph: RoadGraph = .init()
    /// Next entity ID to allocate. Auto-increments deterministically as
    /// buildings are placed.
    public internal(set) var nextEntityRaw: UInt32 = 1

    /// ---- pending player commands ----------------------------------
    public internal(set) var pendingCommands: [Command]

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

    public func canPlace(_ kind: BuildingKind, at anchor: TileCoordinate) -> PlacementResult {
        let spec = BuildingCatalog.spec(for: kind)
        for tile in spec.footprint.tiles(anchor: anchor) {
            guard contains(tile) else { return .rejected(.outOfBounds) }
            if occupiedTiles[tile] != nil { return .rejected(.tileOccupied) }
            let terrainHere = terrain(at: tile) ?? .water
            if terrainHere == .water { return .rejected(.terrainNotBuildable) }
        }
        return .allowed
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
    public mutating func tick() -> TickMetrics {
        let startNanos = currentMonotonicNanoseconds()

        let drained = pendingCommands
        pendingCommands.removeAll(keepingCapacity: true)
        for command in drained {
            apply(command)
        }
        advanceBuildings()
        tickCount &+= 1
        simulatedTime += .tick

        let endNanos = currentMonotonicNanoseconds()
        let elapsed = endNanos > startNanos ? endNanos - startNanos : 0
        return TickMetrics(wallClockNanoseconds: elapsed)
    }

    private mutating func advanceBuildings() {
        for (id, building) in buildings where building.state == .constructing {
            var updated = building
            updated.ticksSincePlacement &+= 1
            let spec = BuildingCatalog.spec(for: building.kind)
            if updated.ticksSincePlacement >= spec.buildDurationTicks {
                updated.state = .operational
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

    private mutating func apply(_ command: Command) {
        switch command {
        case .noop:
            return
        case let .harvestForest(coord):
            // Forests becoming grass when harvested per spec
            // `world-terrain` ("Forest tile can be cleared").
            guard contains(coord), terrain(at: coord) == .forest else { return }
            terrainGrid[coord.y * mapWidth + coord.x] = .grass
        case let .place(kind, anchor):
            applyPlace(kind: kind, anchor: anchor)
        case let .demolish(anchor):
            applyDemolish(anchor: anchor)
        }
    }

    private mutating func applyPlace(kind: BuildingKind, anchor: TileCoordinate) {
        guard case .allowed = canPlace(kind, at: anchor) else { return }
        let spec = BuildingCatalog.spec(for: kind)
        let id = EntityID(raw: nextEntityRaw)
        nextEntityRaw &+= 1
        let initialState: BuildingState = spec.buildDurationTicks == 0 ? .operational : .constructing
        let building = Building(id: id, kind: kind, anchor: anchor, state: initialState)
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
    }

    /// Default stockpile capacity per building kind. nil means "this kind
    /// has no stockpile" — e.g. roads and the town center.
    private static func stockpileCapacity(for kind: BuildingKind) -> Int? {
        switch kind {
        case .warehouse: 200
        case .lumberjackHut, .sawmill: 16
        case .house, .townCenter: 8
        case .road: nil
        }
    }

    private mutating func applyDemolish(anchor: TileCoordinate) {
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
    }
}
