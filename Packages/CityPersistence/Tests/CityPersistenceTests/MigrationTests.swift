import Foundation
import Testing
@testable import CityCore
@testable import CityPersistence

// Tests for the M7 save-schema-v2 migration framework of
// add-archipelago-and-sea. Maps `#### Scenario:` headings from
// openspec/changes/add-archipelago-and-sea/specs/persistence-save-load/spec.md.

// MARK: - Synthetic v1 helpers

/// Builds the JSON for a v1-shape save by encoding a current World
/// and stripping the v2-only fields. Used by tests that need a v1
/// payload without checking in a hand-authored fixture.
private func makeV1Payload(world: World, writtenAt: Date = Date()) throws -> Data {
    var v2 = try JSONEncoder().encode(SaveFile(world: world, writtenAt: writtenAt))
    var json = try JSONSerialization.jsonObject(with: v2) as? [String: Any] ?? [:]
    json["version"] = 1
    var inner = json["world"] as? [String: Any] ?? [:]
    stripRivalKeys(&inner)
    inner.removeValue(forKey: "layout")
    inner.removeValue(forKey: "islands")
    inner.removeValue(forKey: "ships")
    inner.removeValue(forKey: "routes")
    // Test-only field added by `add-build-materials-cost`; v1 saves
    // predate it. The migration re-introduces it as an empty dict.
    inner.removeValue(forKey: "testMaterialCredits")
    json["world"] = inner
    v2 = try JSONSerialization.data(
        withJSONObject: json, options: [.sortedKeys]
    )
    return v2
}

private func decodeWorld(_ data: Data) throws -> World {
    let store = SaveStore(baseDirectory: FileManager.default.temporaryDirectory)
    return try store.decode(data)
}

// MARK: - Codable snapshot save format

// (`scenario: unknown version refused` is covered by the existing
// `CityPersistenceTests` test of the same name.)

@Test("scenario: version 1 save loads successfully")
func scenarioVersion1SaveLoadsSuccessfully() throws {
    let world = World.newGame()
    let v1 = try makeV1Payload(world: world)
    let loaded = try decodeWorld(v1)
    #expect(loaded.layout == .singleIsland)
}

@Test("scenario: version 2 save loads without migration")
func scenarioVersion2SaveLoadsWithoutMigration() throws {
    let world = World.newGame(layout: .archipelago, seed: 17)
    let data = try JSONEncoder().encode(SaveFile(world: world))
    let loaded = try decodeWorld(data)
    #expect(loaded.layout == .archipelago)
    #expect(loaded.islands.count >= 2)
}

@Test("scenario: save writes use current version")
func scenarioSaveWritesUseCurrentVersion() throws {
    let world = World.newGame()
    let data = try JSONEncoder().encode(SaveFile(world: world))
    let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    #expect(parsed["version"] as? Int == SaveFile.currentVersion)
}

// MARK: - Versioned migration pipeline

@Test("scenario: v1 to v2 migration chain runs once")
func scenarioV1ToV2MigrationChainRunsOnce() throws {
    let world = World.newGame()
    let v1 = try makeV1Payload(world: world)
    let counter = MigrationCounter()
    let registry = MigrationRegistry(migrations: [
        CountingMigration(wrapped: MigrationV1ToV2(), counter: counter)
    ])
    let migrated = try registry.migrate(payload: v1, toVersion: SaveFile.currentVersion)
    #expect(counter.invocations == 1)
    let parsed = try JSONSerialization.jsonObject(with: migrated) as? [String: Any] ?? [:]
    #expect(parsed["version"] as? Int == 2)
}

@Test("scenario: v2 save bypasses migration")
func scenarioV2SaveBypassesMigration() throws {
    let world = World.newGame()
    let data = try JSONEncoder().encode(SaveFile(world: world))
    let counter = MigrationCounter()
    let registry = MigrationRegistry(migrations: [
        CountingMigration(wrapped: MigrationV1ToV2(), counter: counter)
    ])
    _ = try registry.migrate(payload: data, toVersion: SaveFile.currentVersion)
    #expect(counter.invocations == 0)
}

