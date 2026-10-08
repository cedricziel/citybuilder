import Foundation

/// Pipeline element: takes a parsed JSON object at one schema
/// version and returns the same logical save at the next. Spec:
/// `persistence-save-load` / Requirement: Versioned migration pipeline.
public protocol Migration: Sendable {
    var fromVersion: Int { get }
    var toVersion: Int { get }
    func migrate(_ payload: [String: Any]) throws -> [String: Any]
}

/// Ordered chain of migrations applied at load time. Loaders walk
/// the chain from the file's `version` up to `SaveFile.currentVersion`.
public struct MigrationRegistry: Sendable {
    public let migrations: [Migration]

    public init(migrations: [Migration] = MigrationRegistry.defaultMigrations) {
        self.migrations = migrations.sorted { $0.fromVersion < $1.fromVersion }
    }

    /// Default chain — extend by appending the next-version migration
    /// at the end of this array.
    public static let defaultMigrations: [Migration] = [
        MigrationV1ToV2(),
        MigrationV2ToV3(),
        MigrationV3ToV4(),
        MigrationV4ToV5(),
        MigrationV5ToV6(),
        MigrationV6ToV7(),
        MigrationV7ToV8()
    ]

    /// Runs the chain on a raw save payload. Returns the migrated
    /// `Data` whose top-level `version` matches `toVersion`. Each
    /// migration step is `fromVersion → toVersion = fromVersion + 1`.
    public func migrate(payload: Data, toVersion: Int) throws -> Data {
        guard var root = try JSONSerialization.jsonObject(with: payload) as? [String: Any]
        else {
            throw SaveError.integrityFailed(reason: "save payload is not a JSON object")
        }
        let startVersion = (root["version"] as? Int) ?? 0
        guard startVersion <= toVersion else {
            throw SaveError.unknownVersion(startVersion)
        }
        let applicable = migrations.filter { step in
            step.fromVersion >= startVersion && step.toVersion <= toVersion
        }
        for step in applicable {
            root = try step.migrate(root)
        }
        return try JSONSerialization.data(
            withJSONObject: root, options: [.sortedKeys]
        )
    }
}

/// Migration #1: v1 → v2. The v1 schema predates the
/// `add-archipelago-and-sea` change; v2 adds `layout`, `islands`,
/// `ships`, and `routes` to the `World` payload. The single-island
/// MVP layout is the implicit pre-v2 topology, so we set it
/// explicitly and synthesize a one-entry island list from the
/// terrain grid. Ships and routes start empty — v1 had no sea
/// transport.
///
/// Determinism: every field this migration sets is derived from the
/// v1 payload (or hard-coded constants). The same v1 bytes always
/// produce the same v2 bytes.
public struct MigrationV1ToV2: Migration {
    public let fromVersion = 1
    public let toVersion = 2

    public init() {}

    public func migrate(_ payload: [String: Any]) throws -> [String: Any] {
        var root = payload
        root["version"] = 2
        guard var world = root["world"] as? [String: Any] else { return root }

        world["layout"] = "single-island"
        // `[EntityID: Ship]` and `[EntityID: Route]` encode as flat
        // JSON arrays of alternating key/value pairs (Codable's
        // representation of non-String-keyed dictionaries). Empty
        // collections therefore serialize as empty arrays.
        world["ships"] = [Any]()
        world["routes"] = [Any]()
        // `testMaterialCredits: [Good: Int]` is a test-only field
        // added by `add-build-materials-cost`. Real saves never carry
        // it; old v1 payloads lack the key entirely. Seed it as an
        // empty dictionary so World's Codable decoder finds the key.
        world["testMaterialCredits"] = [Any]()

        // Synthesize the single-island metadata from the terrain grid.
        let mapWidth = world["mapWidth"] as? Int ?? 0
        let mapHeight = world["mapHeight"] as? Int ?? 0
        let terrainGrid = world["terrainGrid"] as? [String] ?? []
        let buildable = terrainGrid.count(where: { $0 != "water" })

        if buildable > 0, mapWidth > 0, mapHeight > 0 {
            world["islands"] = [[
                "id": 1,
                "tileCount": buildable,
                "bounds": [
                    "minX": 0,
                    "minY": 0,
                    "maxX": mapWidth - 1,
                    "maxY": mapHeight - 1
                ],
                "climate": "temperate"
            ] as [String: Any]]
        } else {
            world["islands"] = [[String: Any]]()
        }

        root["world"] = world
        return root
    }
}

/// Migration #2: v2 → v3. v2 saves predate `add-construction-stalls`:
/// `Building` had no `constructionState` or `materialsDelivered`. The
/// migration treats every constructing building as already fully paid
/// — seeds `materialsDelivered = materialCost` and
/// `constructionState = .actively` so existing in-progress builds
/// don't suddenly stall on load. Operational buildings keep the
/// defaults; the fields are unused once construction is done.
public struct MigrationV2ToV3: Migration {
    public let fromVersion = 2
    public let toVersion = 3

    public init() {}

