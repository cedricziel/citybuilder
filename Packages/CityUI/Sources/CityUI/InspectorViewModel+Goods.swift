import CityCore

/// One need of a house, drawn as a chip with the good's icon. Spec:
/// `platform-shells` / Callout shows goods as icons.
public struct NeedChip: Equatable, Sendable {
    public let good: Good
    public let isMet: Bool

    public var name: String {
        good.displayName
    }

    public var spokenLabel: String {
        let name = InspectorViewModel.goodName(good)
        return isMet ? GameText.string("inspector.need.met", name) : GameText.string("inspector.need.short", name)
    }

    static func chips(for population: HousePopulation, in culture: Culture) -> [NeedChip] {
        population.tier.needs(in: culture).map { NeedChip(good: $0, isMet: population.isSatisfied($0)) }
    }
}

public struct GoodAmount: Equatable, Hashable, Sendable {
    public let good: Good
    public let amount: Int
}

/// What a producer takes in and makes per cycle, goods in catalog order.
public struct RecipeSummary: Equatable, Sendable {
    public let inputs: [GoodAmount]
    public let outputs: [GoodAmount]

    init?(kind: BuildingKind) {
        guard let recipe = ProductionCatalog.recipe(for: kind) else { return nil }
        inputs = Self.ordered(recipe.inputs)
        outputs = Self.ordered(recipe.outputs)
    }

    private static func ordered(_ goods: [Good: Int]) -> [GoodAmount] {
        Good.allCases.compactMap { good in goods[good].map { GoodAmount(good: good, amount: $0) } }
    }

    public var spokenLabel: String {
        let list = { (goods: [GoodAmount]) in
            goods.map { "\($0.amount) \(InspectorViewModel.goodName($0.good))" }.joined(separator: ", ")
        }
        return inputs.isEmpty
            ? GameText.string("inspector.recipe.makes", list(outputs))
            : GameText.string("inspector.recipe.makesFrom", list(outputs), list(inputs))
    }
}

public extension InspectorViewModel {
    /// The key lines the callout lists as text: the need chips take the
    /// place of the "Needs:" line.
    var calloutKeyLines: [String] {
        guard !needChips.isEmpty else { return keyLines }
        let needs = Self.marker("inspector.needs")
        return keyLines.filter { !$0.hasPrefix(needs) }
    }
}
