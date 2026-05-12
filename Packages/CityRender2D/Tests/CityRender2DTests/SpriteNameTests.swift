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

// MARK: - Good-prefix grammar (add-island-hud-overlay → M4)

@Test("scenario: sprite-name grammar accepts good- prefix")
func scenarioSpriteNameGrammarAcceptsGoodPrefix() {
    for good in ["good-wood", "good-planks", "good-food"] {
        let result = SpriteName.validate(good)
        if case let .failure(reason) = result {
            Issue.record("expected \(good) to pass; got \(reason.rawValue)")
        }
    }
}

@Test("scenario: validator rejects good- with underscore")
func scenarioValidatorRejectsGoodWithUnderscore() {
    let result = SpriteName.validate("good-iron_ore")
    switch result {
    case let .failure(reason):
        #expect(reason.rawValue == "sprite_name_uses_underscore")
    case .success:
        Issue.record("expected underscore rejection on good-iron_ore")
    }
}

// MARK: - Catalog conformance

// MARK: - Per-tile art variant slot (add-sprite-art-variants)

@Test("scenario: variant slot accepted for terrain")
func scenarioVariantSlotAcceptedForTerrain() {
    let result = SpriteName.validate("terrain-mountain-v2")
    if case let .failure(reason) = result {
        Issue.record("expected terrain-mountain-v2 to pass; got \(reason.rawValue)")
    }
}

@Test("scenario: variant slot accepted for land-only building")
func scenarioVariantSlotAcceptedForLandOnlyBuilding() {
    let result = SpriteName.validate("building-road-v3")
    if case let .failure(reason) = result {
        Issue.record("expected building-road-v3 to pass; got \(reason.rawValue)")
    }
}

@Test("scenario: variant slot rejected on shore building")
func scenarioVariantSlotRejectedOnShoreBuilding() {
    // Shore-grammar kinds (port, shipyard) do not opt into the variant
    // slot — the orientation slot already provides per-tile differentia-
    // tion. `building-port-v1-n` puts `v1` where the orientation must
    // be, so validation MUST reject it.
    let result = SpriteName.validate("building-port-v1-n")
    switch result {
    case .failure:
        // The exact reason code is implementation-specific (today's
        // validator surfaces `shore_building_missing_orientation`); the
        // contract is rejection, not which error wins.
        break
    case .success:
        Issue.record("expected building-port-v1-n to fail; shore kinds do not accept the variant slot")
    }
}

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
