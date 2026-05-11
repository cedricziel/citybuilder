import AVFoundation
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
