import CityCore
import Foundation

/// Residents strolling the roads near their house. Drawn from the
/// snapshot, never simulated. Spec: `rendering-2_5d` / Residents stroll
/// the streets (design D4 of `add-city-life`).
public enum StrollerPlanner {
    public struct Stroller: Hashable, Sendable {
        public let house: EntityID
        public let slot: Int
        /// The stroller walks from `from` toward `to`; `progress` is 0…1.
        public let from: TileCoordinate
        public let to: TileCoordinate
        public let progress: Double
    }

    static let maxPerHouse = 3
    static let residentsPerStroller: UInt32 = 3
    static let reach = 3
    static let ticksPerTile: UInt64 = 12

    public static func strollers(in snapshot: WorldSnapshot) -> [Stroller] {
        let phase = TimeOfDay(tick: snapshot.tickCount).phase
        guard phase == .day || phase == .dusk else { return [] }
        let roads = Set(snapshot.buildings.values.filter { $0.kind == .road && $0.state == .operational }.map(\.anchor))
        var result: [Stroller] = []
        for (id, pop) in snapshot.housePopulations.sorted(by: { $0.key.raw < $1.key.raw }) {
            let count = min(maxPerHouse, Int(pop.population / residentsPerStroller))
            guard count > 0, let house = snapshot.buildings[id] else { continue }
            let route = nearbyRoads(of: house, in: roads)
            guard route.count > 1 else { continue }
            for slot in 0 ..< count {
                result.append(walk(house: id, slot: slot, route: route, tick: snapshot.tickCount))
            }
        }
        return result
    }

    /// Road tiles within `reach` of the house footprint, in reading order.
    static func nearbyRoads(of house: Building, in roads: Set<TileCoordinate>) -> [TileCoordinate] {
        let footprint = BuildingCatalog.spec(for: house.kind).footprint
        let xs = (house.anchor.x - reach) ... (house.anchor.x + footprint.width - 1 + reach)
        let ys = (house.anchor.y - reach) ... (house.anchor.y + footprint.height - 1 + reach)
        return roads.filter { xs.contains($0.x) && ys.contains($0.y) }
            .sorted { ($0.y, $0.x) < ($1.y, $1.x) }
    }

    /// Back and forth along the route; each slot starts at a different
    /// point so strollers of one house spread out.
    static func walk(house: EntityID, slot: Int, route: [TileCoordinate], tick: UInt64) -> Stroller {
        let legs = UInt64(2 * (route.count - 1))
        let offset = UInt64(house.raw) &* 7 &+ UInt64(slot) * legs / UInt64(maxPerHouse)
        let step = (tick / ticksPerTile &+ offset) % legs
        let progress = Double(tick % ticksPerTile) / Double(ticksPerTile)
        let index = Int(step)
        let forward = index < route.count - 1
        let fromIndex = forward ? index : Int(legs) - index
        let toIndex = forward ? fromIndex + 1 : fromIndex - 1
        return Stroller(house: house, slot: slot, from: route[fromIndex], to: route[toIndex], progress: progress)
    }
}
