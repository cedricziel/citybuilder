import CityCore
import Foundation

/// Loops the configured ambient track on the `ambient` bus while the
/// world is alive. The bed is silent until the first non-empty
/// `[WorldEvent]` arrives (proxy for "the simulation is producing
/// activity"); thereafter the loop cue is dispatched exactly once and
/// the bus runs continuously. Per spec `audio-playback` — Ambient bed
/// section.
@MainActor
public final class AmbientBed {
    public typealias CueDispatcher = (DispatchedCue) -> Void

    private let section: Bindings.AmbientSection?
    private let dispatch: CueDispatcher
    private var started: Bool = false

    public init(section: Bindings.AmbientSection?, dispatch: @escaping CueDispatcher) {
        self.section = section
        self.dispatch = dispatch
    }

    /// True once the ambient loop has been dispatched. Exposed so the
    /// `AudioStack` can avoid re-wiring on rebuilds.
    public var isPlaying: Bool {
        started
    }

    /// Game-loop entry point: called once per tick with the events from
    /// that tick. The first call whose array is non-empty triggers the
    /// dispatch; subsequent calls are no-ops.
    public func consume(events: [WorldEvent]) {
        guard !started, !events.isEmpty else { return }
        guard let track = section?.tracks.first else { return }
        started = true
        let cue = Bindings.Cue(
            file: track.file,
            bus: .ambient,
            loop: true,
            spatialize: false
        )
        dispatch(DispatchedCue(cue: cue, position: nil))
    }
}
