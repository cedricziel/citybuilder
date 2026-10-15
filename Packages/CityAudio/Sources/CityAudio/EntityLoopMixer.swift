import CityCore

/// One playing building loop. Production voices wrap an
/// `AVAudioPlayerNode`; tests use recorders.
@MainActor
protocol LoopVoice: AnyObject {
    /// Starts looping, fading in from silence.
    func start()
    /// Fades out, then stops and releases the node.
    func stop()
}

/// Keeps one voice per building loop for the loops `LoopSelection` lets
/// play, and starts and stops voices as loops come and go, the listener
/// moves, or the session ends. Spec: `audio-playback` / Loop players
/// follow their buildings.
@MainActor
final class EntityLoopMixer {
    typealias VoiceFactory = (DispatchedCue) -> LoopVoice?

    private let makeVoice: VoiceFactory
    private var wanted: [EntityID: DispatchedCue] = [:]
    private(set) var voices: [EntityID: LoopVoice] = [:]
    private var listener: TileCoordinate?

    init(makeVoice: @escaping VoiceFactory) {
        self.makeVoice = makeVoice
    }

    func want(_ dispatched: DispatchedCue) {
        guard let entity = dispatched.entity, wanted[entity] == nil else { return }
        wanted[entity] = dispatched
        refresh()
    }

    func stop(_ entity: EntityID) {
        guard wanted.removeValue(forKey: entity) != nil else { return }
        refresh()
    }

    func setListener(_ tile: TileCoordinate?) {
        guard tile != listener else { return }
        listener = tile
        refresh()
    }

    /// Silences every building loop, for the end of a game session.
    func stopAll() {
        wanted.removeAll()
        refresh()
    }

    private func refresh() {
        let audible = LoopSelection.audible(
            wanted.mapValues(\.position),
            listener: listener,
            playing: Set(voices.keys)
        )
        for (entity, voice) in voices where !audible.contains(entity) {
            voices.removeValue(forKey: entity)
            voice.stop()
        }
        for entity in audible.sorted(by: { $0.raw < $1.raw }) where voices[entity] == nil {
            guard let dispatched = wanted[entity], let voice = makeVoice(dispatched) else { continue }
            voices[entity] = voice
            voice.start()
        }
    }
}
