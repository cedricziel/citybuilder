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

    /// ---- pending player commands ----------------------------------
    public internal(set) var pendingCommands: [Command]

    /// ---- tick instrumentation -------------------------------------
    public struct TickMetrics: Codable, Sendable, Equatable {
        public let wallClockNanoseconds: UInt64
        public init(wallClockNanoseconds: UInt64) {
            self.wallClockNanoseconds = wallClockNanoseconds
        }
    }

    public internal(set) var lastTickMetrics: TickMetrics?

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
        self.lastTickMetrics = nil
    }

    /// ---- terrain queries ------------------------------------------
    public func contains(_ coord: TileCoordinate) -> Bool {
        coord.x >= 0 && coord.x < mapWidth && coord.y >= 0 && coord.y < mapHeight
    }

    public func terrain(at coord: TileCoordinate) -> TerrainType? {
        guard contains(coord) else { return nil }
        return terrainGrid[coord.y * mapWidth + coord.x]
    }

    public func canPlace(_: BuildingKind, at coord: TileCoordinate) -> PlacementResult {
        guard contains(coord) else { return .rejected(.outOfBounds) }
        if occupiedTiles[coord] != nil { return .rejected(.tileOccupied) }
        let terrainHere = terrain(at: coord) ?? .water
        if terrainHere == .water { return .rejected(.terrainNotBuildable) }
        return .allowed
    }

    /// ---- command queue --------------------------------------------
    public mutating func enqueue(_ command: Command) {
        pendingCommands.append(command)
    }

    /// ---- tick -----------------------------------------------------
    public mutating func tick() {
        // M1 STUB: real systems run here. Until M1 task 2.3 ships, this
        // only advances tickCount and simulatedTime and drains the
        // command queue without applying effects.
        let drained = pendingCommands
        pendingCommands.removeAll(keepingCapacity: true)
        for command in drained {
            apply(command)
        }
        tickCount &+= 1
        simulatedTime += .tick
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
        }
    }
}
