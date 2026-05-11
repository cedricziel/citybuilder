/// CityAudio is the AVFoundation-backed audio layer that consumes the
/// transient `WorldEvent` stream emitted by `World.tick()` and turns those
/// events into music + SFX playback. Per spec `audio-playback` and design D11.
///
/// Boundary:
/// - Depends on `Foundation`, `AVFoundation`, and `CityCore` only.
/// - MUST NOT be linked by the `citybuilder-cli` target (enforced by
///   `scripts/check-cli-no-audio.sh`).
/// - Linked by `CitybuilderiOS` and `CitybuilderMac` app shells.
public enum CityAudio {
    public static let version = "0.0.0"
}
