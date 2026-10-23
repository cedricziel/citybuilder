import Foundation

/// A good piling up with nothing in town to use it, and the building
/// kinds its owner could build that would.
public struct IdleGood: Equatable, Sendable {
    public let good: Good
    public let users: [BuildingKind]
}

public extension World {
    /// Units in the owner's stores at which an unused good counts as idle.
    static let idleGoodThreshold = 20

    /// The owner's idle goods in catalog order: goods its stores hold at
    /// least `idleGoodThreshold` of that no house tier needs, that a kind
    /// the owner may build now uses, and that no building of the owner's,
    /// in any state, uses. Spec: `platform-shells` / Idle-good hint
    /// (`keep-the-town-supplied` D2).
    func idleGoods(of owner: Owner) -> [IdleGood] {
        var stored: [Good: Int] = [:]
        for store in goodsBuffers(of: owner) where store.state == .operational {
            for good in Good.allCases {
                stored[good, default: 0] += stockpiles[store.id]?.quantity(of: good) ?? 0
            }
        }
        let houseGoods = Set(HouseTier.allNeeds(in: culture(of: owner)))
        let owned = Set(buildings.values.filter { $0.owner == owner }.map(\.kind))
        return Good.allCases.compactMap { good in
            guard stored[good, default: 0] >= Self.idleGoodThreshold, !houseGoods.contains(good) else { return nil }
            let users = buildableUsers(of: good, for: owner)
            guard !users.isEmpty, owned.isDisjoint(with: Self.allUsers(of: good)) else { return nil }
            return IdleGood(good: good, users: users)
        }
    }

    /// Kinds `owner` may build now that turn `good` into other goods or
    /// burn it as fuel, in catalog order.
    internal func buildableUsers(of good: Good, for owner: Owner) -> [BuildingKind] {
        let culture = culture(of: owner)
        return Self.allUsers(of: good).filter { kind in
            let obsolete = kind.obsoletedBy.map(research.isResearched) ?? false
            return kind.isBuildable(in: culture) && research.isAvailable(kind) && !obsolete
        }
    }

    /// Every kind that turns `good` into other goods or burns it as fuel.
    /// Projects such as the monument take goods but make nothing, so
    /// building one is no use for a pile.
    internal static func allUsers(of good: Good) -> [BuildingKind] {
        usersByGood[good] ?? []
    }

    /// `allUsers(of:)` for every good, computed once from the catalogs.
    private static let usersByGood: [Good: [BuildingKind]] = Dictionary(
        uniqueKeysWithValues: Good.allCases.map { good in
            (good, BuildingKind.allCases.filter { kind in
                let recipe = ProductionCatalog.recipe(for: kind).flatMap { $0.outputs.isEmpty ? nil : $0 }
                return recipe?.inputs[good] != nil || kind.fuel?.good == good
            })
        }
    )
}