@Test("scenario: migration is pure")
func scenarioMigrationIsPure() throws {
    // The migration function itself is the unit of purity: the same
    // v1 bytes must produce the same v2 bytes. (Re-encoding a fully-
    // decoded `World` is not byte-stable in general because
    // `[EntityID: …]` dictionaries serialize via Codable as
    // alternating-pair JSON arrays whose order tracks the dictionary's
    // non-deterministic iteration order — out of scope for this
    // change. The migration step itself acts on the JSON object
    // tree with `.sortedKeys`, which is deterministic.)
    let world = World.newGame()
    let v1 = try makeV1Payload(world: world)
    let registry = MigrationRegistry()
    let first = try registry.migrate(payload: v1, toVersion: SaveFile.currentVersion)
    let second = try registry.migrate(payload: v1, toVersion: SaveFile.currentVersion)
    #expect(first == second)
}

// MARK: - v1→v2 migration semantics

@Test("scenario: migrated save loads as single-island layout")
func scenarioMigratedSaveLoadsAsSingleIslandLayout() throws {
    let world = World.newGame()
    let v1 = try makeV1Payload(world: world)
    let loaded = try decodeWorld(v1)
    #expect(loaded.layout == .singleIsland)
}

@Test("scenario: warehouses preserved as goods buffers")
func scenarioWarehousesPreservedAsGoodsBuffers() throws {
    // The MVP starting world includes a town-center building plus
    // whatever the new-game economy seeds; warehouses are the user's
    // own placement, but the migration is purely structural — any
    // `kind == .warehouse` entry must round-trip. We use a directly-
    // constructed World since CityPersistence cannot mutate
    // `pendingCommands` (the setter is internal to CityCore).
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    let warehouseID = EntityID(raw: 999)
    let warehouse = Building(
        id: warehouseID, kind: .warehouse,
        anchor: TileCoordinate(x: 1, y: 1), state: .operational
    )
    world.buildings[warehouseID] = warehouse
    world.occupiedTiles[warehouse.anchor] = warehouseID
    let warehousesBefore = world.buildings.values.count(where: { $0.kind == .warehouse })
    let v1 = try makeV1Payload(world: world)
    let loaded = try decodeWorld(v1)
    let warehousesAfter = loaded.buildings.values.count(where: { $0.kind == .warehouse })
    #expect(warehousesAfter == warehousesBefore)
    #expect(warehousesAfter >= 1)
}

@Test("scenario: migrated save has no ships or routes")
func scenarioMigratedSaveHasNoShipsOrRoutes() throws {
    let world = World.newGame()
    let v1 = try makeV1Payload(world: world)
    let loaded = try decodeWorld(v1)
    #expect(loaded.ships.isEmpty)
    #expect(loaded.routes.isEmpty)
}

@Test("scenario: migration preserves money and population balance")
func scenarioMigrationPreservesMoneyAndPopulationBalance() throws {
    let world = World.newGame()
    let moneyBefore = world.economy.balance
    let v1 = try makeV1Payload(world: world)
    let loaded = try decodeWorld(v1)
    #expect(loaded.economy.balance == moneyBefore)
}

// MARK: - Migration coverage gate

@Test("gate: every prior save version has a registered migration + fixture")
func gateEveryPriorVersionHasMigrationAndFixture() {
    // For every source version `v` in [1, currentVersion-1], the
    // default registry MUST contain a migration with that fromVersion
    // AND a `v<v>_*.json` fixture file MUST exist in the saves
    // directory. CI fails when a future version bumps without both.
    let registry = MigrationRegistry()
    let fromVersions = Set(registry.migrations.map(\.fromVersion))
    let fixtureDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/saves")
    let fixtureNames = (try? FileManager.default.contentsOfDirectory(atPath: fixtureDir.path)) ?? []
    for sourceVersion in 1 ..< SaveFile.currentVersion {
        #expect(
            fromVersions.contains(sourceVersion),
            "missing migration for version \(sourceVersion)"
        )
        let prefix = "v\(sourceVersion)_"
        let hasFixture = fixtureNames.contains { $0.hasPrefix(prefix) }
        #expect(hasFixture, "missing fixture v\(sourceVersion)_*.json")
    }
}

// MARK: - Migration fixture coverage

private func fixtureURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // CityPersistenceTests
        .appendingPathComponent("Fixtures/saves/v1_single_island.json")
}

private func v2FixtureURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/saves/v2_single_island.json")
}

