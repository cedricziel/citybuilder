import CityCore
import Foundation

/// Consumes the per-tick `[WorldEvent]` produced by `World.tick()` and
/// dispatches matching cues from a `Bindings` table to the audio engine.
/// Per spec `audio-playback` "AudioCoordinator consumes per-tick events".
///
/// The dispatch step is injected as a closure so the coordinator stays
/// testable in isolation (test recorders) and so the production wiring
/// (an `AudioEngine`-backed player) can evolve without touching the
/// coordinator itself.
public final class AudioCoordinator: @unchecked Sendable {
    /// Invoked once per cue the coordinator chooses to play.
    public typealias CueDispatcher = (Bindings.Cue) -> Void

    private let bindings: Bindings
    private let dispatch: CueDispatcher
    private var rng: any RandomNumberGenerator
    /// Active per-entity loops. Used to make loop-start idempotent and to
    /// route `stopLoop(for:)` to the right player.
    private var activeLoops: [EntityID: Bindings.Cue] = [:]

    public init(
        bindings: Bindings,
        rng: any RandomNumberGenerator = SystemRandomNumberGenerator(),
        dispatch: @escaping CueDispatcher
    ) {
        self.bindings = bindings
        self.rng = rng
        self.dispatch = dispatch
    }

    /// Routes every event in `events` through the bindings table in input
    /// order. Unbound events are silently dropped. When multiple cues are
    /// bound to a single event, one is picked at random.
    @MainActor
    public func consume(events: [WorldEvent]) {
        for event in events {
            let key = Self.caseKey(for: event)
            guard let candidates = bindings.bindings[key], !candidates.isEmpty else { continue }
            let cue: Bindings.Cue = if candidates.count == 1 {
                candidates[0]
            } else {
                candidates.randomElement(using: &rng) ?? candidates[0]
            }

            if cue.loop == true, let entityId = event.primaryEntityID {
                // Idempotent loop start — second dispatch for the same
                // entity is a no-op until the matching stopLoop arrives.
                guard activeLoops[entityId] == nil else { continue }
                activeLoops[entityId] = cue
                dispatch(cue)
            } else {
                dispatch(cue)
            }
        }
    }

    /// Halts any active loop associated with `entity`. No-op if no loop
    /// is currently active for that entity.
    @MainActor
    public func stopLoop(for entity: EntityID) {
        // In Phase 1 the coordinator does not own AVAudioPlayerNode
        // instances directly — the dispatch closure manages playback. We
        // signal stop by re-dispatching the cue with a sentinel; for now
        // the contract is simply "the entity is no longer in activeLoops".
        // The real engine-backed coordinator (M11 wiring) will hold a
        // [EntityID: AVAudioPlayerNode] map and stop the node here.
        activeLoops.removeValue(forKey: entity)
    }

    /// True if a loop is currently registered for `entity`. Used by tests.
    public func hasActiveLoop(for entity: EntityID) -> Bool {
        activeLoops[entity] != nil
    }

    // swiftlint:disable:next cyclomatic_complexity
    static func caseKey(for event: WorldEvent) -> String {
        switch event {
        case .buildingPlaced: return "buildingPlaced"
        case .buildingDemolished: return "buildingDemolished"
        case .constructionCompleted: return "constructionCompleted"
        case .forestHarvested: return "forestHarvested"
        case .placementRejected: return "placementRejected"
        case .carrierDeparted: return "carrierDeparted"
        case .carrierArrived: return "carrierArrived"
        case .productionCycleCompleted: return "productionCycleCompleted"
        case .productionStalled: return "productionStalled"
        case .productionResumed: return "productionResumed"
        case .taxesCollected: return "taxesCollected"
        case .upkeepPaid: return "upkeepPaid"
        case .bankruptcyWarning: return "bankruptcyWarning"
        case .bankruptcyResolved: return "bankruptcyResolved"
        case .gameOver: return "gameOver"
        }
    }
}
