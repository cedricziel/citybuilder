import CityCore
import Foundation

/// Top-level save file structure. `version` gates forward-migration; the
/// `World` is encoded as the payload. Saves are JSON in v0 per design D6.
public struct SaveFile: Codable, Sendable, Equatable {
    public static let currentVersion: Int = 5

    public let version: Int
    public let world: World
    public let writtenAt: Date

    public init(world: World, writtenAt: Date = Date()) {
        self.version = SaveFile.currentVersion
        self.world = world
        self.writtenAt = writtenAt
    }
}

public enum SaveError: Error, Equatable, CustomStringConvertible, Sendable {
    case unknownVersion(Int)
    case integrityFailed(reason: String)
    case ioFailed(reason: String)

    public var description: String {
        switch self {
        case let .unknownVersion(value): "unknown_save_version (\(value))"
        case let .integrityFailed(reason): "integrity_failed: \(reason)"
        case let .ioFailed(reason): "io_failed: \(reason)"
        }
    }
}
