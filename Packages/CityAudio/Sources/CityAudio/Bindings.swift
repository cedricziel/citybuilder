import Foundation

/// Hand-authored routing table that maps `WorldEvent` case names to one
/// or more audio cues. Loaded from `Resources/Audio/bindings.json` at
/// engine startup. Per spec `audio-playback` "Bindings file maps events
/// to cues".
public struct Bindings: Codable, Sendable, Equatable {
    public let version: Int
    /// Keys are `WorldEvent` case names (e.g. `"buildingPlaced"`). Values
    /// are arrays of cues — `AudioCoordinator` picks one per dispatch
    /// when more than one is bound.
    public let bindings: [String: [Cue]]
    public let music: MusicSection?

    public struct Cue: Codable, Sendable, Equatable {
        /// Path relative to `Resources/Audio/`.
        public let file: String
        public let bus: AudioBus
        public let volume: Float?
        public let loop: Bool?

        public init(file: String, bus: AudioBus, volume: Float? = nil, loop: Bool? = nil) {
            self.file = file
            self.bus = bus
            self.volume = volume
            self.loop = loop
        }
    }

    public struct MusicSection: Codable, Sendable, Equatable {
        public let tracks: [MusicTrack]
        /// Shuffle policy. Only `"no-repeat-within-last-two"` is recognized
        /// today; future values can be added without breaking older clients
        /// because unknown values fall back to plain sequential playback.
        public let shuffle: String?
        public let gapSecondsBetweenTracks: Double?

        public init(
            tracks: [MusicTrack] = [],
            shuffle: String? = nil,
            gapSecondsBetweenTracks: Double? = nil
        ) {
            self.tracks = tracks
            self.shuffle = shuffle
            self.gapSecondsBetweenTracks = gapSecondsBetweenTracks
        }
    }

    public struct MusicTrack: Codable, Sendable, Equatable {
        public let file: String
        public init(file: String) {
            self.file = file
        }
    }

    public init(version: Int = 1, bindings: [String: [Cue]] = [:], music: MusicSection? = nil) {
        self.version = version
        self.bindings = bindings
        self.music = music
    }

    /// All cue + music file references in the bindings, flattened.
    /// Used by validators to check that every referenced file exists in
    /// the manifest and on disk.
    public var allFilePaths: [String] {
        var paths: [String] = []
        for cues in bindings.values {
            paths.append(contentsOf: cues.map(\.file))
        }
        if let music {
            paths.append(contentsOf: music.tracks.map(\.file))
        }
        return paths
    }

    /// Errors surfaced by `validate(against:)`.
    public enum ValidationError: Error, Equatable, CustomStringConvertible {
        case unknownFile(String)

        public var description: String {
            switch self {
            case let .unknownFile(path):
                "bindings references file '\(path)' which has no manifest entry"
            }
        }
    }

    /// Verifies that every file path referenced by this bindings document
    /// has a corresponding `Manifest.Entry` with a matching `path`.
    public func validate(against manifest: Manifest) throws {
        let manifestPaths = Set(manifest.entries.map(\.path))
        for path in allFilePaths where !manifestPaths.contains(path) {
            throw ValidationError.unknownFile(path)
        }
    }

    /// Decode JSON `Data` and run validation against `manifest`.
    public static func load(from data: Data, manifest: Manifest) throws -> Bindings {
        let bindings = try JSONDecoder().decode(Bindings.self, from: data)
        try bindings.validate(against: manifest)
        return bindings
    }
}
