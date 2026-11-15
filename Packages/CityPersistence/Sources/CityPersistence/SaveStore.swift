import CityCore
import Foundation

/// Which platform's save location applies. Apple TV has no persistent
/// local storage, so its saves live in Caches with iCloud as the durable
/// copy.
public enum SavePlatform: Sendable {
    case standard
    case appleTV

    public static var current: SavePlatform {
        #if os(tvOS)
        .appleTV
        #else
        .standard
        #endif
    }

    var searchPathDirectory: FileManager.SearchPathDirectory {
        switch self {
        case .standard: .applicationSupportDirectory
        case .appleTV: .cachesDirectory
        }
    }
}

/// Save/load store. Resolves paths under the platform's save directory,
/// writes atomically, validates integrity on load, and applies forward
/// migrations.
public final class SaveStore: @unchecked Sendable {
    public let baseDirectory: URL
    public let writer: FileWriter

    public init(
        baseDirectory: URL? = nil,
        platform: SavePlatform = .current,
        writer: FileWriter = AtomicDiskWriter()
    ) {
        self.baseDirectory = baseDirectory ?? Self.defaultDirectory(for: platform)
        self.writer = writer
    }

    public static func defaultDirectory(for platform: SavePlatform) -> URL {
        let root = FileManager.default.urls(for: platform.searchPathDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return root
            .appendingPathComponent("Citybuilder", isDirectory: true)
            .appendingPathComponent("saves", isDirectory: true)
    }

    public func url(for gameID: UUID) -> URL {
        baseDirectory.appendingPathComponent("\(gameID.uuidString).json")
    }

    public func save(_ world: World, gameID: UUID, at date: Date = Date()) throws {
        let file = SaveFile(world: world, writtenAt: date)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            let data = try encoder.encode(file)
            try writer.write(data, to: url(for: gameID))
        } catch let error as SaveError {
            throw error
        } catch {
            throw SaveError.ioFailed(reason: "\(error)")
        }
    }

    /// The single backup of `gameID`'s save: the autosave before the latest one.
    public func backupURL(for gameID: UUID) -> URL {
        url(for: gameID).appendingPathExtension("bak")
    }

    /// Writes an autosave. The save it replaces becomes the backup, but only
    /// when it still decodes, so a damaged file never replaces a good backup.
    /// A failed backup does not stop the save. A failed save leaves both
    /// files as they were.
    public func autosave(_ world: World, gameID: UUID, at date: Date = Date()) throws {
        let main = url(for: gameID)
        if writer.exists(at: main), let previous = try? writer.read(from: main), (try? decode(previous)) != nil {
            try? writer.write(previous, to: backupURL(for: gameID))
        }
        try save(world, gameID: gameID, at: date)
    }

    /// Loads `gameID`'s save. When the save cannot be read or decoded and a
    /// backup exists, the backup is loaded instead; the save's own error is
    /// thrown when the backup fails too.
    public func load(gameID: UUID) throws -> World {
        do {
            return try loadFile(at: url(for: gameID))
        } catch {
            let backup = backupURL(for: gameID)
            guard writer.exists(at: backup), let world = try? loadFile(at: backup) else { throw error }
            return world
        }
    }

    private func loadFile(at url: URL) throws -> World {
        let data: Data
        do {
            data = try writer.read(from: url)
        } catch {
            throw SaveError.ioFailed(reason: "\(error)")
        }
        return try decode(data)
    }

    /// Decode + validate + migrate. Public so CloudKit syncs can feed a
    /// remote-fetched payload through the same gate.
    public func decode(_ data: Data) throws -> World {
        // Peek at the version field without decoding the whole file so
        // unknown future versions fail fast.
        struct VersionPeek: Decodable { let version: Int }
        let peek: VersionPeek
        do {
            peek = try JSONDecoder().decode(VersionPeek.self, from: data)
        } catch {
            throw SaveError.integrityFailed(reason: "missing version field")
        }
        if peek.version <= 0 || peek.version > SaveFile.currentVersion {
            throw SaveError.unknownVersion(peek.version)
        }
        // Run the migration pipeline if the file is older than current.
        // Equal versions skip migration entirely (spec: v2 save bypasses
        // migration).
        let payload: Data
        if peek.version < SaveFile.currentVersion {
            do {
                payload = try migrationRegistry.migrate(
                    payload: data, toVersion: SaveFile.currentVersion
                )
            } catch let error as SaveError {
                throw error
            } catch {
                throw SaveError.integrityFailed(reason: "migration failed: \(error)")
            }
        } else {
            payload = data
        }
        let file: SaveFile
        do {
            file = try JSONDecoder().decode(SaveFile.self, from: payload)
        } catch {
            throw SaveError.integrityFailed(reason: "\(error)")
        }
        try validate(file.world)
        return file.world
    }

    /// Migration pipeline applied to pre-current-version payloads.
    /// Public-but-internal-by-default so tests can inject a counting
    /// wrapper around `Migration_v1_to_v2` without touching disk.
    public var migrationRegistry: MigrationRegistry = .init()

    private func validate(_ world: World) throws {
        guard world.mapWidth >= 0, world.mapHeight >= 0 else {
            throw SaveError.integrityFailed(reason: "negative map dimensions")
        }
        guard world.terrainGrid.count == world.mapWidth * world.mapHeight else {
            throw SaveError.integrityFailed(reason: "terrain grid size mismatch")
        }
        for (coord, _) in world.occupiedTiles {
            guard coord.x >= 0, coord.x < world.mapWidth,
                  coord.y >= 0, coord.y < world.mapHeight
            else {
                throw SaveError.integrityFailed(reason: "occupied tile out of bounds")
            }
        }
    }

    public func exists(gameID: UUID) -> Bool {
        writer.exists(at: url(for: gameID))
    }

    public func delete(gameID: UUID) throws {
        let target = url(for: gameID)
        let backup = backupURL(for: gameID)
        if writer.exists(at: backup) { try? writer.remove(at: backup) }
        guard writer.exists(at: target) else { return }
        try writer.remove(at: target)
    }
}
