import Foundation
import Testing
@testable import CityCore

// Tests for the BuildingSpec.materialCost catalog field added by
// `add-build-materials-cost` → M1. Each `#### Scenario:` heading under
// `Requirement: Building material cost` in
// openspec/changes/add-build-materials-cost/specs/buildings-and-construction/spec.md
// maps to one `@Test("scenario: ...")` here.

@Test("scenario: buildingspec carries a material cost per good")
func scenarioBuildingSpecCarriesAMaterialCostPerGood() {
    let cost = BuildingCatalog.spec(for: .sawmill).materialCost
    #expect((cost[.wood] ?? 0) > 0)
    #expect((cost[.planks] ?? 0) > 0)
}

@Test("scenario: default material cost is empty")
func scenarioDefaultMaterialCostIsEmpty() {
    let spec = BuildingSpec(
        kind: .road,
        footprint: .single,
        cost: 0
    )
    #expect(spec.materialCost.isEmpty)
}

@Test("scenario: road and town center have no material cost")
func scenarioRoadAndTownCenterHaveNoMaterialCost() {
    #expect(BuildingCatalog.spec(for: .road).materialCost.isEmpty)
    #expect(BuildingCatalog.spec(for: .townCenter).materialCost.isEmpty)
}

@Test("scenario: every non-free building declares positive amounts")
func scenarioEveryNonFreeBuildingDeclaresPositiveAmounts() {
    // The catalog spans the design D2 recipe table — every paid
    // building lists strictly positive per-good amounts. (No
    // accidental zero entries.)
    let nonFree: [BuildingKind] = [.lumberjackHut, .sawmill, .warehouse, .house, .port, .shipyard]
    for kind in nonFree {
        let cost = BuildingCatalog.spec(for: kind).materialCost
        #expect(!cost.isEmpty, "\(kind) must have a material cost")
        for (_, amount) in cost {
            #expect(amount > 0, "\(kind) cost entries must be positive")
        }
    }
}
