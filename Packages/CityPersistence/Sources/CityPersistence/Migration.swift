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
        MigrationV1ToV2()
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
