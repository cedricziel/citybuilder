import Foundation

/// Totals since the game started that goals read and the world state
/// alone can't give. Spec: `difficulty-and-goals` / More goal kinds.
public struct GoalCounters: Hashable, Codable, Sendable {
    /// Money from selling at the town market and at rival ports.
    public internal(set) var tradeEarnings: Int64 = 0
    /// Units unloaded from player ships into player ports on the home island.
    public internal(set) var landedAtHome: [Good: Int] = [:]
    /// Monuments completed and gallery commissions run to their end.
    public internal(set) var signatureProjects = 0

    public init() {}
}

extension World {
    /// Reads the tick's events for the scenario: counts trade sales and
    /// finished signature projects, and loses a scenario to bankruptcy.
    /// Caravan income and tax are not trade earnings.
    mutating func runScenarioRecords(events: inout [WorldEvent]) {
        for event in events {
            switch event {
            case .gameOver:
                loseScenario(.bankruptcy, events: &events)
            case let .marketTraded(_, _, total, .sold), let .tradeCompleted(_, _, _, total, .sold):
                goalCounters.tradeEarnings += total
            case let .monumentCompleted(building), let .commissionEnded(building):
                if owner(of: building) == .player {
                    goalCounters.signatureProjects += 1
                }
            default:
                break
            }
        }
    }

    /// Counts goods a player ship unloaded into `port`, when the port is
    /// the player's and on the home island.
    mutating func recordLanding(_ good: Good, _ amount: Int, ship: Ship, port: Building) {
        guard ship.owner == .player, port.owner == .player else { return }
        let map = tileToIslandMap()
        guard let home = homeIslandID(in: map), islandFor(building: port, tileToIsland: map) == home else { return }
        goalCounters.landedAtHome[good, default: 0] += amount
    }

    /// The island under the map's centre tile, else the largest: where the
    /// player's home town center stands.
    func homeIslandID(in map: [TileCoordinate: IslandID]) -> IslandID? {
        map[TileCoordinate(x: mapWidth / 2, y: mapHeight / 2)]
            ?? islands.max { ($0.tileCount, -Int($0.id)) < ($1.tileCount, -Int($1.id)) }?.id
    }
}
