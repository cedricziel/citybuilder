/// Named mixer buses inside `AudioEngine`. Each bus is an
/// `AVAudioMixerNode` connected to the engine's main output with an
/// independently settable `outputVolume`. Per spec `audio-playback`
/// "Four-bus mixer engine" and design D4.
///
/// Adding a new bus is a deliberate, infrequent change — it affects the
/// engine graph, the bindings file schema, and the settings UI.
public enum AudioBus: String, CaseIterable, Sendable, Codable {
    /// Background music track(s). Long-form, looped, one-at-a-time playback.
    case music
    /// One-shot effects: UI clicks, placement thunks, coin pickups, chimes.
    case sfx
    /// Per-entity continuous loops (sawmill saw, lumberjack chops). Empty
    /// in Phase 1 — the lifecycle plumbing exists but no cue currently
    /// targets this bus.
    case loop
    /// Always-on world ambience: birdsong, breeze, waves. Subtle bed
    /// under everything else.
    case ambient
}
