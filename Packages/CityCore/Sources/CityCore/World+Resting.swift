import Foundation

/// What the rest check reads about one owner's island: the goods its
/// stores hold and which kinds of building take each good as an input.
struct IslandRestContext: Equatable {
    var stored: [Good: Int] = [:]
    var inputUsers: [Good: Set<BuildingKind>] = [:]
}

/// Spec: `goods-and-production` / Producers rest while the stores hold
/// plenty (`rest-when-stocked` D1, D2).
public extension World {
    /// The first good `producer` makes that the stores on its island hold
    /// at least the good's rest level of, when every good it makes is so
    /// stocked and another kind of building on the island takes one of its
    /// inputs; nil while it works. Producers without inputs never rest.
    func isResting(_ producer: Building) -> Good? {
        let tileToIsland = tileToIslandMap()
        let island = islandFor(building: producer, tileToIsland: tileToIsland)
        let context = island.flatMap { restContexts(of: producer.owner, tileToIsland: tileToIsland)[$0] }
        return isResting(producer, context: context ?? IslandRestContext())
    }
}

extension World {
    /// `context` describes the producer's island.
    func isResting(_ producer: Building, context: IslandRestContext) -> Good? {
        Self.activeRecipe(of: producer).flatMap { Self.restingGood(for: $0, of: producer.kind, context: context) }
    }

    static func restingGood(for recipe: ProductionRecipe, of kind: BuildingKind, context: IslandRestContext) -> Good? {
        guard !recipe.inputs.isEmpty, !recipe.outputs.isEmpty else { return nil }
        var first: Good?
        for good in Good.allCases where recipe.outputs[good] != nil {
            guard let level = good.restAt, context.stored[good, default: 0] >= level else { return nil }
            first = first ?? good
        }
        // Resting frees inputs for other buildings; with no one to share
        // them with, the producer keeps working.
        let shares = recipe.inputs.keys.contains { context.inputUsers[$0, default: []].contains { $0 != kind } }
        return shares ? first : nil
    }

    /// Per island of `owner`: each good's total across its operational
    /// town centers, warehouses and ports, and the kinds of its
    /// operational buildings that take each good as an input. Stores never
    /// feed another island's producers, so an outpost rests only on its
    /// own stock.
    func restContexts(of owner: Owner, tileToIsland: [TileCoordinate: IslandID]) -> [IslandID: IslandRestContext] {
        var contexts: [IslandID: IslandRestContext] = [:]
        for store in goodsBuffers(of: owner) where store.state == .operational {
            guard let island = islandFor(building: store, tileToIsland: tileToIsland) else { continue }
            for (good, amount) in stockpiles[store.id]?.contents ?? [:] {
                contexts[island, default: IslandRestContext()].stored[good, default: 0] += amount
            }
        }
        for building in buildings.values where building.owner == owner && building.state == .operational {
            let needs = Self.suppliedGoods(of: building)
            guard !needs.isEmpty, let island = islandFor(building: building, tileToIsland: tileToIsland) else { continue }
            for good in needs.keys {
                contexts[island, default: IslandRestContext()].inputUsers[good, default: []].insert(building.kind)
            }
        }
        return contexts
    }
}
