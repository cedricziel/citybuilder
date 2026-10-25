import AVFoundation

/// One-shots read whole and converted to the one format every pool node
/// plays. A node connected for one format traps on a buffer of another,
/// and the shipped one-shots mix mono 44.1 kHz with stereo 48 kHz. Spec:
/// `audio-playback` / One-shots play in one format.
enum OneShotBuffer {
    /// The format of every one-shot buffer and pool node.
    nonisolated(unsafe) static let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!

    /// The audio at `url` in `format`, or nil if it won't read or convert:
    /// a one-shot asset must be mono or stereo.
    static func load(_ url: URL) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url),
              (1 ... 2).contains(file.processingFormat.channelCount),
              let read = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: read)) != nil
        else { return nil }
        return read.format == format ? read : convert(read)
    }

    private static func convert(_ input: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: input.format, to: format) else { return nil }
        if input.format.channelCount == 1 {
            // Mono plays from both sides, not the left alone.
            converter.channelMap = [0, 0]
        }
        let ratio = format.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount((Double(input.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        let source = Source(input)
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, status in
            source.next(status)
        }
        return status == .error ? nil : output
    }

    /// Hands the converter the input once, then the end of the stream.
    private final class Source: @unchecked Sendable {
        private var buffer: AVAudioPCMBuffer?

        init(_ buffer: AVAudioPCMBuffer) {
            self.buffer = buffer
        }

        func next(_ status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
            guard let buffer else {
                status.pointee = .endOfStream
                return nil
            }
            self.buffer = nil
            status.pointee = .haveData
            return buffer
        }
    }
}
