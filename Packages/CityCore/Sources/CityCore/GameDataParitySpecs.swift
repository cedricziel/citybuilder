import Foundation

/// Copies of the catalog value types, keyed by the `GameDataParity`
/// enums, so the generated parity catalogs compile next to the
/// hand-written ones. Removed with the namespace in game-data-codegen
/// task 3.3.
extension GameDataParity {
    struct GoodSpec: Hashable {
        let good: Good
        let displayName: String
        let stackUnit: String
    }

    struct BuildingSpec: Hashable {
        let kind: BuildingKind
        let footprint: Footprint
        let cost: Int64
        let upkeep: Int64
        let buildDurationTicks: UInt64
        let shorePlacement: ShorePlacement?
        let materialCost: [Good: Int]
        let requiredTerrain: TerrainRequirement?
    }

    struct ProductionRecipe: Hashable {
        let inputs: [Good: Int]
        let outputs: [Good: Int]
        let cycleTicks: UInt64
    }

    struct LuxuryChain: Hashable {
        let raw: Good
        let good: Good
        let garden: BuildingKind
        let producer: BuildingKind
    }
}
