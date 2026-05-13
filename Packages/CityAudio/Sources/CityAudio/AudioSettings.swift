import Foundation

/// Persisted audio settings: per-bus volumes and master mute. Backed by
/// `UserDefaults` so values survive app launches. Per spec `audio-playback`
/// "Per-bus volume control" and "Volume settings persist".
///
/// In Phase 1 (M11), the app shell wires these values into `AudioEngine`
/// at construction time and observes changes from the Settings UI. M13
/// adds iCloud key-value sync on top of the same three keys.
public final class AudioSettings: @unchecked Sendable {
    private let defaults: UserDefaults

    /// Storage keys — kept here so `icloud-sync` can use the same names
    /// when wiring the CloudKit KV-store mirror.
    public enum Key {
        public static let musicVolume = "audio.musicVolume"
        public static let sfxVolume = "audio.sfxVolume"
        public static let muted = "audio.muted"
        public static let spatialEnabled = "audio.spatialEnabled"
        public static let spatialReferenceDistance = "audio.spatialReferenceDistance"
        public static let spatialMaxDistance = "audio.spatialMaxDistance"
    }

    /// Default volumes if no prior value is stored. Music sits slightly
    /// under SFX so click feedback always cuts through the bed.
    public static let defaultMusicVolume: Float = 0.6
    public static let defaultSFXVolume: Float = 0.8
    /// Default for the spatial-audio toggle. Spec D4 — on by default;
    /// players opt out for accessibility / mono output.
    public static let defaultSpatialAudioEnabled: Bool = true
    /// Default reference distance in tiles (full-volume radius around
    /// the listener). Spec D5.
    public static let defaultSpatialReferenceDistance: Float = 4.0
    /// Default maximum audible distance in tiles. Spec D5.
    public static let defaultSpatialMaxDistance: Float = 32.0

    public init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }

    public var musicVolume: Float {
        get {
            guard defaults.object(forKey: Key.musicVolume) != nil else {
                return Self.defaultMusicVolume
            }
            return defaults.float(forKey: Key.musicVolume)
        }
        set { defaults.set(newValue, forKey: Key.musicVolume) }
    }

    public var sfxVolume: Float {
        get {
            guard defaults.object(forKey: Key.sfxVolume) != nil else {
                return Self.defaultSFXVolume
            }
            return defaults.float(forKey: Key.sfxVolume)
        }
        set { defaults.set(newValue, forKey: Key.sfxVolume) }
    }

    public var isMuted: Bool {
        get { defaults.bool(forKey: Key.muted) }
        set { defaults.set(newValue, forKey: Key.muted) }
    }

    /// Spatial audio toggle. When false, the engine bypasses the
    /// environment node and treats every cue as 2D. Defaults to true.
    public var spatialAudioEnabled: Bool {
        get {
            guard defaults.object(forKey: Key.spatialEnabled) != nil else {
                return Self.defaultSpatialAudioEnabled
            }
            return defaults.bool(forKey: Key.spatialEnabled)
        }
        set { defaults.set(newValue, forKey: Key.spatialEnabled) }
    }

    /// Reference distance for spatial attenuation — sources within this
    /// radius play at full volume. Tunable per spec design D5.
    public var spatialReferenceDistance: Float {
        get {
            guard defaults.object(forKey: Key.spatialReferenceDistance) != nil else {
                return Self.defaultSpatialReferenceDistance
            }
            return defaults.float(forKey: Key.spatialReferenceDistance)
        }
        set { defaults.set(newValue, forKey: Key.spatialReferenceDistance) }
    }

    /// Maximum audible distance for spatial sources. Beyond this they
    /// are silent. Tunable per spec design D5.
    public var spatialMaxDistance: Float {
        get {
            guard defaults.object(forKey: Key.spatialMaxDistance) != nil else {
                return Self.defaultSpatialMaxDistance
            }
            return defaults.float(forKey: Key.spatialMaxDistance)
        }
        set { defaults.set(newValue, forKey: Key.spatialMaxDistance) }
    }
}
