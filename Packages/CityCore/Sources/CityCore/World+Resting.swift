import Foundation

/// Spec: `goods-and-production` / Producers rest while the stores hold
/// plenty (`rest-when-stocked` D1, D2).
public extension World {
    /// The first good `producer` makes that the stores on its island hold
    /// at least the good's rest level of, when every good it makes is so
    /// stocked; nil while it works. Producers without inputs never rest.
    func isResting(_ producer: Building) -> Good? {
        let tileToIsland = tileToIslandMap()
        let island = islandFor(building: producer, tileToIsland: tileToIsland)
        let stored = island.flatMap { storedTotals(of: producer.owner, tileToIsland: tileToIsland)[$0] } ?? [:]
        return isResting(producer, stored: stored)
    }
}

extension World {
    /// `stored` holds the totals on the producer's island.
    func isResting(_ producer: Building, stored: [Good: Int]) -> Good? {
        Self.activeRecipe(of: producer).flatMap { Self.restingGood(for: $0, stored: stored) }
    }

    static func restingGood(for recipe: ProductionRecipe, stored: [Good: Int]) -> Good? {
        guard !recipe.inputs.isEmpty, !recipe.outputs.isEmpty else { return nil }
        var first: Good?
        for good in Good.allCases where recipe.outputs[good] != nil {
            guard let level = good.restAt, stored[good, default: 0] >= level else { return nil }
            first = first ?? good
        }
        return first
    }

    /// Each good's total across `owner`'s operational town centers,
    /// warehouses and ports, per island. Stores never feed another
    /// island's producers, so an outpost rests only on its own stock.
    func storedTotals(of owner: Owner, tileToIsland: [TileCoordinate: IslandID]) -> [IslandID: [Good: Int]] {
        var totals: [IslandID: [Good: Int]] = [:]
        for store in goodsBuffers(of: owner) where store.state == .operational {
            guard let island = islandFor(building: store, tileToIsland: tileToIsland) else { continue }
            for (good, amount) in stockpiles[store.id]?.contents ?? [:] {
                totals[island, default: [:]][good, default: 0] += amount
            }
        }
        return totals
    }
}
