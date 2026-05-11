import Foundation

/// Authoritative record of every audio asset shipped in `Resources/Audio/`.
/// Drives the in-app credits screen and is enforced as the single source
/// of truth by `scripts/check-audio-manifest.swift`. Per spec
/// `audio-playback` "Manifest file declares license metadata".
public struct Manifest: Codable, Sendable, Equatable {
    public let version: Int
    public let entries: [Entry]

    public struct Entry: Codable, Sendable, Equatable {
        public let path: String
        public let title: String
        public let author: String
        public let source: String
        public let license: License
        /// Required when `license` is non-CC0 (e.g. CC-BY-3.0). The text
        /// shown verbatim in the credits screen.
        public let attribution: String?

        public init(
            path: String,
            title: String,
            author: String,
            source: String,
            license: License,
            attribution: String? = nil
        ) {
            self.path = path
            self.title = title
            self.author = author
            self.source = source
            self.license = license
            self.attribution = attribution
        }
    }

    public enum License: String, Codable, Sendable, Equatable {
        case cc0 = "CC0"
        case ccBy30 = "CC-BY-3.0"
        case ccBy40 = "CC-BY-4.0"
        case pixabayContent = "Pixabay-Content"
        case proprietary

        /// True when the license requires attribution text in the credits.
        public var requiresAttribution: Bool {
            switch self {
            case .cc0: return false
            case .ccBy30, .ccBy40, .pixabayContent, .proprietary: return true
            }
        }
    }

    public init(version: Int = 1, entries: [Entry] = []) {
        self.version = version
        self.entries = entries
    }

    /// Errors surfaced by `validate()`.
    public enum ValidationError: Error, Equatable, CustomStringConvertible {
        case missingAttribution(path: String, license: License)
        case duplicatePath(String)

        public var description: String {
            switch self {
            case let .missingAttribution(path, license):
                "manifest entry '\(path)' uses license \(license.rawValue) which requires attribution text"
            case let .duplicatePath(path):
                "manifest contains duplicate entry for path '\(path)'"
            }
        }
    }

    /// Structural checks:
    /// 1. No duplicate `path` values.
    /// 2. Every entry whose license requires attribution carries one.
    public func validate() throws {
        var seen = Set<String>()
        for entry in entries {
            if !seen.insert(entry.path).inserted {
                throw ValidationError.duplicatePath(entry.path)
            }
            let attribution = (entry.attribution ?? "").trimmingCharacters(in: .whitespaces)
            if entry.license.requiresAttribution, attribution.isEmpty {
                throw ValidationError.missingAttribution(path: entry.path, license: entry.license)
            }
        }
    }

    /// Convenience: decode from JSON `Data` and validate in one step.
    public static func load(from data: Data) throws -> Manifest {
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        try manifest.validate()
        return manifest
    }
}
