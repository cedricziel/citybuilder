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
    /// Invoked once per cue the coordinator chooses to play. Carries the
    /// cue plus the per-event position resolved from the cached snapshot.
    public typealias CueDispatcher = (DispatchedCue) -> Void

    private let bindings: Bindings
    private let dispatch: CueDispatcher
    private var rng: any RandomNumberGenerator
    /// Active per-entity loops. Used to make loop-start idempotent and to
    /// route `stopLoop(for:)` to the right player.
    private var activeLoops: [EntityID: Bindings.Cue] = [:]
    /// Last `WorldSnapshot` accepted via `consumeSnapshot`. Used by
    /// `consume(events:)` to resolve each event's `primaryEntityID` to a
    /// `TileCoordinate`. Nil until the first snapshot arrives — events
    /// fired before that point dispatch with `position: nil`.
    private var cachedSnapshot: WorldSnapshot?

    public init(
        bindings: Bindings,
        rng: any RandomNumberGenerator = SystemRandomNumberGenerator(),
        dispatch: @escaping CueDispatcher
    ) {
        self.bindings = bindings
        self.rng = rng
        self.dispatch = dispatch
    }

    /// Caches the latest `WorldSnapshot` so `consume(events:)` can look up
    /// the position of each event's primary entity, and tears down loops
    /// for entities that have left the world (demolished, deserialized,
    /// etc.). The game loop calls this once per tick before forwarding
    /// the same tick's events. Idempotent for unchanged worlds.
    /// Spec: `audio-playback` — Snapshot-driven loop teardown.
    @MainActor
    public func consumeSnapshot(_ snapshot: WorldSnapshot) {
        cachedSnapshot = snapshot
        let presentIDs = snapshot.buildings.keys
        let presentSet = Set(presentIDs)
        for id in activeLoops.keys where !presentSet.contains(id) {
            stopLoop(for: id)
        }
    }

    /// Routes every event in `events` through the bindings table in input
    /// order. Unbound events are silently dropped. When multiple cues are
    /// bound to a single event, one is picked at random.
    @MainActor
    public func consume(events: [WorldEvent]) {
        for event in events {
            let key = Self.caseKey(for: event)
            guard let candidates = bindings.bindings[key], !candidates.isEmpty else { continue }
            // Filter candidates whose kindFilter doesn't match the event's
            // payload. A nil filter accepts any event; a non-nil filter
            // rejects events without a `kind` payload as a non-match.
            let matching = candidates.filter { cue in
                guard let filter = cue.kindFilter else { return true }
                return event.buildingKind == filter
            }
            guard !matching.isEmpty else { continue }
            let cue: Bindings.Cue = if matching.count == 1 {
                matching[0]
            } else {
                matching.randomElement(using: &rng) ?? matching[0]
            }

            if cue.action == .stop {
                if let entityId = event.primaryEntityID {
                    stopLoop(for: entityId)
                }
                continue
            }

            let position = resolvePosition(for: event)
            let dispatched = DispatchedCue(cue: cue, position: position)

            if cue.loop == true, let entityId = event.primaryEntityID {
                // Idempotent loop start — second dispatch for the same
                // entity is a no-op until the matching stopLoop arrives.
                guard activeLoops[entityId] == nil else { continue }
                activeLoops[entityId] = cue
                dispatch(dispatched)
            } else {
                dispatch(dispatched)
            }
        }
    }

    private func resolvePosition(for event: WorldEvent) -> TileCoordinate? {
        guard let entityId = event.primaryEntityID else { return nil }
        return cachedSnapshot?.buildings[entityId]?.anchor
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
        case .materialsDeducted: return "materialsDeducted"
        case .constructionWaitingForMaterials: return "constructionWaitingForMaterials"
        case .constructionStarted: return "constructionStarted"
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
        case .seasonChanged: return "seasonChanged"
        case .historyEvent: return "historyEvent"
        case .ageAdvanced: return "ageAdvanced"
        case .scenarioWon: return "scenarioWon"
        case .fuelRanOut: return "fuelRanOut"
        case .monumentCompleted: return "monumentCompleted"
        case .commissionStarted: return "commissionStarted"
        case .commissionEnded: return "commissionEnded"
        case .caravanSold: return "caravanSold"
        case .rivalAgeAdvanced: return "rivalAgeAdvanced"
        case .tradeCompleted: return "tradeCompleted"
        }
    }
}