/// Regeneration rewrites committed files, so it only runs when asked:
/// `SWIFT_DETERMINISTIC_HASHING=1 REGENERATE_FIXTURES=1 xcrun swift test --package-path Packages/CityPersistence`.
let regenerateFixtures = ProcessInfo.processInfo.environment["REGENERATE_FIXTURES"] == "1"

/// Dictionaries with non-string keys encode in hash order, which is
/// seeded per process unless deterministic hashing is on.
func requireDeterministicHashing() throws {
    try #require(
        ProcessInfo.processInfo.environment["SWIFT_DETERMINISTIC_HASHING"] == "1",
        "set SWIFT_DETERMINISTIC_HASHING=1 so regenerated fixtures are byte-stable"
    )
}

/// Removes what v9 (`add-rival-towns`) added, for payloads of older
/// versions: the world's `rivals` and every building and ship `owner`.
/// Buildings and ships encode as alternating key/value arrays.
func stripRivalKeys(_ world: inout [String: Any]) {
    world.removeValue(forKey: "rivals")
    for key in ["buildings", "ships"] {
        guard var entries = world[key] as? [Any] else { continue }
        for index in stride(from: 1, to: entries.count, by: 2) {
            guard var entry = entries[index] as? [String: Any] else { continue }
            entry.removeValue(forKey: "owner")
            entries[index] = entry
        }
        world[key] = entries
    }
}

/// Fixed `writtenAt` for regenerated fixtures so a regen diff only
/// shows real schema changes.
let fixtureWrittenAt = Date(timeIntervalSinceReferenceDate: 800_000_000)

@Test("fixture: regenerate v1 single-island save", .enabled(if: regenerateFixtures))
func regenerateV1SingleIslandFixture() throws {
    try requireDeterministicHashing()
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    let warehouseID = EntityID(raw: 1001)
    world.buildings[warehouseID] = Building(
        id: warehouseID, kind: .warehouse,
        anchor: TileCoordinate(x: 1, y: 1), state: .operational
    )
    world.occupiedTiles[TileCoordinate(x: 1, y: 1)] = warehouseID
    world.stockpiles[warehouseID] = Stockpile(capacity: 200)
    if var sp = world.stockpiles[warehouseID] {
        _ = sp.deposit(.wood, amount: 50)
        world.stockpiles[warehouseID] = sp
    }
    var data = try makeV1Payload(world: world, writtenAt: fixtureWrittenAt)
    // Append a trailing newline so the pre-commit `end-of-file-fixer`
    // hook does not rewrite the file every commit.
    data.append(0x0A)
    let url = fixtureURL()
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    try data.write(to: url)
}

@Test("fixture: regenerate v2 single-island save", .enabled(if: regenerateFixtures))
func regenerateV2SingleIslandFixture() throws {
    try requireDeterministicHashing()
    // Writes a representative v2 save (pre-`add-construction-stalls`)
    // to the fixture path so the migration-coverage gate has something
    // to point at for the v2 → v3 step. v2 is shaped exactly like the
    // current Codable, minus the new `constructionState` and
    // `materialsDelivered` fields on `Building`.
    var world = World.newGame()
    let warehouseID = EntityID(raw: 1001)
    world.buildings[warehouseID] = Building(
        id: warehouseID, kind: .warehouse,
        anchor: TileCoordinate(x: 1, y: 1), state: .constructing,
        ticksSincePlacement: 3
    )
    world.occupiedTiles[TileCoordinate(x: 1, y: 1)] = warehouseID
    world.stockpiles[warehouseID] = Stockpile(capacity: 200)
    var data = try makeV2Payload(world: world, writtenAt: fixtureWrittenAt)
    data.append(0x0A)
    let url = v2FixtureURL()
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    try data.write(to: url)
}

