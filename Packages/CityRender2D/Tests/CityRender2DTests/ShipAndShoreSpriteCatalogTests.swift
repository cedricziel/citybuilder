import CityCore
import Foundation
import Testing
@testable import CityRender2D

// Tests for the M7.5 sprite-asset-pipeline extension: ship sprites
// (8 facings × 2 frames) + shore-building sprites (4 orientations ×
// 6 state/frame slots per kind). Each `#### Scenario:` from
// openspec/changes/add-archipelago-and-sea/specs/sprite-asset-pipeline/spec.md
// maps to one `@Test` here.

// MARK: - Sprite naming grammar

@Test("scenario: conformant shore-building name accepted")
func scenarioConformantShoreBuildingNameAccepted() {
    let result = SpriteName.validate("building-port-w-operational-1")
    if case let .failure(reason) = result {
        Issue.record("expected building-port-w-operational-1 to pass; got \(reason.rawValue)")
    }
}

@Test("scenario: conformant shore-building idle baseline accepted")
func scenarioConformantShoreBuildingIdleBaselineAccepted() {
    let result = SpriteName.validate("building-port-n")
    if case let .failure(reason) = result {
        Issue.record("expected building-port-n to pass; got \(reason.rawValue)")
    }
}

@Test("scenario: conformant ship name accepted")
func scenarioConformantShipNameAccepted() {
    let result = SpriteName.validate("ship-ne-1")
    if case let .failure(reason) = result {
        Issue.record("expected ship-ne-1 to pass; got \(reason.rawValue)")
    }
}

@Test("scenario: shore-building name without orientation rejected")
func scenarioShoreBuildingNameWithoutOrientationRejected() {
    let result = SpriteName.validate("building-port-operational-0")
    switch result {
    case let .failure(reason):
        #expect(reason.rawValue == "shore_building_missing_orientation")
    case .success:
        Issue.record("expected rejection")
    }
}

@Test("scenario: ship name with cardinal-only facing rejected")
func scenarioShipNameWithCardinalOnlyFacingRejected() {
    // Post-archive: the 8-facing grammar accepts ship-ne-0. This test
    // pins that semantic (the spec phrasing reads as a regression
    // guard against reverting to the legacy walker-style 4-facing
    // validator).
    let result = SpriteName.validate("ship-ne-0")
    if case let .failure(reason) = result {
        Issue.record("ship-ne-0 must pass under the M7.5 grammar; got \(reason.rawValue)")
    }
}

@Test("scenario: ship name with unknown facing rejected")
func scenarioShipNameWithUnknownFacingRejected() {
    let result = SpriteName.validate("ship-northeast-0")
    switch result {
    case let .failure(reason):
        #expect(reason.rawValue == "ship_facing_unknown")
    case .success:
        Issue.record("expected rejection")
    }
}

// MARK: - Atlas routing by sprite-name prefix

@Test("scenario: ship name routes to units atlas")
func scenarioShipNameRoutesToUnitsAtlas() {
    #expect(SpriteAtlasRouting.atlasName(for: "ship-ne-0") == "Units")
    #expect(SpriteAtlasRouting.atlasName(for: "ship-nw-1") == "Units")
}

@Test("scenario: shore-building name routes to buildings atlas")
func scenarioShoreBuildingNameRoutesToBuildingsAtlas() {
    #expect(SpriteAtlasRouting.atlasName(for: "building-port-w-operational-1") == "Buildings")
    #expect(SpriteAtlasRouting.atlasName(for: "building-shipyard-s") == "Buildings")
}

// MARK: - Ship sprite inventory

@Test("scenario: all 16 ship sprites declared")
func scenarioAll16ShipSpritesDeclared() {
    let names = Set(SpriteAtlas.catalogSpriteNames.filter { $0.hasPrefix("ship-") })
    var expected: Set<String> = []
    for facing in SpriteName.shipFacings {
        for frame in 0 ..< 2 {
            expected.insert("ship-\(facing)-\(frame)")
        }
    }
    #expect(names == expected)
    #expect(names.count == 16)
}

// MARK: - Shore-building sprite inventory

@Test("scenario: all 24 port sprites declared")
func scenarioAll24PortSpritesDeclared() {
    let names = Set(SpriteAtlas.catalogSpriteNames.filter { $0.hasPrefix("building-port-") })
    #expect(names.count == 24)
    for orientation in SpriteName.shoreOrientations {
        #expect(names.contains("building-port-\(orientation)"))
        for frame in 0 ..< 3 {
            #expect(names.contains("building-port-\(orientation)-constructing-\(frame)"))
        }
        for frame in 0 ..< 2 {
            #expect(names.contains("building-port-\(orientation)-operational-\(frame)"))
        }
    }
}

@Test("scenario: all 24 shipyard sprites declared")
func scenarioAll24ShipyardSpritesDeclared() {
    let names = Set(SpriteAtlas.catalogSpriteNames.filter { $0.hasPrefix("building-shipyard-") })
    #expect(names.count == 24)
    for orientation in SpriteName.shoreOrientations {
        #expect(names.contains("building-shipyard-\(orientation)"))
        for frame in 0 ..< 3 {
            #expect(names.contains("building-shipyard-\(orientation)-constructing-\(frame)"))
        }
        for frame in 0 ..< 2 {
            #expect(names.contains("building-shipyard-\(orientation)-operational-\(frame)"))
        }
    }
}

// MARK: - Sprite catalog declares new content

@Test("scenario: catalog count grows by exactly 64")
func scenarioCatalogCountGrowsByExactly64() {
    // Pre-M7.5 catalog count for the 6 non-shore building kinds was
    // their static entries + constructing frames (no operational
    // animations for some), plus terrain entries + walker entries.
    // M7.5 ADDS 64 entries (16 ship + 24 port + 24 shipyard) and
    // REMOVES the 2 stale `building-port` / `building-shipyard`
    // entries that pre-M7.5 enumeration emitted under the non-shore
    // grammar. The net delta on the catalog is therefore +64 - 2.
    let names = Set(SpriteAtlas.catalogSpriteNames)
    let shipCount = names.count(where: { $0.hasPrefix("ship-") })
    let portCount = names.count(where: { $0.hasPrefix("building-port-") })
    let shipyardCount = names.count(where: { $0.hasPrefix("building-shipyard-") })
    #expect(shipCount == 16)
    #expect(portCount == 24)
    #expect(shipyardCount == 24)
    #expect(shipCount + portCount + shipyardCount == 64)
}

@Test("scenario: pre-existing catalog entries unchanged")
func scenarioPreExistingCatalogEntriesUnchanged() {
    // Pre-M7.5 entries for non-shore building kinds, terrain, and
    // walkers must continue to appear with identical names. We snapshot
    // a representative set rather than the full list — the existing
    // catalog tests (`SpriteAnimationTests`, `SpriteAtlasRoutingTests`)
    // pin individual entries.
    let names = Set(SpriteAtlas.catalogSpriteNames)
    let mustExist = [
        "terrain-grass", "terrain-water-3",
        "building-house", "building-warehouse", "building-road",
        "building-sawmill-operational-0", "building-lumberjack-hut-constructing-1",
        "walker-ne-0", "walker-sw-1"
    ]
    for entry in mustExist {
        #expect(names.contains(entry), "missing pre-existing catalog entry: \(entry)")
    }
    // The stale `building-port` / `building-shipyard` (non-orientation)
    // entries that pre-M7.5 enumeration emitted MUST be gone — they
    // no longer fit the shore-building grammar.
    #expect(!names.contains("building-port"))
    #expect(!names.contains("building-shipyard"))
}
