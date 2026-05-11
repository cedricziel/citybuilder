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
    }

    /// Default volumes if no prior value is stored. Music sits slightly
    /// under SFX so click feedback always cuts through the bed.
    public static let defaultMusicVolume: Float = 0.6
    public static let defaultSFXVolume: Float = 0.8

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
}
