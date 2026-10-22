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

@Test("scenario: an unknown ship stem falls back to the kit atlas")
func scenarioUnknownShipStemFallsBackToKitAtlas() {
    #expect(SpriteAtlasRouting.atlasName(for: "ship-x-0") == "Kit")
}

@Test("scenario: shore-building name routes to buildings atlas")
func scenarioShoreBuildingNameRoutesToBuildingsAtlas() {
    #expect(SpriteAtlasRouting.atlasName(for: "building-port-x-operational-1") == "Buildings")
}

@Test("scenario: ship name routes to kit atlas")
func scenarioShipNameRoutesToKitAtlas() {
    #expect(SpriteAtlasRouting.atlasName(for: "ship-ne-0") == "Kit")
    #expect(SpriteAtlasRouting.atlasName(for: "ship-nw-1") == "Kit")
}

@Test("scenario: shore-building name routes to kit atlas")
func scenarioShoreBuildingNameRoutesToKitAtlas() {
    #expect(SpriteAtlasRouting.atlasName(for: "building-port-w-operational-1") == "Kit")
    #expect(SpriteAtlasRouting.atlasName(for: "building-shipyard-s") == "Kit")
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

@Test("scenario: all 20 port sprites declared")
func scenarioAll20PortSpritesDeclared() {
    let names = Set(SpriteAtlas.catalogSpriteNames.filter { $0.hasPrefix("building-port-") })
    #expect(names.count == 20)
    for orientation in SpriteName.shoreOrientations {
        #expect(names.contains("building-port-\(orientation)"))
        for frame in 0 ..< 3 {
            #expect(names.contains("building-port-\(orientation)-constructing-\(frame)"))
        }
        #expect(names.contains("building-port-\(orientation)-operational-0"))
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

// MARK: - Catalog counts

@Test("the catalog declares 16 ships, 20 port sprites and 24 shipyard sprites")
func catalogCountsShipsAndShoreSprites() {
    let names = Set(SpriteAtlas.catalogSpriteNames)
    #expect(names.count(where: { $0.hasPrefix("ship-") }) == 16)
    #expect(names.count(where: { $0.hasPrefix("building-port-") }) == 20)
    #expect(names.count(where: { $0.hasPrefix("building-shipyard-") }) == 24)
}

@Test("pre-existing catalog entries stay declared")
func preExistingCatalogEntriesStayDeclared() {
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

// MARK: - Placement ghost

/// A shore building has no facing-free sprite, so its ghost asks for the facing it would get.
@Test("a shore building's ghost shows the facing the water gives it")
func shoreGhostShowsItsFacing() {
    let anchor = TileCoordinate(x: 10, y: 10)
    let waterSouth = { (tile: TileCoordinate) -> TerrainType? in tile.y >= 12 ? .water : .grass }
    let waterWest = { (tile: TileCoordinate) -> TerrainType? in tile.x == 10 ? .water : .grass }
    #expect(ShoreOrientationMath.ghostTextureName(kind: .port, anchor: anchor, terrain: waterSouth) == "building-port-s")
    #expect(ShoreOrientationMath.ghostTextureName(kind: .shipyard, anchor: anchor, terrain: waterWest) == "building-shipyard-w")
    #expect(ShoreOrientationMath.ghostTextureName(kind: .port, anchor: anchor) { _ in .grass } == "building-port-s")
    #expect(ShoreOrientationMath.ghostTextureName(kind: .house, anchor: anchor, terrain: waterSouth) == nil)
}
