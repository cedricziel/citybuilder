import Foundation

/// Spec: `goods-and-production` / Producers rest while the stores hold
/// plenty (`rest-when-stocked` D1, D2).
public extension World {
    /// The first good `producer` makes that its owner's stores hold at
    /// least the good's rest level of, when every good it makes is so
    /// stocked; nil while it works. Producers without inputs never rest.
    func isResting(_ producer: Building) -> Good? {
        isResting(producer, stored: storedTotals(of: producer.owner))
    }
}

extension World {
    func isResting(_ producer: Building, stored: [Good: Int]) -> Good? {
        guard let recipe = Self.activeRecipe(of: producer), !recipe.inputs.isEmpty, !recipe.outputs.isEmpty else { return nil }
        var first: Good?
        for good in Good.allCases where recipe.outputs[good] != nil {
            guard let level = good.restAt, stored[good, default: 0] >= level else { return nil }
            first = first ?? good
        }
        return first
    }

    /// Each good's total across `owner`'s operational town centers,
    /// warehouses and ports.
    func storedTotals(of owner: Owner) -> [Good: Int] {
        var totals: [Good: Int] = [:]
        for store in goodsBuffers(of: owner) where store.state == .operational {
            for (good, amount) in stockpiles[store.id]?.contents ?? [:] {
                totals[good, default: 0] += amount
            }
        }
        return totals
    }
}
