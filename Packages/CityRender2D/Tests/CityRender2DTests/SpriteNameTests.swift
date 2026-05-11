import CityCore
import Foundation
import Testing
@testable import CityRender2D

// Tests for the `Sprite naming grammar` requirement of
// sprite-asset-pipeline. Each `#### Scenario:` in
// openspec/changes/add-sprite-atlas-layout/specs/sprite-asset-pipeline/spec.md
// maps to one `@Test("scenario: <lowercased title>")` here.

// MARK: - Conformant names accepted

@Test("scenario: conformant terrain name accepted")
func scenarioConformantTerrainNameAccepted() {
    let result = SpriteName.validate("terrain-water-3")
    if case let .failure(reason) = result {
        Issue.record("expected terrain-water-3 to pass; got \(reason.rawValue)")
    }
}

@Test("scenario: conformant building name accepted")
func scenarioConformantBuildingNameAccepted() {
    let result = SpriteName.validate("building-sawmill-operational-2")
    if case let .failure(reason) = result {
        Issue.record("expected building-sawmill-operational-2 to pass; got \(reason.rawValue)")
    }
}

@Test("scenario: conformant building idle baseline accepted")
func scenarioConformantBuildingIdleBaselineAccepted() {
    let result = SpriteName.validate("building-house")
    if case let .failure(reason) = result {
        Issue.record("expected building-house to pass; got \(reason.rawValue)")
    }
}

@Test("scenario: conformant walker name accepted")
func scenarioConformantWalkerNameAccepted() {
    let result = SpriteName.validate("walker-ne-1")
    if case let .failure(reason) = result {
        Issue.record("expected walker-ne-1 to pass; got \(reason.rawValue)")
    }
}

// MARK: - Non-conformant names rejected

@Test("scenario: non-conformant casing rejected")
func scenarioNonConformantCasingRejected() {
    let result = SpriteName.validate("Building-Sawmill-operational-0")
    switch result {
    case let .failure(reason):
        #expect(reason.rawValue == "sprite_name_not_lowercase")
    case .success:
        Issue.record("expected casing rejection")
    }
}

@Test("scenario: underscore in name rejected")
func scenarioUnderscoreInNameRejected() {
    let result = SpriteName.validate("building-town_center")
    switch result {
    case let .failure(reason):
        #expect(reason.rawValue == "sprite_name_uses_underscore")
    case .success:
        Issue.record("expected underscore rejection")
    }
}

@Test("scenario: unknown prefix rejected")
func scenarioUnknownPrefixRejected() {
    let result = SpriteName.validate("vehicle-cart-0")
    switch result {
    case let .failure(reason):
        #expect(reason.rawValue == "sprite_name_unknown_prefix")
    case .success:
        Issue.record("expected unknown-prefix rejection")
    }
}

// MARK: - Catalog conformance

@Test("scenario: every catalog sprite name conforms to the grammar")
func scenarioEveryCatalogSpriteNameConformsToTheGrammar() {
    // The catalog enumerator is the single source of truth for what
    // sprites the renderer will look up at runtime. Every entry MUST
    // pass `SpriteName.validate` — this gate forces legacy underscore
    // names (e.g. `lumberjack_hut`, `town_center`) to be renamed.
    let violations: [(String, String)] = SpriteAtlas.catalogSpriteNames.compactMap { name in
        if case let .failure(reason) = SpriteName.validate(name) {
            return (name, reason.rawValue)
        }
        return nil
    }
    if !violations.isEmpty {
        let summary = violations.map { "\($0.0) → \($0.1)" }.joined(separator: ", ")
        Issue.record("catalog has non-conformant sprite names: \(summary)")
    }
    #expect(violations.isEmpty)
}
