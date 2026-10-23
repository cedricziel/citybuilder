import AVFoundation
import Foundation
@testable import CityAudio

/// A bundle holding `file`, `seconds` of 44.1 kHz mono silence, in a temporary folder named
/// `folder`, laid out as the cue player looks files up.
func silentBundle(folder: String, file: String, seconds: Double) -> Bundle? {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(folder)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    let frames = AVAudioFrameCount(44100 * seconds)
    guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
          let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
          let audio = try? AVAudioFile(forWriting: url.appendingPathComponent(file), settings: format.settings)
    else { return nil }
    buffer.frameLength = frames
    try? audio.write(from: buffer)
    return Bundle(url: url)
}

/// Stops the engine behind `engine`'s back and posts the change, as the system does when the output
/// hardware changes.
@MainActor
func changeConfiguration(of engine: AudioEngine) {
    engine.underlyingEngine.stop()
    NotificationCenter.default.post(name: .AVAudioEngineConfigurationChange, object: engine.underlyingEngine)
}