/// Encode a World and stamp the version to 2 while stripping the
/// fields that v2 didn't carry (`constructionState`,
/// `materialsDelivered` on Building). Mirrors `makeV1Payload`'s
/// strip-then-re-encode approach.
private func makeV2Payload(world: World, writtenAt: Date = Date()) throws -> Data {
    var data = try JSONEncoder().encode(SaveFile(world: world, writtenAt: writtenAt))
    var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    json["version"] = 2
    var inner = json["world"] as? [String: Any] ?? [:]
    stripRivalKeys(&inner)
    if var buildings = inner["buildings"] as? [Any] {
        for idx in stride(from: 1, to: buildings.count, by: 2) {
            if var building = buildings[idx] as? [String: Any] {
                building.removeValue(forKey: "constructionState")
                building.removeValue(forKey: "materialsDelivered")
                buildings[idx] = building
            }
        }
        inner["buildings"] = buildings
    }
    json["world"] = inner
    data = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
    return data
}

private func v3FixtureURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/saves/v3_single_island.json")
}

/// Encode a World as a v3 save: the current shape minus `research`.
private func makeV3Payload(world: World, writtenAt: Date = Date()) throws -> Data {
    let data = try JSONEncoder().encode(SaveFile(world: world, writtenAt: writtenAt))
    var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    json["version"] = 3
    var inner = json["world"] as? [String: Any] ?? [:]
    stripRivalKeys(&inner)
    inner.removeValue(forKey: "research")
    inner.removeValue(forKey: "calendar")
    inner.removeValue(forKey: "culture")
    inner.removeValue(forKey: "age")
    for key in ["difficulty", "goals", "scenarioWon"] {
        inner.removeValue(forKey: key)
    }
    json["world"] = inner
    return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
}

@Test("fixture: regenerate v3 single-island save", .enabled(if: regenerateFixtures))
func regenerateV3SingleIslandFixture() throws {
    try requireDeterministicHashing()
    // A v3 save predates `add-research`: no `research` on World.
    var data = try makeV3Payload(world: World.newGame(), writtenAt: fixtureWrittenAt)
    data.append(0x0A)
    try data.write(to: v3FixtureURL())
}

@Test("scenario: v3 save loads with all techs researched")
func scenarioV3SaveLoadsWithAllTechsResearched() throws {
    let data = try Data(contentsOf: v3FixtureURL())
    let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    #expect(parsed["version"] as? Int == 3, "fixture must be a v3 save")
    let loaded = try decodeWorld(data)
    // "Every tech" means every tech that existed in v3; era techs came later.
    #expect([Tech.scholarship, .milling, .mining, .metallurgy, .seafaring].allSatisfy(loaded.research.isResearched))
    #expect(loaded.research.current == nil)
}

@Test("scenario: v1 fixture exists and migrates cleanly")
func scenarioV1FixtureExistsAndMigratesCleanly() throws {
    let data = try Data(contentsOf: fixtureURL())
    let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    #expect(parsed["version"] as? Int == 1, "fixture must be a v1 save")
    let loaded = try decodeWorld(data)
    #expect(loaded.layout == .singleIsland)
    #expect(loaded.islands.count == 1)
    #expect(loaded.ships.isEmpty)
    #expect(loaded.routes.isEmpty)
    let warehouses = loaded.buildings.values.filter { $0.kind == .warehouse }
    #expect(warehouses.count >= 1)
}

@Test("fixture: v2 fixture exists and migrates cleanly")
func v2FixtureExistsAndMigratesCleanly() throws {
    let data = try Data(contentsOf: v2FixtureURL())
    let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    #expect(parsed["version"] as? Int == 2, "fixture must be a v2 save")
    let loaded = try decodeWorld(data)
    let warehouse = try #require(loaded.buildings[EntityID(raw: 1001)])
    #expect(warehouse.kind == .warehouse)
    #expect(warehouse.state == .constructing)
}

// MARK: - Test helpers

final class MigrationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = 0
    /// Number of times `bump()` has been called. Named `invocations`
    /// rather than `count` to dodge the SwiftLint + SwiftFormat
    /// interplay around `count == 0` / `isEmpty`.
    var invocations: Int {
        lock.lock(); defer { lock.unlock() }
        return stored
    }

    func bump() {
        lock.lock(); defer { lock.unlock() }
        stored += 1
    }
}

struct CountingMigration: Migration {
    let wrapped: Migration
    let counter: MigrationCounter
    var fromVersion: Int {
        wrapped.fromVersion
    }

    var toVersion: Int {
        wrapped.toVersion
    }

    func migrate(_ payload: [String: Any]) throws -> [String: Any] {
        counter.bump()
        return try wrapped.migrate(payload)
    }
}
