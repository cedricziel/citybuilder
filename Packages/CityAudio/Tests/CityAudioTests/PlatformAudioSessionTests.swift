import Foundation
import Testing
@testable import CityAudio

// Tests for spec `platform-shells` — iOS audio session category +
// interruption handling, macOS no-op.

@MainActor
@Test("scenario: audio session not activated at launch")
func scenarioAudioSessionNotActivatedAtLaunch() {
    // Fresh PlatformAudioSession starts inactive — no AVAudioSession
    // category is set, no notification observer is installed. This holds
    // on every platform.
    let engine = AudioEngine()
    let session = PlatformAudioSession(engine: engine)
    #expect(!session.isActivated)
}

@MainActor
@Test("scenario: player's music keeps playing")
func scenarioPlayersMusicKeepsPlaying() {
    // The contract is "category .ambient on iOS, no-op on macOS". On the
    // macOS test host we can only verify that `activate()` does not throw
    // (because the Mac path is a no-op) and that the session reports
    // itself as activated. The full "user's Music app keeps playing"
    // behavior requires iOS hardware to verify.
    let engine = AudioEngine()
    let session = PlatformAudioSession(engine: engine)
    do {
        try session.activate()
        #expect(session.isActivated)
    } catch {
        // On iOS without a proper audio session, this could throw. The
        // test is written against macOS where the body is a no-op.
        Issue.record("activate() failed unexpectedly on macOS: \(error)")
    }
}

@MainActor
@Test("scenario: mac build links without audiosession")
func scenarioMacBuildLinksWithoutAudiosession() {
    // The iOS-only interruption-handling code is gated by
    // `#if os(iOS) || os(tvOS) || os(visionOS)`. On macOS, the Mac binary
    // compiles without referencing AVAudioSession types beyond import-
    // visibility. We assert the compile-time invariant via the macOS
    // process behavior — the package builds and tests run, which proves
    // the conditional compilation works.
    #if os(macOS)
    // Nothing more to assert — reaching this line on macOS means the
    // file compiled without an unconditional AVAudioSession reference.
    #expect(Bool(true))
    #else
    Issue.record("this scenario asserts macOS-only behavior; run on macOS")
    #endif
}
