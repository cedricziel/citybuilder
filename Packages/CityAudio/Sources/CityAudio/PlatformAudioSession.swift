import AVFoundation
import Foundation

/// Cross-platform audio session configuration. The iOS implementation sets
/// the shared `AVAudioSession` category to `.ambient` so the user's own
/// music (Apple Music, Spotify) keeps playing alongside the game, and
/// observes interruption notifications (phone calls, Siri) to pause and
/// resume the engine. The macOS implementation is a no-op — AVAudioEngine
/// alone is sufficient on Mac.
///
/// Per spec `platform-shells` "iOS audio session category" + "iOS
/// interruption handling" + "macOS audio session no-op".
@MainActor
public final class PlatformAudioSession {
    private weak var engine: AudioEngine?
    private var activated = false

    public init(engine: AudioEngine) {
        self.engine = engine
    }

    /// True once `activate()` has been called and (on iOS) the audio
    /// session has been configured.
    public var isActivated: Bool {
        activated
    }

    /// Lazily configure the platform's audio session. Called on the first
    /// cue dispatch — never at app launch — so silent cold-launches do
    /// not interfere with the user's existing audio.
    public func activate() throws {
        guard !activated else { return }
        #if os(iOS) || os(tvOS) || os(visionOS)
        try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        #endif
        activated = true
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }
        switch type {
        case .began:
            engine?.stop()
        case .ended:
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    try? engine?.start()
                }
            }
        @unknown default:
            break
        }
    }
    #endif
}
