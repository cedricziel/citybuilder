import Foundation
@testable import CityCore

/// Shared setup for the add-age-signatures scenarios.
enum SignatureFixture {
    static func grass(width: Int = 40, height: Int = 30) -> World {
        var world = World.fixtureWithTerrain(width: width, height: height, fill: .grass, seed: 1)
        world.economy.credit(100_000)
        return world
    }

    /// Puts a building straight into the world, skipping placement and
    /// construction.
    @discardableResult
    static func inject(
        _ kind: BuildingKind,
        at anchor: TileCoordinate,
        in world: inout World,
        state: BuildingState = .operational
    ) -> EntityID {
        let id = EntityID(raw: world.nextEntityRaw)
        world.nextEntityRaw &+= 1
        world.buildings[id] = Building(id: id, kind: kind, anchor: anchor, state: state)
        for tile in BuildingCatalog.spec(for: kind).footprint.tiles(anchor: anchor) {
            world.occupiedTiles[tile] = id
        }
        if let capacity = World.stockpileCapacity(for: kind) {
            world.stockpiles[id] = Stockpile(capacity: capacity)
        }
        return id
    }

    /// First anchor whose footprint lies on free grass.
    static func freeAnchor(for kind: BuildingKind, in world: World) -> TileCoordinate? {
        let footprint = BuildingCatalog.spec(for: kind).footprint
        for y in 0 ..< world.mapHeight {
            for x in 0 ..< world.mapWidth {
                let anchor = TileCoordinate(x: x, y: y)
                let fits = footprint.tiles(anchor: anchor).allSatisfy {
                    world.terrain(at: $0) == .grass && world.occupiedTiles[$0] == nil
                }
                if fits { return anchor }
            }
        }
        return nil
    }

    /// A sawmill with wood for many cycles.
    static func suppliedSawmill(at anchor: TileCoordinate, in world: inout World) -> EntityID {
        let id = inject(.sawmill, at: anchor, in: &world)
        world.stockpiles[id]?.deposit(.wood, amount: 8)
        return id
    }

    /// A fuelled building with fuel for many burns: charcoal for a steam
    /// engine or power plant, the luxury for a culture signature.
    @discardableResult
    static func fuelled(_ kind: BuildingKind, at anchor: TileCoordinate, in world: inout World) -> EntityID {
        let id = inject(kind, at: anchor, in: &world)
        world.buildings[id]?.fuelled = true
        if let fuel = kind.fuel {
            world.stockpiles[id]?.deposit(fuel.good, amount: 12)
        }
        return id
    }

    /// Ticks until `producer` completes its next cycle, starting from a
    /// fresh cycle.
    static func cycleTicks(of producer: EntityID, in world: inout World, limit: Int = 200) -> Int {
        world.productions[producer] = ProductionProgress()
        guard let kind = world.buildings[producer]?.kind else { return -1 }
        for elapsed in 1 ... limit {
            let events = world.tick().events
            if events.contains(.productionCycleCompleted(producer: producer, kind: kind)) {
                return elapsed
            }
        }
        return -1
    }

    static func run(_ world: inout World, ticks: Int) -> [WorldEvent] {
        var events: [WorldEvent] = []
        for _ in 0 ..< ticks {
            events += world.tick().events
        }
        return events
    }

    /// Ticks until the next tick will have a count that is a multiple
    /// of `interval`.
    static func runUntilBefore(multipleOf interval: UInt64, in world: inout World) {
        while !(world.tickCount + 1).isMultiple(of: interval) {
            world.tick()
        }
    }
}
