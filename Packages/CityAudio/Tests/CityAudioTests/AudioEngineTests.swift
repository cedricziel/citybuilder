import AVFoundation
import CityCore
import Foundation
import Testing
@testable import CityAudio

// Tests for spec `audio-playback` — `Four-bus mixer engine` requirement
// and surrounding lifecycle scenarios.

@Test("scenario: engine has four buses")
func scenarioEngineHasFourBuses() {
    let engine = AudioEngine()
    let music = engine.bus(.music)
    let sfx = engine.bus(.sfx)
    let loop = engine.bus(.loop)
    let ambient = engine.bus(.ambient)
    // Four distinct AVAudioMixerNode instances.
    let identifiers: Set<ObjectIdentifier> = [
        ObjectIdentifier(music),
        ObjectIdentifier(sfx),
        ObjectIdentifier(loop),
        ObjectIdentifier(ambient)
    ]
    #expect(identifiers.count == 4, "four distinct mixer nodes, one per bus")
}

@Test("scenario: engine lazy-initializes on first cue")
func scenarioEngineLazyInitializesOnFirstCue() {
    let engine = AudioEngine()
    // Before any call to start() (which a cue dispatch will do), the
    // underlying engine is not running. No audio session activation,
    // no audio-render-cycle cost.
    #expect(!engine.isRunning, "engine must not auto-start at construction")
}

@Test("scenario: engine starts on first cue")
func scenarioEngineStartsOnFirstCue() throws {
    let engine = AudioEngine()
    try engine.start()
    #expect(engine.isRunning, "calling start() once must put the engine in running state")
    // Idempotent: calling start() again should not fail or transition state.
    try engine.start()
    #expect(engine.isRunning)
    engine.stop()
}

@Test("scenario: volume change applies within one render cycle")
func scenarioVolumeChangeAppliesWithinOneRenderCycle() {
    let engine = AudioEngine()
    engine.setVolume(0.5, on: .music)
    #expect(engine.bus(.music).outputVolume == 0.5)
}

@Test("scenario: global mute silences all buses")
func scenarioGlobalMuteSilencesAllBuses() {
    let engine = AudioEngine()
    engine.setVolume(0.8, on: .music)
    engine.setVolume(0.6, on: .sfx)
    engine.isMuted = true
    // Every bus's effective output volume drops to 0 under mute.
    for bus in AudioBus.allCases {
        #expect(engine.bus(bus).outputVolume == 0.0, "bus \(bus) must be silenced when muted")
    }
}

// MARK: - Spatial graph wiring (add-spatial-audio M2)

private func busDownstream(_ engine: AudioEngine, _ bus: AudioBus) -> AVAudioNode? {
    let mixer = engine.bus(bus)
    return engine.underlyingEngine.outputConnectionPoints(for: mixer, outputBus: 0).first?.node
}

@Test("scenario: loop bus routes through the environment node")
func scenarioLoopBusRoutesThroughTheEnvironmentNode() throws {
    let engine = AudioEngine(spatialEnabled: true)
    let env = engine.environmentNode
    #expect(env != nil, "spatial-enabled engine must have an environment node")
    // Loop mixer's downstream node is the environment node, not main.
    #expect(busDownstream(engine, .loop) === env)
    // Environment node's downstream is main.
    let envDest = try engine.underlyingEngine.outputConnectionPoints(for: #require(env), outputBus: 0).first?.node
    #expect(envDest === engine.underlyingEngine.mainMixerNode)
}

@Test("scenario: music bus bypasses the environment node")
func scenarioMusicBusBypassesTheEnvironmentNode() {
    let engine = AudioEngine(spatialEnabled: true)
    let main = engine.underlyingEngine.mainMixerNode
    // Music, SFX, and ambient mixers all connect directly to main —
    // never through the environment node.
    for bus in AudioBus.allCases where bus != .loop {
        #expect(
            busDownstream(engine, bus) === main,
            "bus \(bus) must connect directly to main, not through environment"
        )
    }
}

@Test("scenario: bypass toggle removes the environment node")
func scenarioBypassToggleRemovesTheEnvironmentNode() {
    let engine = AudioEngine(spatialEnabled: true)
    #expect(engine.environmentNode != nil)
    engine.setSpatialEnabled(false)
    #expect(engine.environmentNode == nil, "disabling spatial must detach the environment node")
    #expect(!engine.isSpatialEnabled)
    // Loop mixer now connects directly to main.
    #expect(busDownstream(engine, .loop) === engine.underlyingEngine.mainMixerNode)
    // Idempotent: a second call to disable doesn't crash or change state.
    engine.setSpatialEnabled(false)
    #expect(engine.environmentNode == nil)
    // Re-enabling rebuilds the chain.
    engine.setSpatialEnabled(true)
    #expect(engine.environmentNode != nil)
    #expect(busDownstream(engine, .loop) === engine.environmentNode)
}

@Test("scenario: spatial-disabled engine has no environment node from the start")
func scenarioSpatialDisabledEngineHasNoEnvironmentNodeFromTheStart() {
    let engine = AudioEngine(spatialEnabled: false)
    #expect(engine.environmentNode == nil)
    #expect(!engine.isSpatialEnabled)
    #expect(busDownstream(engine, .loop) === engine.underlyingEngine.mainMixerNode)
}

// MARK: - Listener position (add-spatial-audio M4)

@Test("scenario: listener position writes to environment node")
func scenarioListenerPositionWritesToEnvironmentNode() {
    let engine = AudioEngine(spatialEnabled: true)
    // Mirror what `AudioStack.setListenerPosition` does — write into the
    // env node's listener slot. The stack just adds the nil-tile and
    // no-env-node guards.
    let tile = TileCoordinate(x: 4, y: 5)
    engine.environmentNode?.listenerPosition = AVAudio3DPoint(
        x: Float(tile.x),
        y: 0,
        z: Float(tile.y)
    )
    let pos = engine.environmentNode?.listenerPosition
    #expect(pos?.x == 4)
    #expect(pos?.y == 0)
    #expect(pos?.z == 5)
}
