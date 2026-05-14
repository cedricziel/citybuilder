import CityCore
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
    /// Optional ambient bed: a track that plays as a loop on the
    /// `ambient` bus while any building exists. See spec
    /// `audio-playback` — Ambient bed section.
    public let ambient: AmbientSection?

    /// Whether a cue starts playback or stops the active loop for the
    /// event's primary entity. Default `.start` matches Phase 1 semantics.
    public enum CueAction: String, Codable, Sendable, Equatable {
        case start
        case stop
    }

    public struct Cue: Codable, Sendable, Equatable {
        /// Path relative to `Resources/Audio/`. Required for `.start` cues;
        /// ignored for `.stop` cues (the empty string is the conventional
        /// placeholder so authors can omit it in JSON).
        public let file: String
        public let bus: AudioBus
        public let volume: Float?
        public let loop: Bool?
        /// Opt in / out of spatial routing for this cue. nil → defaults to
        /// spatialized iff `bus == .loop` (see `DispatchedCue.isSpatialized`).
        public let spatialize: Bool?
        /// `.start` (default) → dispatch playback; `.stop` → look up the
        /// event's primary entity and halt its active loop.
        public let action: CueAction
        /// Restricts this cue to events whose payload `kind` matches.
        /// Events without a `kind` payload never match a non-nil filter.
        public let kindFilter: BuildingKind?

        public init(
            file: String = "",
            bus: AudioBus = .sfx,
            volume: Float? = nil,
            loop: Bool? = nil,
            spatialize: Bool? = nil,
            action: CueAction = .start,
            kindFilter: BuildingKind? = nil
        ) {
            self.file = file
            self.bus = bus
            self.volume = volume
            self.loop = loop
            self.spatialize = spatialize
            self.action = action
            self.kindFilter = kindFilter
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CueCodingKey.self)
            file = try container.decodeIfPresent(String.self, forKey: .file) ?? ""
            bus = try container.decode(AudioBus.self, forKey: .bus)
            volume = try container.decodeIfPresent(Float.self, forKey: .volume)
            loop = try container.decodeIfPresent(Bool.self, forKey: .loop)
            spatialize = try container.decodeIfPresent(Bool.self, forKey: .spatialize)
            action = try container.decodeIfPresent(CueAction.self, forKey: .action) ?? .start
            kindFilter = try container.decodeIfPresent(BuildingKind.self, forKey: .kindFilter)
        }
    }

    /// Coding keys for `Cue`. Defined at the `Bindings` level rather than
    /// nested inside `Cue` to keep the type tree under SwiftLint's
    /// `nesting` rule (max 1 level deep).
    enum CueCodingKey: String, CodingKey {
        case file, bus, volume, loop, spatialize, action, kindFilter
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

    /// Ambient bed paralleling `MusicSection`. When present and non-empty,
    /// `AudioStack` starts the first track as a loop cue on the `ambient`
    /// bus on the first non-empty `consume(events:)` call. Multi-track
    /// support is forwards-compatible with future shuffle policy.
    public struct AmbientSection: Codable, Sendable, Equatable {
        public let tracks: [MusicTrack]
        public let crossfadeSeconds: Double?

        public init(tracks: [MusicTrack] = [], crossfadeSeconds: Double? = nil) {
            self.tracks = tracks
            self.crossfadeSeconds = crossfadeSeconds
        }
    }

    public init(
        version: Int = 1,
        bindings: [String: [Cue]] = [:],
        music: MusicSection? = nil,
        ambient: AmbientSection? = nil
    ) {
        self.version = version
        self.bindings = bindings
        self.music = music
        self.ambient = ambient
    }

    /// All cue + music + ambient file references in the bindings,
    /// flattened. Used by validators to check that every referenced file
    /// exists in the manifest and on disk. Cues with `action == .stop`
    /// contribute no file (their `file` is conventionally empty).
    public var allFilePaths: [String] {
        var paths: [String] = []
        for cues in bindings.values {
            for cue in cues where cue.action == .start && !cue.file.isEmpty {
                paths.append(cue.file)
            }
        }
        if let music {
            paths.append(contentsOf: music.tracks.map(\.file))
        }
        if let ambient {
            paths.append(contentsOf: ambient.tracks.map(\.file))
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
