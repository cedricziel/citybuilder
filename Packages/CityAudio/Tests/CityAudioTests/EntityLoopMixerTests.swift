import CityCore
import Testing
@testable import CityAudio

// Spec `audio-playback`: "Loop players follow their buildings" and
// "A session's loops end with it", through the cue player's voice
// bookkeeping with recording voices instead of AVAudioPlayerNodes.

@MainActor
private final class RecordingVoice: LoopVoice {
    let entity: EntityID
    private(set) var started = 0
    private(set) var stopped = 0
    init(entity: EntityID) {
        self.entity = entity
    }

    func start() {
        started += 1
    }

    func stop() {
        stopped += 1
    }
}

@MainActor
private final class Recorder {
    var voices: [RecordingVoice] = []
    lazy var mixer = EntityLoopMixer { [unowned self] dispatched in
        let voice = RecordingVoice(entity: dispatched.entity!)
        voices.append(voice)
        return voice
    }

    func voices(of entity: EntityID) -> [RecordingVoice] {
        voices.filter { $0.entity == entity }
    }
}

private func loop(_ raw: UInt32, at x: Int) -> DispatchedCue {
    DispatchedCue(
        cue: Bindings.Cue(file: "loop/saw.caf", bus: .loop, loop: true),
        position: TileCoordinate(x: x, y: 0),
        entity: EntityID(raw: raw)
    )
}

@MainActor
@Test("scenario: a stopped loop's player is released")
func stoppedLoopPlayerIsReleased() {
    let recorder = Recorder()
    recorder.mixer.want(loop(1, at: 1))
    recorder.mixer.want(loop(1, at: 1))
    #expect(recorder.voices.count == 1, "a repeated start makes no second voice")
    recorder.mixer.stop(EntityID(raw: 1))
    #expect(recorder.voices[0].stopped == 1)
    #expect(recorder.mixer.voices.isEmpty)
    recorder.mixer.want(loop(1, at: 1))
    #expect(recorder.voices.count == 2, "a restart makes a new voice")
    #expect(recorder.voices[1].started == 1)
}

@MainActor
@Test("scenario: moving the listener re-chooses the loops")
func movingTheListenerRechoosesLoops() {
    let recorder = Recorder()
    recorder.mixer.setListener(TileCoordinate(x: 0, y: 0))
    for raw: UInt32 in 1 ... 10 {
        recorder.mixer.want(loop(raw, at: Int(raw)))
    }
    #expect(Set(recorder.mixer.voices.keys) == Set((1 ... 8).map { EntityID(raw: $0) }))
    recorder.mixer.setListener(TileCoordinate(x: 20, y: 0))
    #expect(recorder.voices(of: EntityID(raw: 1)).first?.stopped == 1)
    #expect(recorder.mixer.voices[EntityID(raw: 10)] != nil)
}

@MainActor
@Test("scenario: a session's loops end with it")
func sessionLoopsEndWithIt() {
    let recorder = Recorder()
    let bindings = Bindings(bindings: [
        "productionCycleCompleted": [Bindings.Cue(file: "loop/saw.caf", bus: .loop, loop: true)]
    ])
    let coordinator = AudioCoordinator(
        bindings: bindings,
        dispatch: { recorder.mixer.want($0) },
        stop: { recorder.mixer.stop($0) }
    )
    let sawmill = EntityID(raw: 4)
    coordinator.consume(events: [.productionCycleCompleted(producer: sawmill, kind: .sawmill)])
    #expect(recorder.mixer.voices[sawmill] != nil)
    coordinator.endSession()
    recorder.mixer.stopAll()
    #expect(recorder.mixer.voices.isEmpty)
    #expect(recorder.voices(of: sawmill).first?.stopped == 1)
    // The next game reuses the entity ID; its loop starts again.
    coordinator.consume(events: [.productionCycleCompleted(producer: sawmill, kind: .sawmill)])
    #expect(recorder.voices(of: sawmill).count == 2)
}

@MainActor
@Test("scenario: a demolished workshop's loop stops")
func demolishedWorkshopLoopStops() {
    let recorder = Recorder()
    let bindings = Bindings(bindings: [
        "productionCycleCompleted": [Bindings.Cue(file: "loop/saw.caf", bus: .loop, loop: true)]
    ])
    let coordinator = AudioCoordinator(
        bindings: bindings,
        dispatch: { recorder.mixer.want($0) },
        stop: { recorder.mixer.stop($0) }
    )
    let sawmill = EntityID(raw: 9)
    coordinator.consume(events: [.productionCycleCompleted(producer: sawmill, kind: .sawmill)])
    coordinator.consumeSnapshot(WorldSnapshot(
        tickCount: 0, simulatedTime: .zero, mapWidth: 0, mapHeight: 0, terrainGrid: [], occupiedTiles: [:],
        buildings: [:], carriers: [], economy: Economy(), totalPopulation: 0, camera: Camera()
    ))
    #expect(recorder.mixer.voices.isEmpty)
    #expect(recorder.voices(of: sawmill).first?.stopped == 1)
}

@Test("scenario: a playing loop holds its place near the boundary")
func playingLoopHoldsItsPlace() {
    let playing = EntityID(raw: 1)
    let outsider = EntityID(raw: 2)
    let wanted: [EntityID: TileCoordinate?] = [playing: TileCoordinate(x: 10, y: 0), outsider: TileCoordinate(x: 9, y: 0)]
    let listener = TileCoordinate(x: 0, y: 0)
    #expect(LoopSelection.audible(wanted, listener: listener, playing: [playing], limit: 1) == [playing])
    let farther: [EntityID: TileCoordinate?] = [playing: TileCoordinate(x: 14, y: 0), outsider: TileCoordinate(x: 9, y: 0)]
    #expect(LoopSelection.audible(farther, listener: listener, playing: [playing], limit: 1) == [outsider])
}
