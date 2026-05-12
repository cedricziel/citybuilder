import CityCore
import Foundation

/// Save/load store. Resolves paths under Application Support, writes
/// atomically, validates integrity on load, and applies forward migrations.
public final class SaveStore: @unchecked Sendable {
    public let baseDirectory: URL
    public let writer: FileWriter

    public init(baseDirectory: URL? = nil, writer: FileWriter = AtomicDiskWriter()) {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.baseDirectory = appSupport
                .appendingPathComponent("Citybuilder", isDirectory: true)
                .appendingPathComponent("saves", isDirectory: true)
        }
        self.writer = writer
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

    public func load(gameID: UUID) throws -> World {
        let data: Data
        do {
            data = try writer.read(from: url(for: gameID))
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
        guard writer.exists(at: target) else { return }
        try writer.remove(at: target)
    }
}