    public func migrate(_ payload: [String: Any]) throws -> [String: Any] {
        var root = payload
        root["version"] = 3
        guard var world = root["world"] as? [String: Any] else { return root }
        // `[EntityID: Building]` encodes as a flat array of alternating
        // key/value pairs. Buildings live at the odd indices.
        guard var buildings = world["buildings"] as? [Any] else {
            root["world"] = world
            return root
        }
        for index in stride(from: 1, to: buildings.count, by: 2) {
            guard var building = buildings[index] as? [String: Any] else { continue }
            let state = building["state"] as? String ?? "operational"
            if state == "constructing" {
                building["constructionState"] = "actively"
                let kindRaw = building["kind"] as? String ?? ""
                let cost = materialCost(forBuildingKindRaw: kindRaw)
                building["materialsDelivered"] = encodedGoodIntMap(cost)
            } else {
                building["constructionState"] = "actively"
                building["materialsDelivered"] = [Any]()
            }
            buildings[index] = building
        }
        world["buildings"] = buildings
        root["world"] = world
        return root
    }

    /// Mirror of `BuildingCatalog.spec(for:).materialCost` keyed by
    /// the raw enum string so this migration doesn't depend on the
    /// `BuildingKind` enum (which can drift across releases). Spec
    /// `add-build-materials-cost` design D2 recipe table.
    private func materialCost(forBuildingKindRaw raw: String) -> [String: Int] {
        switch raw {
        case "house": return ["planks": 4]
        case "warehouse": return ["wood": 2, "planks": 6]
        case "lumberjack-hut", "lumberjack_hut": return ["wood": 2]
        case "sawmill": return ["wood": 4, "planks": 1]
        case "port": return ["wood": 8, "planks": 6]
        case "shipyard": return ["wood": 12, "planks": 8]
        case "road", "town-center", "town_center": return [:]
        default: return [:]
        }
    }

    /// `[Good: Int]` encodes as `[Any]` with alternating key/value
    /// pairs in Codable. Build the same shape from a String-keyed map.
    private func encodedGoodIntMap(_ map: [String: Int]) -> [Any] {
        var result: [Any] = []
        for (good, amount) in map.sorted(by: { $0.key < $1.key }) {
            result.append(good)
            result.append(amount)
        }
        return result
    }
}

/// Migration #3: v3 → v4. v3 saves predate `add-research`: `World` had
/// no `research`. Older games keep every building available, so they
/// migrate with every tech researched. Spec: `persistence-save-load` /
/// Saves before research unlock every tech.
public struct MigrationV3ToV4: Migration {
    public let fromVersion = 3
    public let toVersion = 4

    public init() {}

    public func migrate(_ payload: [String: Any]) throws -> [String: Any] {
        var root = payload
        root["version"] = 4
        guard var world = root["world"] as? [String: Any] else { return root }
        world["research"] = [
            "researched": ["metallurgy", "milling", "mining", "scholarship", "seafaring"],
            "knowledge": 0,
            "progress": 0
        ] as [String: Any]
        root["world"] = world
        return root
    }
}

/// Migration #4: v4 → v5. v4 saves predate `add-calendar-and-events`:
/// `World` had no `calendar`. They migrate with an active calendar
/// starting in 1200, so their date is 1200 plus however long they have
/// run. Spec: `persistence-save-load` / Saves before the calendar get one.
public struct MigrationV4ToV5: Migration {
    public let fromVersion = 4
    public let toVersion = 5

    public init() {}

    public func migrate(_ payload: [String: Any]) throws -> [String: Any] {
        var root = payload
        root["version"] = 5
        guard var world = root["world"] as? [String: Any] else { return root }
        world["calendar"] = ["startYear": 1200, "isActive": true] as [String: Any]
        root["world"] = world
        return root
    }
}

/// Migration #5: v5 → v6. v5 saves predate `add-cultures`: `World` had
/// no `culture`. Their towns were Northern European. Spec:
/// `persistence-save-load` / Saves before cultures are Northern European.
public struct MigrationV5ToV6: Migration {
    public let fromVersion = 5
    public let toVersion = 6

    public init() {}

    public func migrate(_ payload: [String: Any]) throws -> [String: Any] {
        var root = payload
        root["version"] = 6
        guard var world = root["world"] as? [String: Any] else { return root }
        world["culture"] = "northern-european"
        root["world"] = world
        return root
    }
}

/// Migration #6: v6 → v7. v6 saves predate `add-historical-ages`:
/// `World` had no `age`. Their towns were Medieval, which means they
/// had passed Feudal Order, so it joins the researched list (kept
/// sorted like `ResearchState` encodes it). Spec:
/// `persistence-save-load` / Saves before ages are Medieval.
public struct MigrationV6ToV7: Migration {
    public let fromVersion = 6
    public let toVersion = 7

    public init() {}

    public func migrate(_ payload: [String: Any]) throws -> [String: Any] {
        var root = payload
        root["version"] = 7
        guard var world = root["world"] as? [String: Any] else { return root }
        world["age"] = "medieval"
        if var research = world["research"] as? [String: Any] {
            let researched = research["researched"] as? [String] ?? []
            research["researched"] = Array(Set(researched + ["feudal-order"])).sorted()
            world["research"] = research
        }
        root["world"] = world
        return root
    }
}

/// Migration #7: v7 → v8. v7 saves predate `add-difficulty-and-goals`:
/// they were Normal sandbox games. Spec: `persistence-save-load` /
/// Saves before difficulty are Normal sandboxes.
public struct MigrationV7ToV8: Migration {
    public let fromVersion = 7
    public let toVersion = 8

    public init() {}

    public func migrate(_ payload: [String: Any]) throws -> [String: Any] {
        var root = payload
        root["version"] = 8
        guard var world = root["world"] as? [String: Any] else { return root }
        world["difficulty"] = "normal"
        world["goals"] = [Any]()
        world["scenarioWon"] = false
        root["world"] = world
        return root
    }
}
