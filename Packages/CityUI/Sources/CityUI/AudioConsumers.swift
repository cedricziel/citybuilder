import CityCore
import Foundation

/// Consumer of the per-tick `[WorldEvent]` stream produced by
/// `World.tick()`. The app shells pass an `AudioCoordinator.consume(events:)`
/// closure (from `CityAudio`); headless tests pass nil or a recorder.
/// Decouples `CityUI` from `CityAudio` so the package boundary stays clean.
public typealias AudioEventConsumer = ([WorldEvent]) -> Void

/// Consumer of the per-tick `WorldSnapshot`. Called before
/// `AudioEventConsumer` for the same tick so the audio coordinator can
/// resolve each event's primary entity to a `TileCoordinate` for the
/// spatial layer. Per spec `audio-playback` "Cue dispatched with optional
/// position" (`add-spatial-audio` M1).
public typealias AudioSnapshotConsumer = (WorldSnapshot) -> Void
